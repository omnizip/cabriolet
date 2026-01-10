# frozen_string_literal: true

module Cabriolet
  module Binary
    # Bitstream provides bit-level I/O operations for reading compressed data
    class Bitstream
      attr_reader :io_system, :handle, :buffer_size, :bit_order

      # Initialize a new bitstream
      #
      # @param io_system [System::IOSystem] I/O system for reading data
      # @param handle [System::FileHandle, System::MemoryHandle] Handle to read from
      # @param buffer_size [Integer] Size of the input buffer
      # @param bit_order [Symbol] Bit order (:lsb or :msb)
      # @param salvage [Boolean] Salvage mode - return 0 on EOF instead of raising
      def initialize(io_system, handle, buffer_size = Cabriolet.default_buffer_size, bit_order: :lsb, salvage: false)
        @io_system = io_system
        @handle = handle
        @buffer_size = buffer_size
        @bit_order = bit_order
        @salvage = salvage
        @buffer = ""
        @buffer_pos = 0
        @bit_buffer = 0
        @bits_left = 0
        @input_end = false  # Track EOF state (matches libmspack's input_end flag)

        # For MSB mode, we need to know the bit width of the buffer
        # Ruby integers are arbitrary precision, so we use 32 bits as standard
        @bitbuf_width = 32
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

        if @bit_order == :msb
          read_bits_msb(num_bits)
        else
          read_bits_lsb(num_bits)
        end
      end

      private

      # Read bits in LSB-first order
      #
      # Per libmspack: EOF handling allows padding to avoid bitstream overrun.
      # First EOF: pad with zeros (2 bytes worth). Second EOF: raise error.
      def read_bits_lsb(num_bits)
        # Ensure we have enough bits in the buffer
        while @bits_left < num_bits
          byte = read_byte
          # First EOF: pad with zeros (matches libmspack read_input behavior)
          # On second EOF, read_byte will raise DecompressionError
          # In salvage mode, pad indefinitely; otherwise pad on first EOF
          byte = 0 if byte.nil?

          # DEBUG
          $stderr.puts "DEBUG LSB read_byte: buffer_pos=#{@buffer_pos} byte=#{byte} (#{byte.to_s(2).rjust(8, '0')}) bits_left=#{@bits_left}" if ENV['DEBUG_BITSTREAM']

          # INJECT_BITS (LSB): append to the right
          @bit_buffer |= (byte << @bits_left)
          @bits_left += 8
        end

        # PEEK_BITS (LSB): extract from the right
        result = @bit_buffer & ((1 << num_bits) - 1)
        # REMOVE_BITS (LSB): shift right
        @bit_buffer >>= num_bits
        @bits_left -= num_bits

        # DEBUG
        $stderr.puts "DEBUG LSB read_bits(#{num_bits}): result=#{result} buffer=#{@bit_buffer.to_s(16)} bits_left=#{@bits_left}" if ENV['DEBUG_BITSTREAM']

        result
      end

      # Read bits in MSB-first order (libmspack LZX/Quantum style)
      #
      # Per libmspack readbits.h: Reads 2 bytes at a time (little-endian 16-bit word).
      # EOF handling: First EOF pads with zeros, second EOF raises error.
      def read_bits_msb(num_bits)
        # Ensure we have enough bits in the buffer
        while @bits_left < num_bits
          # Read 2 bytes at a time (little-endian), like libmspack
          byte0 = read_byte
          if byte0.nil?
            # First EOF: pad with zeros
            # Second EOF: read_byte will raise DecompressionError
            byte0 = 0 if @salvage || @input_end
          end

          byte1 = read_byte
          if byte1.nil?
            # Pad with 0 if only 1 byte left (or EOF)
            byte1 = 0
          end

          # Combine as little-endian 16-bit value
          word = byte0 | (byte1 << 8)

          # DEBUG
          $stderr.puts "DEBUG MSB read_bytes: byte0=0x#{byte0.to_s(16)} byte1=0x#{byte1.to_s(16)} word=0x#{word.to_s(16)} bits_left=#{@bits_left}" if ENV['DEBUG_BITSTREAM']

          # INJECT_BITS (MSB): inject at the left side
          # bit_buffer |= word << (BITBUF_WIDTH -16 - bits_left)
          @bit_buffer |= (word << (@bitbuf_width - 16 - @bits_left))
          @bits_left += 16
        end

        # PEEK_BITS (MSB): extract from the left
        # result = bit_buffer >> (BITBUF_WIDTH - num_bits)
        result = @bit_buffer >> (@bitbuf_width - num_bits)

        # REMOVE_BITS (MSB): shift left
        @bit_buffer = (@bit_buffer << num_bits) & ((1 << @bitbuf_width) - 1)
        @bits_left -= num_bits

        # DEBUG
        $stderr.puts "DEBUG MSB read_bits(#{num_bits}) result=#{result} (0x#{result.to_s(16)}) buffer=0x#{@bit_buffer.to_s(16)} bits_left=#{@bits_left}" if ENV['DEBUG_BITSTREAM']

        result
      end

      public

      # Read a single byte from the input
      #
      # Per libmspack readbits.h: On first EOF, we pad with zeros.
      # On second EOF, we raise an error (unless salvage mode).
      #
      # @return [Integer, nil] Byte value or nil to signal EOF padding needed
      # @raise [DecompressionError] on second EOF attempt (unless salvage mode)
      def read_byte
        if @buffer_pos >= @buffer.bytesize
          @buffer = @io_system.read(@handle, @buffer_size)
          @buffer_pos = 0

          if @buffer.empty?
            # Hit EOF - check if this is first or second EOF
            if @input_end
              # Second EOF: raise error unless salvage mode
              unless @salvage
                raise DecompressionError, "Unexpected end of input stream"
              end
              # In salvage mode, keep returning nil
              return nil
            else
              # First EOF: signal to pad with zeros (return nil)
              @input_end = true
              return nil
            end
          end
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

        if @bit_order == :msb
          # Ensure we have enough bits
          while @bits_left < num_bits
            # Read 2 bytes at a time (little-endian), like libmspack
            byte0 = read_byte
            if byte0.nil?
              # At EOF: break and work with remaining bits
              break
            end

            byte1 = read_byte
            byte1 = 0 if byte1.nil?

            # Combine as little-endian 16-bit value
            word = byte0 | (byte1 << 8)

            # INJECT_BITS (MSB): inject at the left side
            @bit_buffer |= (word << (@bitbuf_width - 16 - @bits_left))
            @bits_left += 16
          end

          # PEEK_BITS (MSB): extract from the left
          # If we have fewer than num_bits available, result may be incorrect
          # but this matches EOF handling behavior
          @bit_buffer >> (@bitbuf_width - num_bits)
        else
          # Ensure we have enough bits (LSB mode)
          while @bits_left < num_bits
            byte = read_byte
            if byte.nil?
              # At EOF: pad remaining bits with zeros and continue
              # This matches libmspack behavior where peek can use partial bits
              # The missing high bits are implicitly 0
              break
            end

            @bit_buffer |= (byte << @bits_left)
            @bits_left += 8
          end

          # Extract num_bits from bit_buffer
          # If we have fewer than num_bits, the high bits will be 0
          @bit_buffer & ((1 << num_bits) - 1)
        end
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
