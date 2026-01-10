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
      # @param bit_order [Symbol] Bit ordering - :lsb (default) or :msb
      # @param msb_first [Boolean] Deprecated: use bit_order instead
      def initialize(io_system, handle,
 buffer_size = Cabriolet.default_buffer_size, bit_order: :lsb, msb_first: false)
        @io_system = io_system
        @handle = handle
        @buffer_size = buffer_size

        # Support legacy msb_first parameter or new bit_order parameter
        @bit_order = msb_first ? :msb : bit_order
        @msb_first = (@bit_order == :msb)

        @bit_buffer = 0
        @bits_in_buffer = 0
        @accumulated = 0
        @bits_accumulated = 0
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

        # Delegate to MSB method if in MSB mode
        if @bit_order == :msb
          write_bits_msb_internal(value, num_bits)
          return
        end

        # LSB-first mode (default)
        # Mask value to num_bits
        value &= (1 << num_bits) - 1

        # Accumulate bits
        @accumulated |= (value << @bits_accumulated)
        @bits_accumulated += num_bits

        # Transfer accumulated bits to buffer in 8-bit chunks
        while @bits_accumulated >= 8
          # Take the lowest 8 bits from accumulated
          byte = @accumulated & 0xFF
          @accumulated >>= 8
          @bits_accumulated -= 8

          # Add to buffer
          @bit_buffer |= (byte << @bits_in_buffer)
          @bits_in_buffer += 8

          # Flush complete bytes from buffer
          while @bits_in_buffer >= 8
            flush_byte = @bit_buffer & 0xFF
            write_byte(flush_byte)
            @bit_buffer >>= 8
            @bits_in_buffer -= 8
          end
        end
      end

      # Align to the next byte boundary by padding with zeros
      #
      # @return [void]
      def byte_align
        if @bit_order == :msb
          # MSB mode: align to 16-bit boundary (like Bitstream reader)
          return if @bits_in_buffer.zero?

          padding = (16 - @bits_in_buffer) % 16
          if padding.positive?
            write_bits(0, padding)
          end
        else
          # LSB mode: align to 8-bit boundary
          return if @bits_accumulated.zero?

          padding = (8 - @bits_accumulated) % 8
          if padding.positive?
            write_bits(0, padding)
          end
        end
      end

      # Flush any remaining bits in the buffer
      #
      # @return [void]
      def flush
        # For MSB mode, use the special MSB flush
        if @bit_order == :msb
          flush_msb_internal
          return
        end

        # LSB mode flush
        # First flush any accumulated bits
        if @bits_accumulated.positive?
          byte = @accumulated & 0xFF
          write_byte(byte)
          @accumulated = 0
          @bits_accumulated = 0
        end

        # Then flush buffer
        return if @bits_in_buffer.zero?

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
        # DEBUG
        $stderr.puts "DEBUG write_byte: pos=#{@bits_in_buffer} byte=#{byte} (#{byte.to_s(2).rjust(8, '0')})" if ENV['DEBUG_BITSTREAM']
        @io_system.write(@handle, data)
      end

      # Write bits in MSB-first mode (internal implementation)
      # Matches the behavior of Bitstream's MSB mode for reading
      #
      # @param value [Integer] Value to write
      # @param num_bits [Integer] Number of bits to write
      # @return [void]
      def write_bits_msb_internal(value, num_bits)
        # Mask value to num_bits
        value &= (1 << num_bits) - 1

        # Add bits to buffer (MSB first - inject at left side)
        @bit_buffer = (@bit_buffer << num_bits) | value
        @bits_in_buffer += num_bits

        # Flush complete 16-bit words
        # The most significant bits are at the left of the buffer
        # We want to extract the highest 16 bits and keep the rest
        while @bits_in_buffer >= 16
          # Extract the highest 16 bits by shifting right by (bits_in_buffer - 16)
          # This moves the top 16 bits to positions 0-15
          @bits_in_buffer -= 16
          shift = @bits_in_buffer
          word = (@bit_buffer >> shift) & 0xFFFF
          # Write little-endian (LSB byte first, then MSB byte) to match Bitstream reader
          write_byte(word & 0xFF)
          write_byte((word >> 8) & 0xFF)
        end
      end

      # Flush MSB buffer (internal implementation)
      # Write remaining bits padded to 16-bit boundary
      #
      # @return [void]
      def flush_msb_internal
        return if @bits_in_buffer.zero?

        # Pad to 16-bit boundary
        padding = (16 - @bits_in_buffer) % 16
        @bit_buffer <<= padding if padding.positive?
        @bits_in_buffer += padding

        # Write final 16-bit word
        if @bits_in_buffer == 16
          word = @bit_buffer & 0xFFFF
          # Write little-endian (LSB byte first, then MSB byte) to match Bitstream reader
          write_byte(word & 0xFF)
          write_byte((word >> 8) & 0xFF)
        end

        @bit_buffer = 0
        @bits_in_buffer = 0
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
