# frozen_string_literal: true

module Cabriolet
  module Compressors
    # LZSS compressor for creating LZSS-compressed data
    #
    # LZSS (Lempel-Ziv-Storer-Szymanski) is a derivative of LZ77 compression.
    # It uses a 4096-byte sliding window with a control byte mechanism to
    # indicate whether the next operation is a literal byte copy or a match
    # from the window history.
    #
    # The compression algorithm searches for matching sequences in the sliding
    # window and encodes them as (offset, length) pairs when the match is 3 or
    # more bytes. Shorter sequences are encoded as literal bytes.
    class LZSS < Base
      # LZSS algorithm constants
      WINDOW_SIZE = 4096
      WINDOW_FILL = 0x20
      MIN_MATCH = 3
      MAX_MATCH = 18 # 0x0F + 3

      # LZSS modes
      MODE_EXPAND = 0
      MODE_MSHELP = 1
      MODE_QBASIC = 2

      attr_reader :mode, :window, :window_pos

      # Initialize LZSS compressor
      #
      # @param io_system [System::IOSystem] I/O system for reading/writing
      # @param input [System::FileHandle, System::MemoryHandle] Input handle
      # @param output [System::FileHandle, System::MemoryHandle] Output handle
      # @param buffer_size [Integer] Buffer size for I/O operations
      # @param mode [Integer] LZSS mode (default: MODE_EXPAND)
      def initialize(io_system, input, output, buffer_size,
                     mode = MODE_EXPAND)
        super(io_system, input, output, buffer_size)
        @mode = mode
        @window = Array.new(WINDOW_SIZE, WINDOW_FILL)
        @window_pos = initialize_window_position
        @invert = mode == MODE_MSHELP ? 0xFF : 0x00
      end

      # Compress input data using LZSS algorithm
      #
      # @return [Integer] Number of bytes written
      def compress
        bytes_written = 0
        input_data = read_all_input
        input_pos = 0

        while input_pos < input_data.bytesize
          control_byte, encoded_ops, input_pos = process_block(
            input_data,
            input_pos,
          )
          bytes_written += write_block(control_byte, encoded_ops)
        end

        bytes_written
      end

      private

      # Process up to 8 operations for one control byte
      #
      # @param input_data [String] Input data being compressed
      # @param input_pos [Integer] Current position in input
      # @return [Array] control_byte, encoded_ops, new_input_pos
      def process_block(input_data, input_pos)
        control_bits = []
        encoded_ops = []

        8.times do
          break if input_pos >= input_data.bytesize

          match = find_match(input_data, input_pos)

          if match && match[:length] >= MIN_MATCH
            control_bits << 0
            encoded_ops << encode_match(match[:offset], match[:length])
            input_pos = add_match_to_window(input_data, input_pos,
                                            match[:length])
          else
            control_bits << 1
            byte = input_data.getbyte(input_pos)
            encoded_ops << [byte].pack("C")
            input_pos = add_byte_to_window(byte, input_pos)
          end
        end

        control_byte = build_control_byte(control_bits)
        [control_byte, encoded_ops, input_pos]
      end

      # Build control byte from control bits
      #
      # @param control_bits [Array<Integer>] Array of bits (0 or 1)
      # @return [Integer] Control byte value
      def build_control_byte(control_bits)
        control_byte = 0
        control_bits.each_with_index do |bit, index|
          control_byte |= (bit << index)
        end
        control_byte ^ @invert
      end

      # Write control byte and encoded operations
      #
      # @param control_byte [Integer] Control byte value
      # @param encoded_ops [Array<String>] Encoded operations
      # @return [Integer] Number of bytes written
      def write_block(control_byte, encoded_ops)
        bytes = write_output_byte(control_byte)
        encoded_ops.each do |data|
          bytes += write_output_data(data)
        end
        bytes
      end

      # Add matched bytes to window
      #
      # @param input_data [String] Input data
      # @param input_pos [Integer] Current input position
      # @param length [Integer] Number of bytes to add
      # @return [Integer] New input position
      def add_match_to_window(input_data, input_pos, length)
        length.times do
          @window[@window_pos] = input_data.getbyte(input_pos)
          @window_pos = (@window_pos + 1) & (WINDOW_SIZE - 1)
          input_pos += 1
        end
        input_pos
      end

      # Add single byte to window
      #
      # @param byte [Integer] Byte value
      # @param input_pos [Integer] Current input position
      # @return [Integer] New input position
      def add_byte_to_window(byte, input_pos)
        @window[@window_pos] = byte
        @window_pos = (@window_pos + 1) & (WINDOW_SIZE - 1)
        input_pos + 1
      end

      # Initialize the window position based on mode
      #
      # @return [Integer] Initial window position
      def initialize_window_position
        offset = @mode == MODE_QBASIC ? 18 : 16
        WINDOW_SIZE - offset
      end

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

      # Find the longest match in the sliding window
      #
      # @param input_data [String] Input data being compressed
      # @param input_pos [Integer] Current position in input
      # @return [Hash, nil] Hash with :offset and :length, or nil if no match
      def find_match(input_data, input_pos)
        best_match = nil
        max_length = [MAX_MATCH, input_data.bytesize - input_pos].min

        # Don't search if we can't even get a MIN_MATCH
        return nil if max_length < MIN_MATCH

        # Search the entire window for matches
        WINDOW_SIZE.times do |offset|
          length = 0

          # Count matching bytes
          while length < max_length &&
              input_data.getbyte(input_pos + length) ==
                  @window[(offset + length) & (WINDOW_SIZE - 1)]
            length += 1
          end

          # Update best match if this is longer
          next unless length >= MIN_MATCH &&
            (best_match.nil? || length > best_match[:length])

          best_match = { offset: offset, length: length }

          # Stop if we found the maximum possible match
          break if length == MAX_MATCH
        end

        best_match
      end

      # Encode a match as two bytes
      #
      # @param offset [Integer] Offset into window (0-4095)
      # @param length [Integer] Length of match (3-18)
      # @return [String] Two-byte encoded match
      def encode_match(offset, length)
        offset_low = offset & 0xFF
        offset_high = (offset >> 8) & 0x0F
        length_encoded = (length - 3) & 0x0F

        byte1 = offset_low
        byte2 = (offset_high << 4) | length_encoded

        [byte1, byte2].pack("C2")
      end

      # Write a single byte to the output
      #
      # @param byte [Integer] Byte to write
      # @return [Integer] Number of bytes written (1)
      # @raise [Errors::CompressionError] if write fails
      def write_output_byte(byte)
        data = [byte].pack("C")
        written = @io_system.write(@output, data)
        return written if written == 1

        raise Errors::CompressionError, "Failed to write output byte"
      end

      # Write data to the output
      #
      # @param data [String] Data to write
      # @return [Integer] Number of bytes written
      # @raise [Errors::CompressionError] if write fails
      def write_output_data(data)
        written = @io_system.write(@output, data)
        return written if written == data.bytesize

        raise Errors::CompressionError,
              "Failed to write output data (expected #{data.bytesize}, " \
              "wrote #{written})"
      end
    end
  end
end
