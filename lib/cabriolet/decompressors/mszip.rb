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
      def initialize(io_system, input, output, buffer_size, fix_mszip: false, **_kwargs)
        super(io_system, input, output, buffer_size)
        @fix_mszip = fix_mszip

        # Initialize sliding window
        @window = "\0" * FRAME_SIZE
        @window_posn = 0
        @bytes_output = 0

        # Initialize bitstream
        @bitstream = Binary::Bitstream.new(io_system, input, buffer_size)

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

        while bytes.positive?
          # Read 'CK' signature
          read_signature

          # Reset window state for new block
          @window_posn = 0
          @bytes_output = 0

          # Inflate the block
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

          # Write output
          write_amount = [bytes, @bytes_output].min
          io_system.write(output, @window[0, write_amount])
          total_written += write_amount
          bytes -= write_amount
        end

        total_written
      end

      private

      # Read and verify 'CK' signature
      def read_signature
        # Align to byte boundary
        @bitstream.byte_align

        # Read bytes until we find 'CK' (no EOF checking - matches libmspack lines 407-414)
        state = 0
        bytes_read = 0
        max_search = 10_000 # Prevent infinite loops

        loop do
          byte = @bitstream.read_bits(8)
          bytes_read += 1

          # Prevent infinite loops
          if bytes_read > max_search
            raise DecompressionError,
                  "CK signature not found in stream"
          end

          if byte == 0x43 # 'C'
            state = 1
          elsif state == 1 && byte == 0x4B # 'K'
            break
          else
            state = 0
          end
        end
      end

      # Inflate a single block
      def inflate_block
        loop do
          # Read last block flag
          last_block = @bitstream.read_bits(1)

          # Read block type
          block_type = @bitstream.read_bits(2)

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

          break if last_block == 1
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
      def inflate_huffman_block
        loop do
          # Decode symbol from literal tree
          code = Huffman::Decoder.decode_symbol(
            @bitstream, @literal_tree.table, LITERAL_TABLEBITS,
            @literal_lengths, LITERAL_MAXSYMBOLS
          )

          if code < 256
            # Literal byte
            @window.setbyte(@window_posn, code)
            @window_posn += 1
            flush_window if @window_posn == FRAME_SIZE
          elsif code == 256
            # End of block
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
