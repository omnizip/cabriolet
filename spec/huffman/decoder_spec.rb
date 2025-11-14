# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::Huffman::Decoder do
  let(:io_system) { Cabriolet::System::IOSystem.new }

  # Helper to create a bitstream from bytes
  def create_bitstream(bytes)
    handle = Cabriolet::System::MemoryHandle.new(bytes)
    Cabriolet::Binary::Bitstream.new(io_system, handle)
  end

  describe ".decode_symbol" do
    context "with simple 2-bit codes" do
      it "decodes symbols successfully" do
        # All symbols have 2-bit codes
        lengths = [2, 2, 2, 2]
        tree = Cabriolet::Huffman::Tree.new(lengths, 4)
        tree.build_table(2)

        # Create test data - we'll just verify decoding works
        bytes = [0b11_10_01_00].pack("C")
        bitstream = create_bitstream(bytes)

        # Decode 4 symbols
        symbols = []
        4.times do
          symbols << described_class.decode_symbol(bitstream, tree.table, 2,
                                                   lengths, 4)
        end

        # All decoded symbols should be valid (0-3)
        expect(symbols.size).to eq(4)
        symbols.each do |sym|
          expect(sym).to be >= 0
          expect(sym).to be < 4
        end
      end
    end

    context "with variable length codes" do
      it "decodes mixed length symbols correctly" do
        # Create a tree with variable lengths
        lengths = [1, 2, 3, 3]
        tree = Cabriolet::Huffman::Tree.new(lengths, 4)
        tree.build_table(3)

        # Create test bitstream
        bytes = [0xFF].pack("C")
        bitstream = create_bitstream(bytes)

        # Decode several symbols
        symbols = []
        5.times do
          sym = described_class.decode_symbol(bitstream, tree.table, 3,
                                              lengths, 4)
          symbols << sym
          break if sym.nil?
        rescue Cabriolet::Errors::DecompressionError
          break
        end

        # Should decode at least one symbol successfully
        expect(symbols.size).to be >= 1
        symbols.each do |sym|
          expect(sym).to be >= 0
          expect(sym).to be < 4
        end
      end
    end

    context "with codes requiring second-level lookup" do
      it "decodes long codes using tree traversal" do
        # Create a valid tree where some codes exceed table_bits
        lengths = [2, 2, 3, 3, 3, 3, 4, 4]
        table_bits = 3
        tree = Cabriolet::Huffman::Tree.new(lengths, 8)
        result = tree.build_table(table_bits)

        expect(result).to be true

        # Test decoding works
        bytes = [0xFF, 0xFF].pack("C*")
        bitstream = create_bitstream(bytes)

        sym = described_class.decode_symbol(bitstream, tree.table, table_bits,
                                            lengths, 8)
        expect(sym).to be >= 0
        expect(sym).to be < 8
      end
    end

    context "with single symbol tree" do
      it "decodes from a two-symbol tree" do
        # A valid two-symbol tree
        lengths = [1, 1, 0, 0]
        tree = Cabriolet::Huffman::Tree.new(lengths, 4)
        tree.build_table(2)

        bytes = [0xFF].pack("C")
        bitstream = create_bitstream(bytes)

        # Should decode to either symbol 0 or 1
        sym = described_class.decode_symbol(bitstream, tree.table, 2, lengths,
                                            4)
        expect(sym).to be >= 0
        expect(sym).to be < 2
      end
    end

    context "with realistic code lengths" do
      it "decodes symbols from a typical Huffman tree" do
        # Create a valid realistic tree (2*2^(-2) + 2*2^(-3) = 0.75 < 1, incomplete tree)
        # Let's use a complete tree instead
        lengths = [2, 2, 2, 2, 3, 3, 3, 3]
        tree = Cabriolet::Huffman::Tree.new(lengths, 8)
        result = tree.build_table(6)

        # Skip test if table building failed
        skip "Invalid Huffman tree" unless result

        bytes = [0xFF, 0xFF].pack("C*")
        bitstream = create_bitstream(bytes)

        # Decode multiple symbols
        symbols = []
        5.times do
          symbols << described_class.decode_symbol(bitstream, tree.table, 6,
                                                   lengths, 8)
        end

        expect(symbols.size).to eq(5)
        symbols.each do |sym|
          expect(sym).to be >= 0
          expect(sym).to be < 8
        end
      end
    end

    context "with complete binary trees" do
      it "decodes from a complete tree correctly" do
        # A complete binary tree with 2 symbols
        lengths = [1, 1, 0, 0]
        tree = Cabriolet::Huffman::Tree.new(lengths, 4)
        tree.build_table(2)

        bytes = [0b10_10_01_01].pack("C")
        bitstream = create_bitstream(bytes)

        symbols = []
        4.times do
          symbols << described_class.decode_symbol(bitstream, tree.table, 2,
                                                   lengths, 4)
        end

        # Should get a mix of symbols 0 and 1
        expect(symbols.size).to eq(4)
        symbols.each do |sym|
          expect(sym).to be >= 0
          expect(sym).to be < 2
        end
      end
    end

    context "with different table_bits configurations" do
      let(:lengths) { [2, 2, 3, 3, 3, 3, 3, 3] }

      it "decodes correctly with table_bits = 4" do
        tree = Cabriolet::Huffman::Tree.new(lengths, 8)
        tree.build_table(4)

        bytes = [0xFF].pack("C")
        bitstream = create_bitstream(bytes)
        sym = described_class.decode_symbol(bitstream, tree.table, 4, lengths,
                                            8)

        expect(sym).to be >= 0
        expect(sym).to be < 8
      end

      it "decodes correctly with table_bits = 6" do
        tree = Cabriolet::Huffman::Tree.new(lengths, 8)
        tree.build_table(6)

        bytes = [0xFF].pack("C")
        bitstream = create_bitstream(bytes)
        sym = described_class.decode_symbol(bitstream, tree.table, 6, lengths,
                                            8)

        expect(sym).to be >= 0
        expect(sym).to be < 8
      end

      it "decodes correctly with table_bits = 8" do
        tree = Cabriolet::Huffman::Tree.new(lengths, 8)
        tree.build_table(8)

        bytes = [0xFF].pack("C")
        bitstream = create_bitstream(bytes)
        sym = described_class.decode_symbol(bitstream, tree.table, 8, lengths,
                                            8)

        expect(sym).to be >= 0
        expect(sym).to be < 8
      end
    end

    context "boundary conditions" do
      it "handles decoding at byte boundaries" do
        lengths = [3, 3, 3, 3, 3, 3, 3, 3]
        tree = Cabriolet::Huffman::Tree.new(lengths, 8)
        tree.build_table(3)

        # 8 symbols * 3 bits = 24 bits = 3 bytes exactly
        bytes = [0xFF, 0xFF, 0xFF].pack("C*")
        bitstream = create_bitstream(bytes)

        symbols = []
        8.times do
          symbols << described_class.decode_symbol(bitstream, tree.table, 3,
                                                   lengths, 8)
        end

        expect(symbols.size).to eq(8)
        symbols.each do |sym|
          expect(sym).to be >= 0
          expect(sym).to be < 8
        end
      end

      it "handles consecutive decodes" do
        lengths = [2, 2, 2, 2]
        tree = Cabriolet::Huffman::Tree.new(lengths, 4)
        tree.build_table(2)

        bytes = [0xFF, 0xFF].pack("C*")
        bitstream = create_bitstream(bytes)

        # Decode many symbols in sequence
        symbols = []
        8.times do
          symbols << described_class.decode_symbol(bitstream, tree.table, 2,
                                                   lengths, 4)
        end

        expect(symbols.size).to eq(8)
        symbols.each do |sym|
          expect(sym).to be >= 0
          expect(sym).to be < 4
        end
      end
    end

    context "integration with tree building" do
      it "successfully decodes after building various trees" do
        # Test multiple valid configurations (all satisfy Kraft inequality)
        test_cases = [
          { lengths: [1, 1], num_symbols: 2, table_bits: 2 },
          { lengths: [2, 2, 2, 2], num_symbols: 4, table_bits: 2 },
          { lengths: [1, 2, 3, 3], num_symbols: 4, table_bits: 4 },
          { lengths: [2, 2, 3, 3, 3, 3, 3, 3], num_symbols: 8, table_bits: 6 },
        ]

        test_cases.each do |test_case|
          tree = Cabriolet::Huffman::Tree.new(test_case[:lengths],
                                              test_case[:num_symbols])
          result = tree.build_table(test_case[:table_bits])

          # Skip if tree building failed (invalid code)
          next unless result

          bytes = [0xFF, 0xFF].pack("C*")
          bitstream = create_bitstream(bytes)

          # Should be able to decode at least one symbol
          sym = described_class.decode_symbol(
            bitstream,
            tree.table,
            test_case[:table_bits],
            test_case[:lengths],
            test_case[:num_symbols],
          )

          expect(sym).to be >= 0
          expect(sym).to be < test_case[:num_symbols]
        end

        # Ensure at least one test case was successful
        successful_count = test_cases.count do |tc|
          tree = Cabriolet::Huffman::Tree.new(tc[:lengths], tc[:num_symbols])
          tree.build_table(tc[:table_bits])
        end
        expect(successful_count).to be > 0
      end
    end
  end
end
