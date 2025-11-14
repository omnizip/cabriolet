# frozen_string_literal: true

module Cabriolet
  module Binary
    # Bitstream provides bit-level I/O operations for reading compressed data
    class Bitstream
      attr_reader :io_system, :handle, :buffer_size

      # Initialize a new bitstream
      #
      # @param io_system [System::IOSystem] I/O system for reading data
      # @param handle [System::FileHandle, System::MemoryHandle] Handle to read from
      # @param buffer_size [Integer] Size of the input buffer
      def initialize(io_system, handle,
buffer_size = Cabriolet.default_buffer_size)
        @io_system = io_system
        @handle = handle
        @buffer_size = buffer_size
        @buffer = ""
        @buffer_pos = 0
        @bit_buffer = 0
        @bits_left = 0
      end

      # Read specified number of bits from the stream
      #
      # @param num_bits [Integer] Number of bits to read (1-32)
      # @return [Integer] Bits read as an integer
      # @raise [DecompressionError] if unable to read required bits
      def read_bits(num_bits)
        if num_bits < 1 || num_bits > 32
          raise ArgumentError,
                "Can only read 1-32 bits at a time"
        end

        # Ensure we have enough bits in the buffer
        while @bits_left < num_bits
          byte = read_byte
          return 0 if byte.nil? # EOF

          @bit_buffer |= (byte << @bits_left)
          @bits_left += 8
        end

        # Extract the requested bits
        result = @bit_buffer & ((1 << num_bits) - 1)
        @bit_buffer >>= num_bits
        @bits_left -= num_bits

        result
      end

      # Read a single byte from the input
      #
      # @return [Integer, nil] Byte value or nil at EOF
      def read_byte
        if @buffer_pos >= @buffer.bytesize
          @buffer = @io_system.read(@handle, @buffer_size)
          @buffer_pos = 0
          return nil if @buffer.empty?
        end

        byte = @buffer.getbyte(@buffer_pos)
        @buffer_pos += 1
        byte
      end

      # Align to the next byte boundary
      #
      # @return [void]
      def byte_align
        discard_bits = @bits_left % 8
        @bit_buffer >>= discard_bits
        @bits_left -= discard_bits
      end

      # Peek at bits without consuming them
      #
      # @param num_bits [Integer] Number of bits to peek at
      # @return [Integer] Bits as an integer
      def peek_bits(num_bits)
        if num_bits < 1 || num_bits > 32
          raise ArgumentError,
                "Can only peek 1-32 bits at a time"
        end

        # Ensure we have enough bits
        while @bits_left < num_bits
          byte = read_byte
          return 0 if byte.nil?

          @bit_buffer |= (byte << @bits_left)
          @bits_left += 8
        end

        @bit_buffer & ((1 << num_bits) - 1)
      end

      # Skip specified number of bits
      #
      # @param num_bits [Integer] Number of bits to skip
      # @return [void]
      def skip_bits(num_bits)
        read_bits(num_bits)
        nil
      end

      # Read bits in big-endian (MSB first) order
      #
      # @param num_bits [Integer] Number of bits to read
      # @return [Integer] Bits as an integer
      def read_bits_be(num_bits)
        result = 0
        num_bits.times do
          result = (result << 1) | read_bits(1)
        end
        result
      end

      # Read a 16-bit little-endian value
      #
      # @return [Integer] 16-bit value
      def read_uint16_le
        read_bits(16)
      end

      # Read a 32-bit little-endian value
      #
      # @return [Integer] 32-bit value
      def read_uint32_le
        low = read_bits(16)
        high = read_bits(16)
        (high << 16) | low
      end

      # Reset the bitstream state
      #
      # @return [void]
      def reset
        @buffer = ""
        @buffer_pos = 0
        @bit_buffer = 0
        @bits_left = 0
        @io_system.seek(@handle, 0, Constants::SEEK_START)
      end
    end
  end
end
