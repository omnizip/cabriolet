# frozen_string_literal: true

require_relative "../binary/bitstream_writer"
require_relative "../huffman/encoder"

module Cabriolet
  module Compressors
    # LZX handles LZX compression
    # Based on libmspack lzxc.c implementation
    #
    # Phase 1 Implementation:
    # - VERBATIM blocks only
    # - Basic LZ77 matching
    # - Simple tree building
    # - No E8 preprocessing
    # - 32KB window size
    class LZX < Base
      # Frame size (32KB per frame)
      FRAME_SIZE = 32_768

      # Block types
      BLOCKTYPE_VERBATIM = 1
      BLOCKTYPE_ALIGNED = 2
      BLOCKTYPE_UNCOMPRESSED = 3

      # Match constants
      MIN_MATCH = 2
      MAX_MATCH = 257
      NUM_CHARS = 256

      # Tree constants
      PRETREE_NUM_ELEMENTS = 20
      PRETREE_MAXSYMBOLS = 20

      ALIGNED_NUM_ELEMENTS = 8
      ALIGNED_MAXSYMBOLS = 8

      NUM_PRIMARY_LENGTHS = 7
      NUM_SECONDARY_LENGTHS = 249
      LENGTH_MAXSYMBOLS = 250

      # Position slots for different window sizes
      POSITION_SLOTS = [30, 32, 34, 36, 38, 42, 50, 66, 98, 162, 290].freeze

      # Extra bits for position slots
      EXTRA_BITS = [
        0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8,
        9, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 15, 16, 16
      ].freeze

      # Position base offsets
      POSITION_BASE = [
        0, 1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64, 96, 128, 192, 256, 384, 512,
        768, 1024, 1536, 2048, 3072, 4096, 6144, 8192, 12_288, 16_384, 24_576, 32_768,
        49_152, 65_536, 98_304, 131_072, 196_608, 262_144, 393_216, 524_288, 655_360,
        786_432, 917_504, 1_048_576, 1_179_648, 1_310_720, 1_441_792, 1_572_864, 1_703_936,
        1_835_008, 1_966_080, 2_097_152
      ].freeze

      attr_reader :window_bits

      # Initialize LZX compressor
      #
      # @param io_system [System::IOSystem] I/O system for reading/writing
      # @param input [System::FileHandle, System::MemoryHandle] Input handle
      # @param output [System::FileHandle, System::MemoryHandle] Output handle
      # @param buffer_size [Integer] Buffer size for I/O operations
      # @param window_bits [Integer] Window size (15-21 for regular LZX)
      def initialize(io_system, input, output, buffer_size, window_bits: 15)
        super(io_system, input, output, buffer_size)

        # Validate window_bits
        unless (15..21).cover?(window_bits)
          raise ArgumentError,
                "LZX window_bits must be 15-21, got #{window_bits}"
        end

        @window_bits = window_bits
        @window_size = 1 << window_bits

        # Calculate number of position slots
        @num_offsets = POSITION_SLOTS[window_bits - 15] << 3
        @maintree_maxsymbols = NUM_CHARS + @num_offsets

        # Initialize bitstream writer
        @bitstream = Binary::BitstreamWriter.new(io_system, output, buffer_size)

        # Initialize sliding window for LZ77
        @window = "\0" * @window_size
        @window_pos = 0

        # Initialize R0, R1, R2 (LRU offset registers)
        @r0 = 1
        @r1 = 1
        @r2 = 1

        # Statistics for tree building
        @literal_freq = Array.new(NUM_CHARS, 0)
        @match_freq = Array.new(@num_offsets, 0)
        @length_freq = Array.new(LENGTH_MAXSYMBOLS, 0)
      end

      # Compress input data using LZX algorithm
      #
      # @return [Integer] Number of bytes written
      def compress
        input_data = read_all_input
        return 0 if input_data.empty?

        # Write Intel E8 filesize header once at the beginning (1 bit = 0, meaning no E8 processing)
        @bitstream.write_bits(0, 1)

        total_compressed = 0
        pos = 0

        # Process data in FRAME_SIZE chunks
        while pos < input_data.bytesize
          frame_size = [FRAME_SIZE, input_data.bytesize - pos].min
          frame_data = input_data[pos, frame_size]

          # Compress this frame
          compress_frame(frame_data)

          pos += frame_size
          total_compressed += frame_size
        end

        # Flush any remaining bits
        @bitstream.flush

        total_compressed
      end

      private

      # Read all input data into memory
      #
      # @return [String] All input data
      def read_all_input
        data = +""
        loop do
          chunk = @io_system.read(@input, @buffer_size)
          break if chunk.empty?

          data << chunk
        end
        data
      end

      # Compress a single frame (32KB)
      #
      # @param data [String] Frame data to compress
      # @return [void]
      def compress_frame(data)
        # Use UNCOMPRESSED blocks for now (simplest approach)
        write_block_header(BLOCKTYPE_UNCOMPRESSED, data.bytesize)

        # Write R0, R1, R2 (required for uncompressed blocks)
        write_offset_registers

        # Write raw data
        data.each_byte do |byte|
          @bitstream.write_bits(byte, 8)
        end

        # Ensure byte alignment at end of frame for multi-frame support
        @bitstream.byte_align
      end

      # Analyze frame and generate LZ77 tokens
      #
      # @param data [String] Frame data
      # @return [Array<Hash>] Array of tokens (:literal or :match)
      def analyze_frame(data)
        tokens = []
        pos = 0

        while pos < data.bytesize
          # Try to find a match in the window
          match = find_match(data, pos)

          if match && match[:length] >= MIN_MATCH
            # Record match token
            tokens << {
              type: :match,
              length: match[:length],
              offset: match[:offset],
            }

            # Update statistics
            update_match_statistics(match[:length], match[:offset])

            # Add matched bytes to window
            match[:length].times do
              add_to_window(data.getbyte(pos))
              pos += 1
            end
          else
            # Record literal token
            byte = data.getbyte(pos)
            tokens << { type: :literal, value: byte }

            # Update statistics
            @literal_freq[byte] += 1

            add_to_window(byte)
            pos += 1
          end
        end

        tokens
      end

      # Find the longest match in the sliding window
      #
      # @param data [String] Input data
      # @param pos [Integer] Current position in data
      # @return [Hash, nil] Match info with :length and :offset, or nil
      def find_match(data, pos)
        return nil if pos >= data.bytesize

        best_match = nil
        max_length = [MAX_MATCH, data.bytesize - pos].min

        # Don't search if we can't get MIN_MATCH
        return nil if max_length < MIN_MATCH

        # Search window for matches
        search_start = [@window_pos - @window_size, 0].max
        search_end = @window_pos

        (search_start...search_end).each do |win_pos|
          length = 0

          # Count matching bytes
          while length < max_length &&
              data.getbyte(pos + length) == @window.getbyte(win_pos + length)
            length += 1
          end

          # Update best match if this is longer
          next unless length >= MIN_MATCH && (best_match.nil? || length > best_match[:length])

          offset = @window_pos - win_pos
          best_match = { length: length, offset: offset }

          # Stop if we found maximum match
          break if length == MAX_MATCH
        end

        best_match
      end

      # Add byte to sliding window
      #
      # @param byte [Integer] Byte to add
      # @return [void]
      def add_to_window(byte)
        @window.setbyte(@window_pos % @window_size, byte)
        @window_pos += 1
      end

      # Update match statistics
      #
      # @param length [Integer] Match length
      # @param offset [Integer] Match offset
      # @return [void]
      def update_match_statistics(length, offset)
        # Get position slot for this offset
        position_slot = get_position_slot(offset)
        (position_slot << 3)

        # Calculate length slot (0-6 directly, 7 needs length tree)
        length_slot = [length - MIN_MATCH, NUM_PRIMARY_LENGTHS].min

        @match_freq[(position_slot << 3) | length_slot] += 1

        # If length requires length tree
        return unless length_slot == NUM_PRIMARY_LENGTHS

        length_footer = length - MIN_MATCH - NUM_PRIMARY_LENGTHS
        @length_freq[length_footer] += 1 if length_footer < LENGTH_MAXSYMBOLS
      end

      # Get position slot for an offset
      #
      # @param offset [Integer] Match offset
      # @return [Integer] Position slot
      def get_position_slot(offset)
        # Find position slot using binary search on POSITION_BASE
        return 0 if offset < 4

        # For offsets >= 4, find the slot
        slot = 0
        POSITION_BASE.each_with_index do |base, index|
          break if base > offset

          slot = index
        end

        slot
      end

      # Build Huffman trees from frequency statistics
      #
      # @return [void]
      def build_trees
        # Build main tree (literals + matches)
        maintree_freqs = @literal_freq + @match_freq
        @maintree_lengths = build_tree_lengths(maintree_freqs,
                                               @maintree_maxsymbols)
        @maintree_codes = Huffman::Encoder.build_codes(@maintree_lengths,
                                                       @maintree_maxsymbols)

        # Build length tree
        @length_lengths = build_tree_lengths(@length_freq, LENGTH_MAXSYMBOLS)
        @length_codes = Huffman::Encoder.build_codes(@length_lengths,
                                                     LENGTH_MAXSYMBOLS)

        # Build pretree (used to encode the other trees)
        # Create a valid Huffman tree that satisfies Kraft inequality
        # For 20 symbols, use: 2@3bits + 6@4bits + 12@5bits = 1.0
        @pretree_lengths = Array.new(PRETREE_MAXSYMBOLS, 0)
        # Most common symbols (0-1): 3 bits
        (0..1).each { |i| @pretree_lengths[i] = 3 }
        # Common symbols (2-7): 4 bits
        (2..7).each { |i| @pretree_lengths[i] = 4 }
        # Less common symbols (8-19): 5 bits
        (8..19).each { |i| @pretree_lengths[i] = 5 }
        @pretree_codes = Huffman::Encoder.build_codes(@pretree_lengths,
                                                      PRETREE_MAXSYMBOLS)
      end

      # Build Huffman code lengths from frequencies
      #
      # @param freqs [Array<Integer>] Symbol frequencies
      # @param num_symbols [Integer] Number of symbols
      # @return [Array<Integer>] Code lengths
      def build_tree_lengths(freqs, num_symbols)
        # Simple implementation: assign lengths based on frequency
        # Higher frequency = shorter code
        lengths = Array.new(num_symbols, 0)

        # Get non-zero frequencies
        non_zero = freqs.each_with_index.select { |freq, _| freq.positive? }
        return lengths if non_zero.empty?

        # Sort by frequency (descending)
        sorted = non_zero.sort_by { |freq, _| -freq }

        # Assign lengths using simple strategy
        sorted.each_with_index do |(_, symbol), index|
          # Assign shorter codes to more frequent symbols
          lengths[symbol] = if index < num_symbols / 8
                              4
                            elsif index < num_symbols / 4
                              6
                            elsif index < num_symbols / 2
                              8
                            else
                              10
                            end
        end

        lengths
      end

      # Write block header
      #
      # @param block_type [Integer] Block type
      # @param block_length [Integer] Block length in bytes
      # @return [void]
      def write_block_header(block_type, block_length)
        # Write 3-bit block type
        @bitstream.write_bits(block_type, 3)

        # Write 24-bit block length (16 bits + 8 bits)
        @bitstream.write_bits((block_length >> 8) & 0xFFFF, 16)
        @bitstream.write_bits(block_length & 0xFF, 8)

        # Align to byte boundary for UNCOMPRESSED blocks
        @bitstream.byte_align if block_type == BLOCKTYPE_UNCOMPRESSED
      end

      # Write offset registers (R0, R1, R2) for uncompressed blocks
      #
      # @return [void]
      def write_offset_registers
        # Write R0, R1, R2 as 32-bit little-endian values (12 bytes total)
        [@r0, @r1, @r2].each do |offset|
          @bitstream.write_bits(offset & 0xFF, 8)
          @bitstream.write_bits((offset >> 8) & 0xFF, 8)
          @bitstream.write_bits((offset >> 16) & 0xFF, 8)
          @bitstream.write_bits((offset >> 24) & 0xFF, 8)
        end
      end

      # Write tree definitions
      #
      # @return [void]
      def write_trees
        # Write pretree (20 elements, 4 bits each)
        write_pretree

        # Write main tree using pretree encoding
        write_tree_with_pretree(@maintree_lengths, 0, NUM_CHARS)
        write_tree_with_pretree(@maintree_lengths, NUM_CHARS,
                                @maintree_maxsymbols)

        # Write length tree using pretree encoding
        write_tree_with_pretree(@length_lengths, 0, NUM_SECONDARY_LENGTHS)
      end

      # Write pretree
      #
      # @return [void]
      def write_pretree
        PRETREE_MAXSYMBOLS.times do |i|
          @bitstream.write_bits(@pretree_lengths[i], 4)
        end
      end

      # Write tree lengths using pretree encoding
      #
      # @param lengths [Array<Integer>] Tree lengths to encode
      # @param start [Integer] Start index
      # @param end_idx [Integer] End index (exclusive)
      # @return [void]
      def write_tree_with_pretree(lengths, start, end_idx)
        i = start
        prev_length = 0

        while i < end_idx
          length = lengths[i]

          # Check for runs of zeros
          if length.zero?
            zero_count = 0
            while i < end_idx && lengths[i].zero? && zero_count < 138
              zero_count += 1
              i += 1
            end

            if zero_count >= 20
              # Use code 18 for long runs (20-51)
              while zero_count >= 20
                run = [zero_count, 51].min
                encode_pretree_symbol(18)
                @bitstream.write_bits(run - 20, 5)
                zero_count -= run
              end
            end

            if zero_count >= 4
              # Use code 17 for medium runs (4-19)
              run = [zero_count, 19].min
              encode_pretree_symbol(17)
              @bitstream.write_bits(run - 4, 4)
            elsif zero_count.positive?
              # Encode short runs individually
              zero_count.times do
                delta = (17 - prev_length) % 17
                encode_pretree_symbol(delta)
                prev_length = 0
              end
            end
          else
            # Encode as delta from previous
            delta = (length - prev_length) % 17
            encode_pretree_symbol(delta)
            prev_length = length
            i += 1
          end
        end
      end

      # Encode a pretree symbol
      #
      # @param symbol [Integer] Symbol to encode
      # @return [void]
      def encode_pretree_symbol(symbol)
        code_entry = @pretree_codes[symbol]
        return unless code_entry

        @bitstream.write_bits(code_entry[:code], code_entry[:bits])
      end

      # Encode tokens using Huffman codes
      #
      # @param tokens [Array<Hash>] Tokens to encode
      # @return [void]
      def encode_tokens(tokens)
        tokens.each do |token|
          if token[:type] == :literal
            encode_literal(token[:value])
          else
            encode_match(token[:length], token[:offset])
          end
        end
      end

      # Encode a literal byte
      #
      # @param byte [Integer] Byte value
      # @return [void]
      def encode_literal(byte)
        code_entry = @maintree_codes[byte]
        return unless code_entry

        @bitstream.write_bits(code_entry[:code], code_entry[:bits])
      end

      # Encode a match
      #
      # @param length [Integer] Match length
      # @param offset [Integer] Match offset
      # @return [void]
      def encode_match(length, offset)
        # Get position slot
        position_slot = get_position_slot(offset)

        # Calculate main element
        length_header = [length - MIN_MATCH, NUM_PRIMARY_LENGTHS].min
        main_element = NUM_CHARS + (position_slot << 3) + length_header

        # Encode main element
        code_entry = @maintree_codes[main_element]
        if code_entry
          @bitstream.write_bits(code_entry[:code],
                                code_entry[:bits])
        end

        # Encode length footer if needed
        if length_header == NUM_PRIMARY_LENGTHS
          length_footer = length - MIN_MATCH - NUM_PRIMARY_LENGTHS
          length_entry = @length_codes[length_footer]
          if length_entry
            @bitstream.write_bits(length_entry[:code],
                                  length_entry[:bits])
          end
        end

        # Encode position extra bits
        encode_position_extra_bits(offset, position_slot)

        # Update R0, R1, R2
        update_offset_cache(offset)
      end

      # Encode position extra bits
      #
      # @param offset [Integer] Match offset
      # @param position_slot [Integer] Position slot
      # @return [void]
      def encode_position_extra_bits(offset, position_slot)
        return if position_slot < 2

        extra_bits = position_slot >= 36 ? 17 : EXTRA_BITS[position_slot]
        return if extra_bits.zero?

        base = POSITION_BASE[position_slot]
        extra_value = offset - base

        @bitstream.write_bits(extra_value, extra_bits)
      end

      # Update offset cache (R0, R1, R2)
      #
      # @param offset [Integer] New offset
      # @return [void]
      def update_offset_cache(offset)
        # Don't update for repeated offsets
        return if [@r0, @r1, @r2].include?(offset)

        @r2 = @r1
        @r1 = @r0
        @r0 = offset
      end
    end
  end
end
