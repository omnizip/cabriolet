# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::Huffman::Tree do
  describe "#initialize" do
    it "initializes with lengths and num_symbols" do
      lengths = [2, 3, 3, 2]
      tree = described_class.new(lengths, 4)

      expect(tree.lengths).to eq(lengths)
      expect(tree.num_symbols).to eq(4)
      expect(tree.table).to be_nil
    end
  end

  describe "#build_table" do
    context "with simple 2-bit codes" do
      it "builds a valid decode table" do
        # Simple case: all symbols have 2-bit codes
        lengths = [2, 2, 2, 2]
        tree = described_class.new(lengths, 4)

        result = tree.build_table(2)

        expect(result).to be true
        expect(tree.table).not_to be_nil
        expect(tree.table.size).to eq((1 << 2) + (4 * 2))

        # All 4 table entries should be filled with symbols 0-3
        table_entries = tree.table[0...4].sort
        expect(table_entries).to eq([0, 1, 2, 3])
      end
    end

    context "with variable length codes" do
      it "builds table for mixed code lengths" do
        # Symbol 0: length 1
        # Symbol 1: length 2
        # Symbol 2: length 3
        # Symbol 3: length 3
        lengths = [1, 2, 3, 3]
        tree = described_class.new(lengths, 4)

        result = tree.build_table(3)

        expect(result).to be true
        expect(tree.table).not_to be_nil
      end

      it "builds table with codes up to table_bits length" do
        # Create a valid Huffman tree (Kraft sum = 1)
        # 1*2^(-1) + 1*2^(-2) + 2*2^(-3) = 0.5 + 0.25 + 0.25 = 1.0
        lengths = [1, 2, 3, 3]
        tree = described_class.new(lengths, 4)

        result = tree.build_table(4)

        expect(result).to be true
        expect(tree.table).not_to be_nil
      end
    end

    context "with edge cases" do
      it "handles all zero lengths (empty tree)" do
        # Empty tree - all lengths zero
        lengths = [0, 0, 0, 0]
        tree = described_class.new(lengths, 4)

        # Empty tree should still build (pos == 0, table_mask > 0)
        result = tree.build_table(2)
        # This is actually an incomplete tree, so it should fail
        expect(result).to be false
      end

      it "handles single symbol (degenerate tree)" do
        # Single symbol gets both codes 0 and 1
        lengths = [1, 1, 0, 0]
        tree = described_class.new(lengths, 4)

        result = tree.build_table(2)
        expect(result).to be true
      end

      it "handles complete binary tree" do
        # Complete tree: 2 symbols at depth 1
        lengths = [1, 1, 0, 0]
        tree = described_class.new(lengths, 4)

        result = tree.build_table(2)
        expect(result).to be true
      end
    end

    context "with different table_bits values" do
      # Use a valid complete tree (4 * 2^(-2) = 1.0)
      let(:lengths) { [2, 2, 2, 2] }

      it "builds table with table_bits = 4" do
        tree = described_class.new(lengths, 4)
        result = tree.build_table(4)
        expect(result).to be true
      end

      it "builds table with table_bits = 6" do
        tree = described_class.new(lengths, 4)
        result = tree.build_table(6)
        expect(result).to be true
      end

      it "builds table with table_bits = 8" do
        tree = described_class.new(lengths, 4)
        result = tree.build_table(8)
        expect(result).to be true
      end

      it "builds table with table_bits = 12" do
        tree = described_class.new(lengths, 4)
        result = tree.build_table(12)
        expect(result).to be true
      end
    end

    context "with invalid code lengths" do
      it "detects over-subscribed tree" do
        # This would be an invalid Huffman tree (more codes than possible)
        lengths = [1, 1, 1, 1]
        tree = described_class.new(lengths, 4)

        result = tree.build_table(2)
        # Should fail due to table overrun
        expect(result).to be false
      end

      it "handles under-subscribed tree" do
        # Not all codes used (valid but incomplete)
        lengths = [2, 3, 0, 0]
        tree = described_class.new(lengths, 4)

        result = tree.build_table(3)
        # Under-subscribed trees should fail the full table check
        expect(result).to be false
      end
    end

    context "with canonical Huffman example" do
      it "correctly builds table for known canonical codes" do
        # Example canonical Huffman code with 5 symbols
        lengths = [2, 2, 2, 3, 3]
        tree = described_class.new(lengths, 5)

        result = tree.build_table(3)

        expect(result).to be true
        expect(tree.table).not_to be_nil
        expect(tree.table.size).to eq((1 << 3) + (5 * 2))
      end
    end

    context "with realistic MSZIP/LZX code lengths" do
      it "builds table for typical literal tree" do
        # Typical MSZIP literal/length tree has 288 symbols
        lengths = Array.new(288, 0)
        # Characters 0-143: length 8
        (0..143).each { |i| lengths[i] = 8 }
        # Characters 144-255: length 9
        (144..255).each { |i| lengths[i] = 9 }
        # Characters 256-279: length 7
        (256..279).each { |i| lengths[i] = 7 }
        # Characters 280-287: length 8
        (280..287).each { |i| lengths[i] = 8 }

        tree = described_class.new(lengths, 288)

        result = tree.build_table(9)

        expect(result).to be true
        expect(tree.table).not_to be_nil
      end
    end
  end

  describe "table structure" do
    it "creates table with correct size" do
      lengths = [2, 3, 3, 4]
      tree = described_class.new(lengths, 4)
      table_bits = 4

      tree.build_table(table_bits)

      # Table size = (1 << table_bits) + (num_symbols * 2)
      expected_size = (1 << table_bits) + (4 * 2)
      expect(tree.table.size).to eq(expected_size)
    end

    it "initializes unused entries to 0xFFFF" do
      lengths = [2, 0, 0, 0]
      tree = described_class.new(lengths, 4)

      tree.build_table(3)

      # Most entries should be 0xFFFF for an incomplete tree
      unused_count = tree.table.count { |entry| entry == 0xFFFF }
      expect(unused_count).to be > 0
    end
  end
end
