# frozen_string_literal: true

require_relative "../binary/bitstream_writer"
require_relative "../huffman/encoder"

module Cabriolet
  module Compressors
    # MSZIP handles MSZIP (DEFLATE) compression
    # Based on RFC 1951 and libmspack implementation
    class MSZIP < Base
      # MSZIP frame size (32KB sliding window)
      FRAME_SIZE = 32_768

      # MSZIP signature bytes
      SIGNATURE = [0x43, 0x4B].freeze # 'CK'

      # Block types
      STORED_BLOCK = 0
      FIXED_HUFFMAN_BLOCK = 1
      DYNAMIC_HUFFMAN_BLOCK = 2

      # Match length constants
      MIN_MATCH = 3
      MAX_MATCH = 258

      # Window size for LZ77
      WINDOW_SIZE = 32_768

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

      # Initialize MSZIP compressor
      #
      # @param io_system [System::IOSystem] I/O system for reading/writing
      # @param input [System::FileHandle, System::MemoryHandle] Input handle
      # @param output [System::FileHandle, System::MemoryHandle] Output handle
      # @param buffer_size [Integer] Buffer size for I/O operations
      def initialize(io_system, input, output, buffer_size, **_kwargs)
        super

        # Initialize bitstream writer
        @bitstream = Binary::BitstreamWriter.new(io_system, output, buffer_size)

        # Build fixed Huffman codes
        @fixed_codes = Huffman::Encoder.build_fixed_codes

        # Initialize sliding window for LZ77
        @window = "\0" * WINDOW_SIZE
        @window_pos = 0
      end

      # Compress input data using MSZIP (DEFLATE) algorithm
      #
      # @return [Integer] Number of bytes written
      def compress
        input_data = read_all_input
        total_written = 0
        pos = 0

        # Handle empty input - still need to write a block
        if input_data.empty?
          write_signature
          compress_block("", true)
          @bitstream.flush
          return 0
        end

        # Process data in FRAME_SIZE chunks
        # Each frame is independent and contains blocks ending with last_block=1
        while pos < input_data.bytesize
          chunk_size = [FRAME_SIZE, input_data.bytesize - pos].min
          chunk = input_data[pos, chunk_size]

          # Write CK signature
          write_signature

          # Compress block with fixed Huffman
          # Each frame's block is always marked as last within that frame
          compress_block(chunk, true)

          pos += chunk_size
          total_written += chunk_size
        end

        # Flush any remaining bits
        @bitstream.flush

        total_written
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

      # Write MSZIP signature (CK)
      #
      # @return [void]
      def write_signature
        @bitstream.byte_align
        SIGNATURE.each { |byte| @bitstream.write_raw_byte(byte) }
      end

      # Compress a single block using fixed Huffman encoding
      #
      # @param data [String] Data to compress
      # @param is_last [Boolean] Whether this is the last block
      # @return [void]
      def compress_block(data, is_last)
        # Write block header
        @bitstream.write_bits(is_last ? 1 : 0, 1) # Last block flag
        @bitstream.write_bits(FIXED_HUFFMAN_BLOCK, 2) # Block type

        # Reset window position for this block
        @window_pos = 0

        # Encode data using LZ77 and Huffman
        encode_data(data)

        # Write end-of-block symbol (256)
        encode_literal(256)
      end

      # Encode data using LZ77 matching and Huffman encoding
      #
      # @param data [String] Data to encode
      # @return [void]
      def encode_data(data)
        pos = 0

        while pos < data.bytesize
          # Try to find a match in the window
          match = find_match(data, pos)

          if match && match[:length] >= MIN_MATCH
            # Encode as length/distance pair
            encode_match(match[:length], match[:distance])

            # Add matched bytes to window
            match[:length].times do
              add_to_window(data.getbyte(pos))
              pos += 1
            end
          else
            # Encode as literal
            byte = data.getbyte(pos)
            encode_literal(byte)
            add_to_window(byte)
            pos += 1
          end
        end
      end

      # Find the longest match in the sliding window
      #
      # @param data [String] Input data
      # @param pos [Integer] Current position in data
      # @return [Hash, nil] Match info with :length and :distance, or nil
      def find_match(data, pos)
        return nil if pos >= data.bytesize

        best_match = nil
        max_length = [MAX_MATCH, data.bytesize - pos].min

        # Don't search if we can't get MIN_MATCH
        return nil if max_length < MIN_MATCH

        # Search window for matches (simple greedy search)
        # Start from most recent positions for better compression
        search_start = [@window_pos - WINDOW_SIZE, 0].max
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

          distance = @window_pos - win_pos
          best_match = { length: length, distance: distance }

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
        @window.setbyte(@window_pos % WINDOW_SIZE, byte)
        @window_pos += 1
      end

      # Encode a literal byte using fixed Huffman codes
      #
      # @param byte [Integer] Byte value (0-255) or end-of-block (256)
      # @return [void]
      def encode_literal(byte)
        Huffman::Encoder.encode_symbol(byte, @fixed_codes[:literal], @bitstream)
      end

      # Encode a match as length/distance pair
      #
      # @param length [Integer] Match length (3-258)
      # @param distance [Integer] Match distance (1-32768)
      # @return [void]
      def encode_match(length, distance)
        # Encode length
        length_code, extra_bits, extra_value = encode_length(length)
        Huffman::Encoder.encode_symbol(length_code, @fixed_codes[:literal],
                                       @bitstream)
        @bitstream.write_bits(extra_value, extra_bits) if extra_bits.positive?

        # Encode distance
        dist_code, extra_bits, extra_value = encode_distance(distance)
        Huffman::Encoder.encode_symbol(dist_code, @fixed_codes[:distance],
                                       @bitstream)
        @bitstream.write_bits(extra_value, extra_bits) if extra_bits.positive?
      end

      # Encode length into length code and extra bits
      #
      # @param length [Integer] Match length (3-258)
      # @return [Array<Integer>] [code, extra_bits, extra_value]
      def encode_length(length)
        # Handle edge case for length 258 (max length)
        return [285, 0, 0] if length == 258

        # Find the appropriate length code
        LIT_LENGTHS.each_with_index do |base_length, index|
          next if index >= 29 # Only codes 0-28 are valid

          extra_bits = LIT_EXTRABITS[index]
          max_length = if index == 28
                         258 # Last code handles length 258
                       else
                         base_length + (1 << extra_bits) - 1
                       end

          next unless length.between?(base_length, max_length)

          code = 257 + index
          extra_value = length - base_length
          return [code, extra_bits, extra_value]
        end

        # Should not reach here
        raise Errors::CompressionError, "Invalid length: #{length}"
      end

      # Encode distance into distance code and extra bits
      #
      # @param distance [Integer] Match distance (1-32768)
      # @return [Array<Integer>] [code, extra_bits, extra_value]
      def encode_distance(distance)
        # Find the appropriate distance code (only 0-29 are valid)
        (0...30).each do |code|
          base_offset = DIST_OFFSETS[code]
          extra_bits = DIST_EXTRABITS[code]
          max_offset = base_offset + (1 << extra_bits) - 1

          if distance.between?(base_offset, max_offset)
            extra_value = distance - base_offset
            return [code, extra_bits, extra_value]
          end
        end

        # Should not reach here
        raise Errors::CompressionError, "Invalid distance: #{distance}"
      end
    end
  end
end
