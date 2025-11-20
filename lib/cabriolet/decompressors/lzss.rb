# frozen_string_literal: true

module Cabriolet
  module Decompressors
    # LZSS decompressor for LZSS-compressed CAB data
    #
    # LZSS (Lempel-Ziv-Storer-Szymanski) is a derivative of LZ77 compression.
    # It uses a 4096-byte sliding window with a control byte mechanism to
    # indicate whether the next operation is a literal byte copy or a match
    # from the window history.
    class LZSS < Base
      # LZSS algorithm constants
      WINDOW_SIZE = 4096
      WINDOW_FILL = 0x20

      # LZSS modes
      MODE_EXPAND = 0
      MODE_MSHELP = 1
      MODE_QBASIC = 2

      attr_reader :mode, :window, :window_pos

      # Initialize LZSS decompressor
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
        @input_buffer = ""
        @input_pos = 0
        @invert = mode == MODE_MSHELP ? 0xFF : 0x00
      end

      # Decompress LZSS data
      #
      # @param bytes [Integer, nil] Maximum number of output bytes to write (nil or 0 = until EOF)
      # @return [Integer] Number of bytes decompressed
      def decompress(bytes = nil)
        bytes_written = 0
        # Only enforce limit if bytes is a positive integer
        enforce_limit = bytes && bytes.positive?

        loop do
          # Check if we've reached the output byte limit (only when limit is enforced)
          break if enforce_limit && bytes_written >= bytes

          # Read control byte
          control_byte = read_input_byte
          break if control_byte.nil?

          control_byte ^= @invert

          # Process each bit in the control byte
          8.times do |bit_index|
            # Check output limit before each operation (only when limit is enforced)
            break if enforce_limit && bytes_written >= bytes

            mask = 1 << bit_index

            if control_byte.anybits?(mask)
              # Bit is 1: literal byte
              literal = read_input_byte
              break if literal.nil?

              @window[@window_pos] = literal
              write_output_byte(literal)
              bytes_written += 1

              @window_pos = (@window_pos + 1) & (WINDOW_SIZE - 1)
            else
              # Bit is 0: match from window
              offset_low = read_input_byte
              break if offset_low.nil?

              offset_high_and_length = read_input_byte
              break if offset_high_and_length.nil?

              # Decode match position and length
              match_pos = offset_low | ((offset_high_and_length & 0xF0) << 4)
              length = (offset_high_and_length & 0x0F) + 3

              # Copy from window
              length.times do
                # Check if we've reached the limit mid-match
                break if enforce_limit && bytes_written >= bytes

                byte = @window[match_pos]
                @window[@window_pos] = byte
                write_output_byte(byte)
                bytes_written += 1

                @window_pos = (@window_pos + 1) & (WINDOW_SIZE - 1)
                match_pos = (match_pos + 1) & (WINDOW_SIZE - 1)
              end
            end
          end
        end

        bytes_written
      end

      private

      # Initialize the window position based on mode
      #
      # @return [Integer] Initial window position
      def initialize_window_position
        offset = @mode == MODE_QBASIC ? 18 : 16
        WINDOW_SIZE - offset
      end

      # Read a single byte from the input buffer
      #
      # @return [Integer, nil] Byte value or nil at EOF
      def read_input_byte
        if @input_pos >= @input_buffer.bytesize
          @input_buffer = @io_system.read(@input, @buffer_size)
          @input_pos = 0
          return nil if @input_buffer.empty?
        end

        byte = @input_buffer.getbyte(@input_pos)
        @input_pos += 1
        byte
      end

      # Write a single byte to the output
      #
      # @param byte [Integer] Byte to write
      # @return [void]
      # @raise [Errors::DecompressionError] if write fails
      def write_output_byte(byte)
        data = [byte].pack("C")
        written = @io_system.write(@output, data)
        return if written == 1

        raise Errors::DecompressionError, "Failed to write output byte"
      end
    end
  end
end
