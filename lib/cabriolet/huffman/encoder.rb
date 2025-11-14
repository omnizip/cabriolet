# frozen_string_literal: true

module Cabriolet
  module Huffman
    # Encoder encodes symbols using Huffman codes for compression
    class Encoder
      # Maximum code length supported
      MAX_BITS = 16

      # Build Huffman codes from code lengths (RFC 1951 algorithm)
      #
      # This generates the actual Huffman code values from code lengths.
      # The algorithm ensures canonical Huffman codes where codes of the
      # same length are assigned sequentially.
      #
      # @param lengths [Array<Integer>] Code lengths for each symbol
      # @param num_symbols [Integer] Number of symbols
      # @return [Hash] Hash mapping symbol to {code: value, bits: length}
      def self.build_codes(lengths, num_symbols)
        # Count the number of codes for each length
        bl_count = Array.new(MAX_BITS + 1, 0)
        lengths[0, num_symbols].each do |len|
          bl_count[len] += 1 if len.positive?
        end

        # Find the numerical value of the smallest code for each length
        code = 0
        bl_count[0] = 0
        next_code = Array.new(MAX_BITS + 1, 0)

        (1..MAX_BITS).each do |bits|
          code = (code + bl_count[bits - 1]) << 1
          next_code[bits] = code
        end

        # Assign codes to symbols
        codes = {}
        num_symbols.times do |symbol|
          len = lengths[symbol]
          next unless len.positive?

          codes[symbol] = {
            code: next_code[len],
            bits: len,
          }
          next_code[len] += 1
        end

        codes
      end

      # Build fixed Huffman codes for DEFLATE (RFC 1951)
      #
      # @return [Hash] Hash with :literal and :distance code tables
      def self.build_fixed_codes
        # Fixed literal/length code lengths
        literal_lengths = Array.new(288, 0)
        (0...144).each { |i| literal_lengths[i] = 8 }
        (144...256).each { |i| literal_lengths[i] = 9 }
        (256...280).each { |i| literal_lengths[i] = 7 }
        (280...288).each { |i| literal_lengths[i] = 8 }

        # Fixed distance code lengths (all 5 bits)
        distance_lengths = Array.new(32, 5)

        {
          literal: build_codes(literal_lengths, 288),
          distance: build_codes(distance_lengths, 32),
        }
      end

      # Encode a symbol using Huffman codes and write to bitstream
      #
      # Per RFC 1951 Section 3.1.1, Huffman codes are written LSB-first,
      # so we must reverse the bits before writing to the bitstream.
      #
      # @param symbol [Integer] Symbol to encode
      # @param codes [Hash] Code table mapping symbols to {code:, bits:}
      # @param bitstream [Binary::BitstreamWriter] Output bitstream
      # @return [void]
      def self.encode_symbol(symbol, codes, bitstream)
        entry = codes[symbol]
        unless entry
          raise Cabriolet::CompressionError,
                "No code for symbol #{symbol}"
        end

        # Reverse bits for LSB-first writing per RFC 1951
        reversed_code = reverse_bits(entry[:code], entry[:bits])
        bitstream.write_bits(reversed_code, entry[:bits])
      end

      # Reverse bits for writing (some formats need reversed bit order)
      #
      # @param value [Integer] Value to reverse
      # @param num_bits [Integer] Number of bits
      # @return [Integer] Reversed value
      def self.reverse_bits(value, num_bits)
        result = 0
        num_bits.times do
          result = (result << 1) | (value & 1)
          value >>= 1
        end
        result
      end
    end
  end
end
