# frozen_string_literal: true

module Cabriolet
  module Decompressors
    # MSZIP handles MSZIP (deflate) compressed data
    # Based on RFC 1951 and libmspack implementation
    class MSZIP < Base
      # MSZIP frame size (32KB sliding window)
      FRAME_SIZE = 32_768

      # Huffman tree constants
      LITERAL_MAXSYMBOLS = 288
      LITERAL_TABLEBITS = 9
      DISTANCE_MAXSYMBOLS = 32
      DISTANCE_TABLEBITS = 6

      # MSZIP signature bytes
      SIGNATURE_BYTE_C = 0x43  # ASCII 'C'
      SIGNATURE_BYTE_K = 0x4B  # ASCII 'K'

      # Maximum bytes to search for CK signature (prevents infinite loops)
      MAX_SIGNATURE_SEARCH = 10_000

      # Match lengths for literal codes 257-285
      LIT_LENGTHS = [
        3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27,
        31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258
      ].freeze

      # Match offsets for distance codes 0-29
      DIST_OFFSETS = [
        1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385,
        513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12_289, 16_385, 24_577
      ].freeze

      # Extra bits for literal codes 257-285
      LIT_EXTRABITS = [
        0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2,
        2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0
      ].freeze

      # Extra bits for distance codes 0-29
      DIST_EXTRABITS = [
        0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6,
        6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13
      ].freeze

      # Order of bit length code lengths
      BITLEN_ORDER = [
        16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
      ].freeze

      # Initialize MSZIP decompressor
      #
      # @param io_system [System::IOSystem] I/O system for reading/writing
      # @param input [System::FileHandle, System::MemoryHandle] Input handle
      # @param output [System::FileHandle, System::MemoryHandle] Output handle
      # @param buffer_size [Integer] Buffer size for I/O operations
      # @param fix_mszip [Boolean] Enable repair mode for corrupted data
      def initialize(io_system, input, output, buffer_size, fix_mszip: false, salvage: false, **_kwargs)
        super(io_system, input, output, buffer_size)
        @fix_mszip = fix_mszip

        # Initialize sliding window
        @window = "\0" * FRAME_SIZE
        @window_posn = 0
        @bytes_output = 0
        @window_offset = 0  # Offset into window for unconsumed data (for multi-file CFDATA blocks)

        # Initialize bitstream
        @bitstream = Binary::Bitstream.new(io_system, input, buffer_size, salvage: salvage)

        # Initialize Huffman trees
        @literal_lengths = Array.new(LITERAL_MAXSYMBOLS, 0)
        @distance_lengths = Array.new(DISTANCE_MAXSYMBOLS, 0)
        @literal_tree = nil
        @distance_tree = nil
      end

      # Decompress MSZIP data
      #
      # @param bytes [Integer] Number of bytes to decompress
      # @return [Integer] Number of bytes decompressed
      def decompress(bytes)
        total_written = 0

        if ENV['DEBUG_MSZIP']
          $stderr.puts "DEBUG MSZIP.decompress(#{bytes}): ENTRY bytes_output=#{@bytes_output} window_offset=#{@window_offset} window_posn=#{@window_posn}"
        end

        while bytes.positive?
          # Check if we have buffered data from previous inflate
          if @bytes_output.positive?
            if ENV['DEBUG_MSZIP']
              $stderr.puts "DEBUG MSZIP: Using buffered data: bytes_output=#{@bytes_output} window_offset=#{@window_offset}"
            end

            # Write from buffer
            write_amount = [bytes, @bytes_output].min
            io_system.write(output, @window[@window_offset, write_amount])
            total_written += write_amount
            bytes -= write_amount
            @bytes_output -= write_amount
            @window_offset += write_amount

            if ENV['DEBUG_MSZIP']
              $stderr.puts "DEBUG MSZIP: After buffer write: total_written=#{total_written} bytes_remaining=#{bytes} bytes_output=#{@bytes_output}"
            end

            # Continue loop to check if we need more data
            next
          end

          # No buffered data - need to inflate a new MSZIP frame
          # Reset window for new frame
          @window_offset = 0
          @window_posn = 0

          # Read 'CK' signature (marks start of MSZIP frame)
          # Every MSZIP frame starts with a CK signature
          if ENV['DEBUG_MSZIP']
            $stderr.puts "DEBUG MSZIP: Reading CK signature (new MSZIP frame)"
          end
          read_signature

          # Inflate the MSZIP frame (processes deflate blocks until last_block or window full)
          if ENV['DEBUG_MSZIP']
            $stderr.puts "DEBUG MSZIP: Calling inflate_block"
          end

          begin
            inflate_block
          rescue DecompressionError
            raise unless @fix_mszip

            # In repair mode, pad with zeros
            (@bytes_output...FRAME_SIZE).each do |i|
              @window.setbyte(i, 0)
            end
            @bytes_output = FRAME_SIZE
          end

          if ENV['DEBUG_MSZIP']
            $stderr.puts "DEBUG MSZIP: After inflate_block: bytes_output=#{@bytes_output} window_posn=#{@window_posn}"
          end

          # Now we have data in the window buffer - loop back to write from it
        end

        if ENV['DEBUG_MSZIP']
          $stderr.puts "DEBUG MSZIP.decompress: EXIT total_written=#{total_written}"
        end

        total_written
      end

      private

      # Read and verify 'CK' signature
      def read_signature
        if ENV['DEBUG_MSZIP']
          $stderr.puts "DEBUG read_signature: Before byte_align"
        end

        # Align to byte boundary
        @bitstream.byte_align

        # Read first 2 bytes
        c = @bitstream.read_bits(8)
        k = @bitstream.read_bits(8)

        if ENV['DEBUG_MSZIP']
          $stderr.puts "DEBUG read_signature: Read 0x#{c.to_s(16)} 0x#{k.to_s(16)} (expected 'C'=0x43 'K'=0x4B)"
        end

        # If not CK, search for it (similar to libmspack's tolerant behavior)
        unless c == SIGNATURE_BYTE_C && k == SIGNATURE_BYTE_K
          # Search for CK signature in the stream (up to a reasonable limit)
          max_search = 256
          found = false

          max_search.times do
            # Shift: c becomes k, read new k
            c = k
            k = @bitstream.read_bits(8)

            if c == SIGNATURE_BYTE_C && k == SIGNATURE_BYTE_K
              found = true
              if ENV['DEBUG_MSZIP']
                $stderr.puts "DEBUG read_signature: Found CK signature after searching"
              end
              break
            end
          end

          unless found
            raise DecompressionError,
                  "Invalid MSZIP signature: could not find CK in stream"
          end
        end
      end

      # Inflate a single block
      #
      # Processes deflate blocks until the last_block flag is set or window is full.
      # Always decodes complete blocks - does not stop mid-block.
      def inflate_block
        # Read first block header
        last_block = @bitstream.read_bits(1)
        block_type = @bitstream.read_bits(2)

        if ENV['DEBUG_MSZIP']
          $stderr.puts "DEBUG inflate_block: First block: last_block=#{last_block} block_type=#{block_type}"
        end

        loop do
          # Process current block
          case block_type
          when 0
            inflate_stored_block
          when 1
            build_fixed_trees
            inflate_huffman_block
          when 2
            build_dynamic_trees
            inflate_huffman_block
          else
            raise DecompressionError, "Invalid block type: #{block_type}"
          end

          if ENV['DEBUG_MSZIP']
            $stderr.puts "DEBUG inflate_block: After block: last_block=#{last_block} window_posn=#{@window_posn}"
          end

          # Stop if this was the last block
          break if last_block == 1

          # Read next block header (only if we need to continue)
          last_block = @bitstream.read_bits(1)
          block_type = @bitstream.read_bits(2)
        end

        # Flush remaining window data
        flush_window if @window_posn.positive?
      end

      # Inflate an uncompressed (stored) block
      def inflate_stored_block
        # Align to byte boundary
        @bitstream.byte_align

        # Read length and complement
        length = @bitstream.read_bits(16)
        complement = @bitstream.read_bits(16)

        # Verify complement
        unless length == (~complement & 0xFFFF)
          raise DecompressionError,
                "Stored block length complement mismatch"
        end

        # Copy uncompressed data
        length.times do
          byte = @bitstream.read_bits(8)
          @window.setbyte(@window_posn, byte)
          @window_posn += 1
          flush_window if @window_posn == FRAME_SIZE
        end
      end

      # Build fixed Huffman trees (RFC 1951)
      def build_fixed_trees
        # Fixed literal/length tree
        @literal_lengths.fill(0)
        (0...144).each { |i| @literal_lengths[i] = 8 }
        (144...256).each { |i| @literal_lengths[i] = 9 }
        (256...280).each { |i| @literal_lengths[i] = 7 }
        (280...288).each { |i| @literal_lengths[i] = 8 }

        # Fixed distance tree
        @distance_lengths.fill(5, 0, 32)

        # Build decode tables
        build_literal_table
        build_distance_table
      end

      # Build dynamic Huffman trees from stream
      def build_dynamic_trees
        # Read code counts
        lit_codes = @bitstream.read_bits(5) + 257
        dist_codes = @bitstream.read_bits(5) + 1
        bitlen_codes = @bitstream.read_bits(4) + 4

        # Validate counts
        if lit_codes > LITERAL_MAXSYMBOLS
          raise DecompressionError,
                "Too many literal codes: #{lit_codes}"
        end
        if dist_codes > DISTANCE_MAXSYMBOLS
          raise DecompressionError,
                "Too many distance codes: #{dist_codes}"
        end

        # Read bit length code lengths
        bl_lengths = Array.new(19, 0)
        bitlen_codes.times do |i|
          bl_lengths[BITLEN_ORDER[i]] = @bitstream.read_bits(3)
        end

        # Build bit length decode table
        bl_tree = Huffman::Tree.new(bl_lengths, 19)
        unless bl_tree.build_table(7)
          raise DecompressionError,
                "Failed to build bit length tree"
        end

        # Read code lengths using bit length tree
        code_lengths = []
        last_code = 0

        while code_lengths.size < (lit_codes + dist_codes)
          code = Huffman::Decoder.decode_symbol(
            @bitstream, bl_tree.table, 7, bl_lengths, 19
          )

          if code < 16
            # Literal code length
            code_lengths << code
            last_code = code
          elsif code == 16
            # Repeat last code 3-6 times
            run = @bitstream.read_bits(2) + 3
            run.times { code_lengths << last_code }
          elsif code == 17
            # Repeat 0 for 3-10 times
            run = @bitstream.read_bits(3) + 3
            run.times { code_lengths << 0 }
          elsif code == 18
            # Repeat 0 for 11-138 times
            run = @bitstream.read_bits(7) + 11
            run.times { code_lengths << 0 }
          else
            raise DecompressionError, "Invalid bit length code: #{code}"
          end
        end

        # Split into literal and distance lengths
        @literal_lengths = code_lengths[0,
                                        lit_codes] + Array.new(
                                          LITERAL_MAXSYMBOLS - lit_codes, 0
                                        )
        @distance_lengths = code_lengths[lit_codes, dist_codes] +
          Array.new(DISTANCE_MAXSYMBOLS - dist_codes, 0)

        # Build decode tables
        build_literal_table
        build_distance_table
      end

      # Build literal/length decode table
      def build_literal_table
        @literal_tree = Huffman::Tree.new(@literal_lengths, LITERAL_MAXSYMBOLS)
        return if @literal_tree.build_table(LITERAL_TABLEBITS)

        raise DecompressionError, "Failed to build literal tree"
      end

      # Build distance decode table
      def build_distance_table
        @distance_tree = Huffman::Tree.new(@distance_lengths,
                                           DISTANCE_MAXSYMBOLS)
        return if @distance_tree.build_table(DISTANCE_TABLEBITS)

        raise DecompressionError, "Failed to build distance tree"
      end

      # Inflate a Huffman-compressed block
      #
      # Always decodes until code 256 (END OF BLOCK)
      def inflate_huffman_block
        symbol_count = 0
        loop do
          if ENV['DEBUG_MSZIP_SYMBOLS']
            $stderr.puts "DEBUG inflate_huffman_block: window_posn=#{@window_posn} bytes_output=#{@bytes_output}"
          end

          # Decode symbol from literal tree
          code = Huffman::Decoder.decode_symbol(
            @bitstream, @literal_tree.table, LITERAL_TABLEBITS,
            @literal_lengths, LITERAL_MAXSYMBOLS
          )
          symbol_count += 1

          if ENV['DEBUG_MSZIP_SYMBOLS'] || ENV['DEBUG_MSZIP']
            $stderr.puts "DEBUG inflate_huffman_block[#{symbol_count}]: decoded code=#{code} (#{'0x%02x' % code if code < 256})"
          end

          if code < 256
            # Literal byte
            @window.setbyte(@window_posn, code)
            @window_posn += 1
            flush_window if @window_posn == FRAME_SIZE
          elsif code == 256
            # End of block
            if ENV['DEBUG_MSZIP'] || ENV['DEBUG_MSZIP_SYMBOLS']
              $stderr.puts "DEBUG inflate_huffman_block: END OF BLOCK (window_posn=#{@window_posn})"
            end
            break
          else
            # Length/distance pair (LZ77 match)
            decode_match(code)
          end
        end
      end

      # Decode and copy a match (LZ77)
      #
      # @param code [Integer] Length code (257-285)
      def decode_match(code)
        # Validate code
        code -= 257
        if code >= 29
          raise DecompressionError,
                "Invalid length code: #{code + 257}"
        end

        # Decode length
        extra_bits = LIT_EXTRABITS[code]
        length = LIT_LENGTHS[code]
        length += @bitstream.read_bits(extra_bits) if extra_bits.positive?

        # Decode distance
        dist_code = Huffman::Decoder.decode_symbol(
          @bitstream, @distance_tree.table, DISTANCE_TABLEBITS,
          @distance_lengths, DISTANCE_MAXSYMBOLS
        )
        if dist_code >= 30
          raise DecompressionError,
                "Invalid distance code: #{dist_code}"
        end

        extra_bits = DIST_EXTRABITS[dist_code]
        distance = DIST_OFFSETS[dist_code]
        distance += @bitstream.read_bits(extra_bits) if extra_bits.positive?

        # Calculate match position with wraparound
        match_posn = if distance > @window_posn
                       FRAME_SIZE + @window_posn - distance
                     else
                       @window_posn - distance
                     end

        # Copy match
        length.times do
          @window.setbyte(@window_posn, @window.getbyte(match_posn))
          @window_posn += 1
          match_posn = (match_posn + 1) & (FRAME_SIZE - 1)
          flush_window if @window_posn == FRAME_SIZE
        end
      end

      # Flush window data to output
      def flush_window
        @bytes_output += @window_posn
        if @bytes_output > FRAME_SIZE
          raise DecompressionError,
                "Output overflow"
        end

        @window_posn = 0
      end
    end
  end
end
