# frozen_string_literal: true

module Cabriolet
  module Huffman
    # Tree builds Huffman decoding trees from code lengths
    class Tree
      attr_reader :lengths, :num_symbols, :table

      # Maximum code length supported
      MAX_BITS = 16

      # Initialize a new Huffman tree
      #
      # @param lengths [Array<Integer>] Code lengths for each symbol
      # @param num_symbols [Integer] Number of symbols
      def initialize(lengths, num_symbols)
        @lengths = lengths
        @num_symbols = num_symbols
        @table = nil
      end

      # Build the fast decode table from code lengths
      #
      # This implements a canonical Huffman decoding table based on
      # the algorithm from libmspack (readhuff.h make_decode_table).
      # The table has two levels:
      # 1. Direct lookup for codes <= table_bits length
      # 2. Linked entries for longer codes
      #
      # @param table_bits [Integer] Number of bits for table lookup (typically 6-12)
      # @return [Boolean] true if successful, false on error
      def build_table(table_bits)
        # Allocate table: (1 << table_bits) entries for direct lookup
        # Plus space for longer codes (up to num_symbols * 2)
        table_size = (1 << table_bits) + (num_symbols * 2)
        @table = Array.new(table_size, 0xFFFF)

        pos = 0
        table_mask = 1 << table_bits
        bit_mask = table_mask >> 1

        # Fill entries for codes short enough for direct mapping (LSB ordering)
        (1..table_bits).each do |bit_num|
          (0...num_symbols).each do |sym|
            next unless lengths[sym] == bit_num

            # Reverse the significant bits for LSB ordering
            fill = lengths[sym]
            reverse = pos >> (table_bits - fill)
            leaf = 0
            fill.times do
              leaf <<= 1
              leaf |= reverse & 1
              reverse >>= 1
            end

            pos += bit_mask
            return false if pos > table_mask

            # Fill all possible lookups of this symbol
            fill = bit_mask
            next_symbol = 1 << bit_num
            while fill.positive?
              @table[leaf] = sym
              leaf += next_symbol
              fill -= 1
            end
          end
          bit_mask >>= 1
        end

        # Exit with success if table is complete
        return true if pos == table_mask

        # Mark remaining entries as unused
        (pos...table_mask).each do |sym_idx|
          reverse = sym_idx
          leaf = 0
          fill = table_bits
          fill.times do
            leaf <<= 1
            leaf |= reverse & 1
            reverse >>= 1
          end
          @table[leaf] = 0xFFFF
        end

        # next_symbol = base of allocation for long codes
        next_symbol = [(table_mask >> 1), num_symbols].max

        # Process longer codes (table_bits + 1 to MAX_BITS)
        pos <<= 16
        table_mask <<= 16
        bit_mask = 1 << 15

        ((table_bits + 1)..MAX_BITS).each do |bit_num|
          (0...num_symbols).each do |sym|
            next unless lengths[sym] == bit_num

            return false if pos >= table_mask

            # leaf = the first table_bits of the code, reversed (LSB)
            reverse = pos >> 16
            leaf = 0
            fill = table_bits
            fill.times do
              leaf <<= 1
              leaf |= reverse & 1
              reverse >>= 1
            end

            # Build the tree path for this long code
            (0...(bit_num - table_bits)).each do |fill_idx|
              # If this path hasn't been taken yet, allocate two entries
              if @table[leaf] == 0xFFFF
                @table[next_symbol << 1] = 0xFFFF
                @table[(next_symbol << 1) + 1] = 0xFFFF
                @table[leaf] = next_symbol
                next_symbol += 1
              end

              # Follow the path and select either left or right for next bit
              leaf = @table[leaf] << 1
              leaf += 1 if (pos >> (15 - fill_idx)).anybits?(1)
            end

            @table[leaf] = sym
            pos += bit_mask
          end
          bit_mask >>= 1
        end

        # Full table?
        pos == table_mask
      end
    end
  end
end
