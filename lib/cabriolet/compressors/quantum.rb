# frozen_string_literal: true

module Cabriolet
  module Compressors
    # Quantum compresses data using arithmetic coding and LZ77-based matching
    # Based on the Quantum decompressor and libmspack qtmd.c implementation
    #
    # STATUS: Functional with known limitations
    # - Literals: WORKING ✓
    # - Short matches (3-13 bytes): WORKING ✓
    # - Longer matches (14+ bytes): Limited support (known issue)
    # - Simple data round-trips successfully
    # - Complex repeated patterns may have issues
    #
    # The Quantum method was created by David Stafford, adapted by Microsoft
    # Corporation.
    # rubocop:disable Metrics/ClassLength
    class Quantum < Base
      # Frame size (32KB per frame)
      FRAME_SIZE = 32_768

      # Match constants
      MIN_MATCH = 3
      MAX_MATCH = 1028

      # Position slot tables (same as decompressor)
      POSITION_BASE = [
        0, 1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64, 96, 128, 192, 256, 384,
        512, 768, 1024, 1536, 2048, 3072, 4096, 6144, 8192, 12_288, 16_384,
        24_576, 32_768, 49_152, 65_536, 98_304, 131_072, 196_608, 262_144,
        393_216, 524_288, 786_432, 1_048_576, 1_572_864
      ].freeze

      EXTRA_BITS = [
        0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8,
        9, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 15, 16, 16,
        17, 17, 18, 18, 19, 19
      ].freeze

      LENGTH_BASE = [
        0, 1, 2, 3, 4, 5, 6, 8, 10, 12, 14, 18, 22, 26,
        30, 38, 46, 54, 62, 78, 94, 110, 126, 158, 190, 222, 254
      ].freeze

      LENGTH_EXTRA = [
        0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
        3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0
      ].freeze

      attr_reader :window_bits, :window_size

      # Represents a symbol in an arithmetic coding model
      class ModelSymbol
        attr_accessor :sym, :cumfreq

        def initialize(sym, cumfreq)
          @sym = sym
          @cumfreq = cumfreq
        end
      end

      # Represents an arithmetic coding model
      class Model
        attr_accessor :shiftsleft, :entries, :syms

        def initialize(syms, entries)
          @syms = syms
          @entries = entries
          @shiftsleft = 4
        end
      end

      # Initialize Quantum compressor
      #
      # @param io_system [System::IOSystem] I/O system for reading/writing
      # @param input [System::FileHandle, System::MemoryHandle] Input handle
      # @param output [System::FileHandle, System::MemoryHandle] Output handle
      # @param buffer_size [Integer] Buffer size for I/O operations
      # @param window_bits [Integer] Window size parameter (10-21)
      def initialize(io_system, input, output, buffer_size, window_bits: 10)
        super(io_system, input, output, buffer_size)

        # Validate window_bits
        unless (10..21).cover?(window_bits)
          raise ArgumentError,
                "Quantum window_bits must be 10-21, got #{window_bits}"
        end

        @window_bits = window_bits
        @window_size = 1 << window_bits

        # Initialize bitstream for MSB-first writing
        @bitstream = Binary::BitstreamWriter.new(io_system, output,
                                                 buffer_size, msb_first: true)

        # Initialize models
        initialize_models
      end

      # Compress the input data
      #
      # @return [Integer] Total bytes compressed
      def compress
        total_bytes = 0

        loop do
          # Read frame data
          frame_data = io_system.read(input, FRAME_SIZE)
          break if frame_data.empty?

          total_bytes += frame_data.bytesize

          # Compress frame
          compress_frame(frame_data)

          # Write trailer (0xFF marker)
          @bitstream.flush_msb
          @bitstream.write_byte(0xFF)

          # Reset models for next frame
          initialize_models

          break if frame_data.bytesize < FRAME_SIZE
        end

        total_bytes
      end

      private

      # Initialize all 7 arithmetic coding models (exactly matching decoder)
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

        # Arithmetic coding state
        @h = 0xFFFF
        @l = 0
        @underflow_bits = 0
      end

      # Initialize model symbol array (exactly matching qtmd_init_model)
      def init_model_syms(start, len)
        Array.new(len + 1) do |i|
          ModelSymbol.new(start + i, len - i)
        end
      end

      # Compress a single frame
      def compress_frame(data)
        # No header needed - the first 16 bits of encoded data will be read as C
        pos = 0

        while pos < data.bytesize
          # Try to find a match
          match_length, match_offset = find_match(data, pos)

          if match_length >= MIN_MATCH
            # Encode match
            encode_match(match_length, match_offset)
            pos += match_length
          else
            # Encode literal
            byte = data.getbyte(pos)
            encode_literal(byte)
            pos += 1
          end
        end

        # Finish arithmetic coding - output final range
        # We need to output enough bits to disambiguate the final range
        finish_arithmetic_coding
      end

      # Finish arithmetic coding by outputting the final state
      def finish_arithmetic_coding
        # Output enough bits to ensure decoder can decode correctly
        # We need to output a value that falls within [L, H)
        # A common approach is to output L plus half the range
        @underflow_bits += 1
        bit = if @l.anybits?(0x4000)
                1
              else
                0
              end
        @bitstream.write_bits_msb(bit, 1)
        @underflow_bits.times do
          @bitstream.write_bits_msb(bit ^ 1, 1)
        end
        @underflow_bits = 0
      end

      # Find best match in the sliding window
      def find_match(data, pos)
        return [0, 0] if pos < MIN_MATCH

        best_length = 0
        best_offset = 0
        max_offset = [pos, @window_size].min

        # Search backwards for matches
        (1..max_offset).each do |offset|
          match_pos = pos - offset
          length = 0

          # Count matching bytes
          while length < MAX_MATCH &&
              (pos + length) < data.bytesize &&
              data.getbyte(match_pos + length) == data.getbyte(pos + length)
            length += 1
          end

          if length > best_length
            best_length = length
            best_offset = offset
          end
        end

        [best_length, best_offset]
      end

      # Encode a literal byte
      def encode_literal(byte)
        # Select model based on byte value (0-63, 64-127, 128-191, 192-255)
        selector = byte >> 6
        model = case selector
                when 0 then @model0
                when 1 then @model1
                when 2 then @model2
                else @model3
                end

        # Encode selector (0-3 for literals)
        encode_symbol(@model7, selector)

        # Encode full byte value in selected model
        encode_symbol(model, byte)
      end

      # Encode a match
      def encode_match(length, offset)
        if length == 3
          # Use model4 for 3-byte matches
          encode_symbol(@model7, 4)
          encode_position(@model4, offset)
        elsif length == 4
          # Use model5 for 4-byte matches
          encode_symbol(@model7, 5)
          encode_position(@model5, offset)
        else
          # Use model6 for longer matches
          encode_symbol(@model7, 6)
          encode_length(@model6len, length - 5)
          encode_position(@model6, offset)
        end
      end

      # Encode position using position slots
      def encode_position(model, offset)
        # Find position slot
        slot = find_position_slot(offset - 1)

        # Encode slot
        encode_symbol(model, slot)

        # Encode extra bits if needed
        extra = EXTRA_BITS[slot]
        return unless extra.positive?

        value = (offset - 1) - POSITION_BASE[slot]
        @bitstream.write_bits_msb(value, extra)
      end

      # Find position slot for an offset
      def find_position_slot(offset)
        POSITION_BASE.each_with_index do |base, i|
          return i if offset < base + (1 << EXTRA_BITS[i])
        end
        POSITION_BASE.length - 1
      end

      # Encode match length
      def encode_length(model, length)
        # Find length slot
        slot = find_length_slot(length)

        # Encode slot
        encode_symbol(model, slot)

        # Encode extra bits if needed
        extra = LENGTH_EXTRA[slot]
        return unless extra.positive?

        value = length - LENGTH_BASE[slot]
        @bitstream.write_bits_msb(value, extra)
      end

      # Find length slot for a length value
      def find_length_slot(length)
        LENGTH_BASE.each_with_index do |base, i|
          return i if length < base + (1 << LENGTH_EXTRA[i])
        end
        LENGTH_BASE.length - 1
      end

      # Encode a symbol using arithmetic coding
      # This is the inverse of GET_SYMBOL macro in qtmd.c
      def encode_symbol(model, sym)
        # Find symbol index in model
        i = 0
        i += 1 while i < model.entries && model.syms[i].sym != sym

        if i >= model.entries
          raise ArgumentError,
                "Symbol #{sym} not found in model"
        end

        # Calculate range (matching decoder line 93, 101-102)
        range = (@h - @l) + 1
        symf = model.syms[0].cumfreq

        # Update H and L (matching decoder lines 103-104)
        # Decoder uses syms[i-1] and syms[i], so encoder at index j
        # should use syms[j] and syms[j+1] to make decoder land at i=j+1
        # But decoder returns syms[i-1].sym, so it will return syms[j].sym ✓
        @h = @l + ((model.syms[i].cumfreq * range) / symf) - 1
        @l += ((model.syms[i + 1].cumfreq * range) / symf)

        # Update model frequencies (matching decoder line 106)
        j = i
        while j >= 0
          model.syms[j].cumfreq += 8
          j -= 1
        end

        # Check if model needs updating (matching decoder line 107)
        update_model(model) if model.syms[0].cumfreq > 3800

        # Normalize range (matching decoder lines 109-121)
        normalize_range
      end

      # Normalize arithmetic coding range and output bits
      # This implements the encoder equivalent of the decoder's normalization (lines 109-121)
      def normalize_range
        loop do
          if (@l & 0x8000) == (@h & 0x8000)
            # MSBs are same, output bit
            bit = (@l >> 15) & 1
            @bitstream.write_bits_msb(bit, 1)

            # Output pending underflow bits (inverted)
            @underflow_bits.times do
              @bitstream.write_bits_msb(bit ^ 1, 1)
            end
            @underflow_bits = 0
          else
            # MSBs differ - check for underflow
            break unless @l.anybits?(0x4000) && @h.nobits?(0x4000)

            # Underflow case - track pending bits
            @underflow_bits += 1
            @l &= 0x3FFF
            @h |= 0x4000

            # Can't normalize further

          end

          # Shift range (both for underflow and MSB match cases)
          @l = (@l << 1) & 0xFFFF
          @h = ((@h << 1) | 1) & 0xFFFF
        end
      end

      # Update model statistics (matching qtmd_update_model exactly)
      def update_model(model)
        model.shiftsleft -= 1

        if model.shiftsleft.positive?
          # Simple shift (matching decoder lines 129-135)
          (model.entries - 1).downto(0) do |i|
            model.syms[i].cumfreq >>= 1
            model.syms[i].cumfreq = model.syms[i + 1].cumfreq + 1 if model.syms[i].cumfreq <= model.syms[i + 1].cumfreq
          end
        else
          # Full rebuild (matching decoder lines 137-163)
          model.shiftsleft = 50

          # Convert cumfreq to frequencies (lines 139-145)
          (0...model.entries).each do |i|
            model.syms[i].cumfreq -= model.syms[i + 1].cumfreq
            model.syms[i].cumfreq += 1
            model.syms[i].cumfreq >>= 1
          end

          # Sort by frequency (selection sort for stability, lines 150-158)
          (0...(model.entries - 1)).each do |i|
            ((i + 1)...model.entries).each do |j|
              if model.syms[i].cumfreq < model.syms[j].cumfreq
                model.syms[i], model.syms[j] = model.syms[j], model.syms[i]
              end
            end
          end

          # Convert back to cumulative frequencies (lines 161-163)
          (model.entries - 1).downto(0) do |i|
            model.syms[i].cumfreq += model.syms[i + 1].cumfreq
          end
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
