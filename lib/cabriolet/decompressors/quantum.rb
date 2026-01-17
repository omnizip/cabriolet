# frozen_string_literal: true

require_relative "../quantum_shared"

# Compatibility shim for String#bytesplice (added in Ruby 3.2)
unless String.method_defined?(:bytesplice)
  module StringBytespliceCompat
    # Compatibility implementation of bytesplice for Ruby < 3.2
    # Uses clear/append which is slower but works with mutable strings
    def bytesplice(index, length, other_string, other_index = 0,
other_length = nil)
      other_length ||= other_string.bytesize

      # Build new string content
      prefix = byteslice(0, index)
      middle = other_string.byteslice(other_index, other_length)
      suffix = byteslice((index + length)..-1)
      new_content = prefix + middle + suffix

      # Modify receiver in place
      clear
      self << new_content

      self
    end
  end

  String.prepend(StringBytespliceCompat)
end

module Cabriolet
  module Decompressors
    # Quantum handles Quantum-compressed data using arithmetic coding
    # Based on libmspack qtmd.c implementation
    #
    # The Quantum method was created by David Stafford, adapted by Microsoft
    # Corporation.
    class Quantum < Base
      include QuantumShared

      attr_reader :window_bits, :window_size

      # Initialize Quantum decompressor
      #
      # @param io_system [System::IOSystem] I/O system for reading/writing
      # @param input [System::FileHandle, System::MemoryHandle] Input handle
      # @param output [System::FileHandle, System::MemoryHandle] Output handle
      # @param buffer_size [Integer] Buffer size for I/O operations
      # @param window_bits [Integer] Window size parameter (10-21)
      def initialize(io_system, input, output, buffer_size, window_bits: 10,
**_kwargs)
        super(io_system, input, output, buffer_size)

        # Validate window_bits
        unless (10..21).cover?(window_bits)
          raise ArgumentError,
                "Quantum window_bits must be 10-21, got #{window_bits}"
        end

        @window_bits = window_bits
        @window_size = 1 << window_bits

        # Initialize window (mutable for Ruby < 3.2 bytesplice compatibility)
        @window = if String.method_defined?(:bytesplice)
                    "\0" * @window_size
                  else
                    # In Ruby < 3.2, create mutable window using String.new
                    String.new("\0" * @window_size)
                  end
        @window_posn = 0
        @frame_todo = FRAME_SIZE

        # Arithmetic coding state
        @h = 0xFFFF
        @l = 0
        @c = 0
        @header_read = false

        # Initialize bitstream for MSB-first reading
        @bitstream = MSBBitstream.new(io_system, input, buffer_size)

        # Initialize models
        initialize_models
      end

      # Decompress Quantum data
      #
      # @param bytes [Integer] Number of bytes to decompress
      # @return [Integer] Number of bytes decompressed
      def decompress(bytes)
        return 0 if bytes <= 0

        output_data = String.new(capacity: bytes)
        bytes_todo = bytes

        while bytes_todo.positive?
          # Read header if needed (initializes C register)
          read_frame_header unless @header_read

          # Calculate how much to decode this iteration
          frame_end = @window_posn + [bytes_todo, @frame_todo,
                                      @window_size - @window_posn].min

          # Decode symbols
          while @window_posn < frame_end
            selector = decode_symbol(@model7)

            if selector < 4
              # Literal byte from one of 4 models
              model = case selector
                      when 0 then @model0
                      when 1 then @model1
                      when 2 then @model2
                      else @model3
                      end

              sym = decode_symbol(model)
              @window.setbyte(@window_posn, sym)
              @window_posn += 1
              @frame_todo -= 1
            else
              # Match
              match_offset, match_length = decode_match(selector)

              # Validate match doesn't exceed frame or window
              if @window_posn + match_length > @window_size
                raise DecompressionError,
                      "Match exceeds window boundary"
              end

              @frame_todo -= match_length

              # Copy match
              copy_match(match_offset, match_length)
            end
          end

          # Extract decoded bytes for output
          output_amount = [@window_posn, bytes_todo].min
          output_data << @window[0, output_amount]
          bytes_todo -= output_amount

          # Handle frame completion
          if @frame_todo.zero?
            # Re-align to byte boundary
            @bitstream.byte_align

            # Skip trailer bytes until 0xFF
            loop do
              byte = @bitstream.read_bits(8)
              break if byte == 0xFF
            end

            @header_read = false
            @frame_todo = FRAME_SIZE
          end

          # Handle window wrap
          @window_posn = 0 if @window_posn == @window_size
        end

        # Write output
        io_system.write(output, output_data)
        bytes
      end

      private

      # MSB-first bitstream for Quantum (reads 16-bit words MSB first)
      class MSBBitstream
        attr_reader :bits_left

        def initialize(io_system, handle, buffer_size)
          @io_system = io_system
          @handle = handle
          @buffer_size = buffer_size
          @buffer = ""
          @buffer_pos = 0
          @bit_buffer = 0
          @bits_left = 0
        end

        # Read bits MSB first (matching Quantum's READ_BITS macro)
        def read_bits(num_bits)
          while @bits_left < num_bits
            # Read 16-bit word MSB first
            b0 = read_byte
            b1 = read_byte
            word = (b0 << 8) | b1
            @bit_buffer = (@bit_buffer << 16) | word
            @bits_left += 16
          end

          # Extract bits from MSB side
          @bits_left -= num_bits
          (@bit_buffer >> @bits_left) & ((1 << num_bits) - 1)
        end

        def read_byte
          if @buffer_pos >= @buffer.bytesize
            @buffer = @io_system.read(@handle, @buffer_size)
            @buffer_pos = 0
            return 0 if @buffer.empty?
          end

          byte = @buffer.getbyte(@buffer_pos)
          @buffer_pos += 1
          byte
        end

        def byte_align
          @bits_left -= (@bits_left % 8)
        end
      end

      # Initialize all 7 arithmetic coding models
      def initialize_models
        # Models depend on window size
        i = @window_bits * 2

        # Four literal models (64 symbols each)
        @m0sym = init_model_syms(0, 64)
        @model0 = Model.new(@m0sym, 64)

        @m1sym = init_model_syms(64, 64)
        @model1 = Model.new(@m1sym, 64)

        @m2sym = init_model_syms(128, 64)
        @model2 = Model.new(@m2sym, 64)

        @m3sym = init_model_syms(192, 64)
        @model3 = Model.new(@m3sym, 64)

        # Three match models (size depends on window)
        @m4sym = init_model_syms(0, [i, 24].min)
        @model4 = Model.new(@m4sym, [i, 24].min)

        @m5sym = init_model_syms(0, [i, 36].min)
        @model5 = Model.new(@m5sym, [i, 36].min)

        @m6sym = init_model_syms(0, i)
        @model6 = Model.new(@m6sym, i)

        # Match length model
        @m6lsym = init_model_syms(0, 27)
        @model6len = Model.new(@m6lsym, 27)

        # Selector model (7 symbols: 0-3 literals, 4-6 matches)
        @m7sym = init_model_syms(0, 7)
        @model7 = Model.new(@m7sym, 7)
      end

      # Initialize model symbol array
      def init_model_syms(start, len)
        Array.new(len + 1) do |i|
          ModelSymbol.new(start + i, len - i)
        end
      end

      # Read frame header (initialize C register)
      def read_frame_header
        @h = 0xFFFF
        @l = 0
        @c = @bitstream.read_bits(16)
        @header_read = true
      end

      # Decode a symbol using arithmetic coding
      # This implements the GET_SYMBOL macro from qtmd.c
      def decode_symbol(model)
        # Calculate range
        range = ((@h - @l) & 0xFFFF) + 1
        symf = ((((@c - @l + 1) * model.syms[0].cumfreq) - 1) / range) & 0xFFFF

        # Find symbol
        i = 1
        while i < model.entries
          break if model.syms[i].cumfreq <= symf

          i += 1
        end

        sym = model.syms[i - 1].sym

        # Update range
        range = (@h - @l) + 1
        symf = model.syms[0].cumfreq
        @h = @l + ((model.syms[i - 1].cumfreq * range) / symf) - 1
        @l += ((model.syms[i].cumfreq * range) / symf)

        # Update model frequencies
        j = i - 1
        while j >= 0
          model.syms[j].cumfreq += 8
          j -= 1
        end

        # Check if model needs updating
        update_model(model) if model.syms[0].cumfreq > 3800

        # Normalize range
        normalize_range

        sym
      end

      # Normalize arithmetic coding range
      def normalize_range
        loop do
          if (@l & 0x8000) != (@h & 0x8000)
            # Underflow case
            break unless @l.anybits?(0x4000) && @h.nobits?(0x4000)

            @c ^= 0x4000
            @l &= 0x3FFF
            @h |= 0x4000

          end

          @l = (@l << 1) & 0xFFFF
          @h = ((@h << 1) | 1) & 0xFFFF
          bit = @bitstream.read_bits(1)
          @c = ((@c << 1) | bit) & 0xFFFF
        end
      end

      # Update model statistics (from qtmd_update_model)
      def update_model(model)
        model.shiftsleft -= 1

        if model.shiftsleft.positive?
          # Simple shift
          (model.entries - 1).downto(0) do |i|
            model.syms[i].cumfreq >>= 1
            model.syms[i].cumfreq = model.syms[i + 1].cumfreq + 1 if model.syms[i].cumfreq <= model.syms[i + 1].cumfreq
          end
        else
          # Full rebuild
          model.shiftsleft = 50

          # Convert cumfreq to frequencies
          (0...model.entries).each do |i|
            model.syms[i].cumfreq -= model.syms[i + 1].cumfreq
            model.syms[i].cumfreq += 1
            model.syms[i].cumfreq >>= 1
          end

          # Sort by frequency (selection sort for stability)
          (0...(model.entries - 1)).each do |i|
            ((i + 1)...model.entries).each do |j|
              if model.syms[i].cumfreq < model.syms[j].cumfreq
                model.syms[i], model.syms[j] = model.syms[j], model.syms[i]
              end
            end
          end

          # Convert back to cumulative frequencies
          (model.entries - 1).downto(0) do |i|
            model.syms[i].cumfreq += model.syms[i + 1].cumfreq
          end
        end
      end

      # Decode match offset and length
      def decode_match(selector)
        case selector
        when 4
          # Fixed length match (3 bytes)
          sym = decode_symbol(@model4)
          extra = @bitstream.read_bits(EXTRA_BITS[sym]) if EXTRA_BITS[sym].positive?
          match_offset = POSITION_BASE[sym] + (extra || 0) + 1
          match_length = 3
        when 5
          # Fixed length match (4 bytes)
          sym = decode_symbol(@model5)
          extra = @bitstream.read_bits(EXTRA_BITS[sym]) if EXTRA_BITS[sym].positive?
          match_offset = POSITION_BASE[sym] + (extra || 0) + 1
          match_length = 4
        when 6
          # Variable length match
          sym = decode_symbol(@model6len)
          extra = @bitstream.read_bits(LENGTH_EXTRA[sym]) if LENGTH_EXTRA[sym].positive?
          match_length = LENGTH_BASE[sym] + (extra || 0) + 5

          sym = decode_symbol(@model6)
          extra = @bitstream.read_bits(EXTRA_BITS[sym]) if EXTRA_BITS[sym].positive?
          match_offset = POSITION_BASE[sym] + (extra || 0) + 1
        else
          raise DecompressionError, "Invalid selector: #{selector}"
        end

        [match_offset, match_length]
      end

      # Copy match from window
      # Optimized to use bulk byte operations for better performance
      def copy_match(offset, length)
        # Use bulk copy for matches longer than 32 bytes
        if length > 32
          copy_match_bulk(offset, length)
        else
          copy_match_byte_by_byte(offset, length)
        end
      end

      # Bulk copy using bytesplice for better performance on longer matches
      def copy_match_bulk(offset, length)
        if offset > @window_posn
          # Match wraps around window
          if offset > @window_size
            raise DecompressionError,
                  "Match offset beyond window"
          end

          # Copy from end of window
          src_pos = @window_size - (offset - @window_posn)
          copy_len = offset - @window_posn

          if copy_len < length
            # Copy from end, then from beginning
            @window.bytesplice(@window_posn, copy_len, @window, src_pos,
                               copy_len)
            @window_posn += copy_len
            remaining = length - copy_len
            @window.bytesplice(@window_posn, remaining, @window, 0, remaining)
            @window_posn += remaining
          else
            # Copy entirely from end
            @window.bytesplice(@window_posn, length, @window, src_pos, length)
            @window_posn += length
          end
        else
          # Normal copy - use bytesplice for bulk operation
          src_pos = @window_posn - offset
          @window.bytesplice(@window_posn, length, @window, src_pos, length)
          @window_posn += length
        end
      end

      # Byte-by-byte copy for short matches (fallback)
      def copy_match_byte_by_byte(offset, length)
        if offset > @window_posn
          # Match wraps around window
          if offset > @window_size
            raise DecompressionError,
                  "Match offset beyond window"
          end

          # Copy from end of window
          src_pos = @window_size - (offset - @window_posn)
          copy_len = offset - @window_posn

          if copy_len < length
            # Copy from end, then from beginning
            copy_len.times do
              @window.setbyte(@window_posn, @window.getbyte(src_pos))
              @window_posn += 1
              src_pos += 1
            end
            src_pos = 0
            (length - copy_len).times do
              @window.setbyte(@window_posn, @window.getbyte(src_pos))
              @window_posn += 1
              src_pos += 1
            end
          else
            # Copy entirely from end
            length.times do
              @window.setbyte(@window_posn, @window.getbyte(src_pos))
              @window_posn += 1
              src_pos += 1
            end
          end
        else
          # Normal copy
          src_pos = @window_posn - offset
          length.times do
            @window.setbyte(@window_posn, @window.getbyte(src_pos))
            @window_posn += 1
            src_pos += 1
          end
        end
      end
    end
  end
end
