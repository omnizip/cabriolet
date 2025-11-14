# frozen_string_literal: true

module Cabriolet
  module Huffman
    # Decoder decodes Huffman-encoded symbols from a bitstream
    class Decoder
      # Maximum code length supported
      MAX_BITS = 16

      # Decode a symbol from the bitstream using the decode table
      #
      # This implements fast Huffman decoding based on the libmspack algorithm
      # (readhuff.h READ_HUFFSYM macro). It uses a two-level table:
      # 1. Direct lookup for codes <= table_bits length
      # 2. Tree traversal for longer codes
      #
      # @param bitstream [Binary::Bitstream] Bitstream to read from
      # @param table [Array<Integer>] Huffman decode table
      # @param table_bits [Integer] Number of bits for table lookup
      # @param lengths [Array<Integer>] Code lengths for each symbol
      # @param num_symbols [Integer] Number of symbols in the table
      # @return [Integer] Decoded symbol
      # @raise [DecompressionError] if decoding fails
      def self.decode_symbol(bitstream, table, table_bits, lengths,
num_symbols = nil)
        # If num_symbols not provided, infer it from lengths
        num_symbols ||= lengths.size

        # Peek at table_bits from the bitstream
        bits = bitstream.peek_bits(table_bits)

        # Look up in the decode table
        sym = table[bits]

        # If symbol is directly in table (< num_symbols)
        if sym < num_symbols
          # Get code length for this symbol and consume the bits
          code_len = lengths[sym]
          bitstream.skip_bits(code_len)
          return sym
        end

        # Symbol is a pointer to second level tree
        # We need to traverse the tree for longer codes (> table_bits)
        # Start from table_bits - 1 and increment
        idx = table_bits - 1

        loop do
          idx += 1
          if idx > MAX_BITS
            raise Cabriolet::DecompressionError,
                  "Huffman decode error: code too long"
          end

          # Get the next bit from bit buffer at position idx
          bit = (bitstream.peek_bits(idx + 1) >> idx) & 1

          # Follow the tree path: (current_entry << 1) | bit
          next_idx = (sym << 1) | bit
          sym = table[next_idx]

          # Check for nil (invalid table entry)
          if sym.nil? || sym == 0xFFFF
            raise Cabriolet::DecompressionError,
                  "Huffman decode error: invalid code"
          end

          # Found a valid symbol?
          break if sym < num_symbols
        end

        # Consume idx + 1 bits (the full code length)
        bitstream.skip_bits(idx + 1)

        sym
      end
    end
  end
end
