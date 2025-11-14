# frozen_string_literal: true

module Cabriolet
  module Binary
    # BitstreamWriter provides bit-level I/O operations for writing compressed data
    class BitstreamWriter
      attr_reader :io_system, :handle, :buffer_size

      # Initialize a new bitstream writer
      #
      # @param io_system [System::IOSystem] I/O system for writing data
      # @param handle [System::FileHandle, System::MemoryHandle] Handle to write to
      # @param buffer_size [Integer] Size of the output buffer
      # @param msb_first [Boolean] Whether to write bits MSB-first (for Quantum)
      def initialize(io_system, handle,
buffer_size = Cabriolet.default_buffer_size, msb_first: false)
        @io_system = io_system
        @handle = handle
        @buffer_size = buffer_size
        @msb_first = msb_first
        @bit_buffer = 0
        @bits_in_buffer = 0
      end

      # Write specified number of bits to the stream
      #
      # @param value [Integer] Value to write
      # @param num_bits [Integer] Number of bits to write (1-32)
      # @return [void]
      # @raise [ArgumentError] if num_bits is out of range
      def write_bits(value, num_bits)
        if num_bits < 1 || num_bits > 32
          raise ArgumentError,
                "Can only write 1-32 bits at a time"
        end

        # Add bits to buffer (LSB first, like DEFLATE)
        @bit_buffer |= ((value & ((1 << num_bits) - 1)) << @bits_in_buffer)
        @bits_in_buffer += num_bits

        # Flush complete bytes
        while @bits_in_buffer >= 8
          byte = @bit_buffer & 0xFF
          write_byte(byte)
          @bit_buffer >>= 8
          @bits_in_buffer -= 8
        end
      end

      # Align to the next byte boundary by padding with zeros
      #
      # @return [void]
      def byte_align
        return if @bits_in_buffer.zero?

        # Pad with zeros to complete the current byte
        padding_bits = 8 - (@bits_in_buffer % 8)
        write_bits(0, padding_bits) if padding_bits < 8
      end

      # Flush any remaining bits in the buffer
      #
      # @return [void]
      def flush
        return if @bits_in_buffer.zero?

        # Write any remaining bits (padded with zeros)
        byte = @bit_buffer & 0xFF
        write_byte(byte)
        @bit_buffer = 0
        @bits_in_buffer = 0
      end

      # Write a single byte to the output
      #
      # @param byte [Integer] Byte value to write
      # @return [void]
      def write_byte(byte)
        data = [byte].pack("C")
        @io_system.write(@handle, data)
      end

      # Write a raw byte directly (for signatures, etc.)
      # This ensures the bit buffer is flushed first
      #
      # @param byte [Integer] Byte value to write
      # @return [void]
      def write_raw_byte(byte)
        flush if @bits_in_buffer.positive?
        write_byte(byte)
      end

      # Write multiple bytes to the output
      #
      # @param bytes [String, Array<Integer>] Bytes to write
      # @return [void]
      def write_bytes(bytes)
        data = bytes.is_a?(String) ? bytes : bytes.pack("C*")
        @io_system.write(@handle, data)
      end

      # Write bits in big-endian (MSB first) order
      #
      # @param value [Integer] Value to write
      # @param num_bits [Integer] Number of bits to write
      # @return [void]
      def write_bits_be(value, num_bits)
        num_bits.times do |i|
          bit = (value >> (num_bits - 1 - i)) & 1
          write_bits(bit, 1)
        end
      end

      # Write a 16-bit little-endian value
      #
      # @param value [Integer] 16-bit value
      # @return [void]
      def write_uint16_le(value)
        write_bits(value & 0xFFFF, 16)
      end

      # Write a 32-bit little-endian value
      #
      # @param value [Integer] 32-bit value
      # @return [void]
      def write_uint32_le(value)
        write_bits(value & 0xFFFF, 16)
        write_bits((value >> 16) & 0xFFFF, 16)
      end

      # Write bits MSB-first (for Quantum compression)
      # Accumulates bits and writes 16-bit words MSB-first
      #
      # @param value [Integer] Value to write
      # @param num_bits [Integer] Number of bits to write
      # @return [void]
      def write_bits_msb(value, num_bits)
        if num_bits < 1 || num_bits > 32
          raise ArgumentError,
                "Can only write 1-32 bits at a time"
        end

        # Add bits to buffer (MSB first)
        @bit_buffer = (@bit_buffer << num_bits) | (value & ((1 << num_bits) - 1))
        @bits_in_buffer += num_bits

        # Flush complete 16-bit words MSB-first
        while @bits_in_buffer >= 16
          @bits_in_buffer -= 16
          word = (@bit_buffer >> @bits_in_buffer) & 0xFFFF
          # Write MSB first
          write_byte((word >> 8) & 0xFF)
          write_byte(word & 0xFF)
        end
      end

      # Flush MSB buffer (write remaining bits padded to 16-bit boundary)
      #
      # @return [void]
      def flush_msb
        return if @bits_in_buffer.zero?

        # Pad to 16-bit boundary
        padding = (16 - @bits_in_buffer) % 16
        @bit_buffer <<= padding if padding.positive?
        @bits_in_buffer += padding

        # Write final 16-bit word
        if @bits_in_buffer == 16
          word = @bit_buffer & 0xFFFF
          write_byte((word >> 8) & 0xFF)
          write_byte(word & 0xFF)
        end

        @bit_buffer = 0
        @bits_in_buffer = 0
      end
    end
  end
end
