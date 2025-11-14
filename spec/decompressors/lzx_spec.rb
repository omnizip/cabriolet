# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::Decompressors::LZX do
  let(:io_system) { Cabriolet::System::IOSystem.new }

  describe "#initialize" do
    context "with valid window_bits" do
      it "initializes with window_bits 15 for regular LZX" do
        input = Cabriolet::System::MemoryHandle.new("")
        output = Cabriolet::System::MemoryHandle.new("")

        lzx = described_class.new(io_system, input, output, 4096,
                                  window_bits: 15)

        expect(lzx.window_bits).to eq(15)
        expect(lzx.is_delta).to be false
      end

      it "initializes with window_bits 21 for regular LZX" do
        input = Cabriolet::System::MemoryHandle.new("")
        output = Cabriolet::System::MemoryHandle.new("")

        lzx = described_class.new(io_system, input, output, 4096,
                                  window_bits: 21)

        expect(lzx.window_bits).to eq(21)
      end

      it "initializes with window_bits 17 for LZX DELTA" do
        input = Cabriolet::System::MemoryHandle.new("")
        output = Cabriolet::System::MemoryHandle.new("")

        lzx = described_class.new(io_system, input, output, 4096,
                                  window_bits: 17, is_delta: true)

        expect(lzx.window_bits).to eq(17)
        expect(lzx.is_delta).to be true
      end

      it "initializes with window_bits 25 for LZX DELTA" do
        input = Cabriolet::System::MemoryHandle.new("")
        output = Cabriolet::System::MemoryHandle.new("")

        lzx = described_class.new(io_system, input, output, 4096,
                                  window_bits: 25, is_delta: true)

        expect(lzx.window_bits).to eq(25)
        expect(lzx.is_delta).to be true
      end
    end

    context "with invalid window_bits" do
      it "raises error for window_bits < 15 in regular LZX" do
        input = Cabriolet::System::MemoryHandle.new("")
        output = Cabriolet::System::MemoryHandle.new("")

        expect do
          described_class.new(io_system, input, output, 4096,
                              window_bits: 14)
        end.to raise_error(Cabriolet::ArgumentError, /must be 15-21/)
      end

      it "raises error for window_bits > 21 in regular LZX" do
        input = Cabriolet::System::MemoryHandle.new("")
        output = Cabriolet::System::MemoryHandle.new("")

        expect do
          described_class.new(io_system, input, output, 4096,
                              window_bits: 22)
        end.to raise_error(Cabriolet::ArgumentError, /must be 15-21/)
      end

      it "raises error for window_bits < 17 in LZX DELTA" do
        input = Cabriolet::System::MemoryHandle.new("")
        output = Cabriolet::System::MemoryHandle.new("")

        expect do
          described_class.new(io_system, input, output, 4096,
                              window_bits: 16, is_delta: true)
        end.to raise_error(Cabriolet::ArgumentError, /must be 17-25/)
      end

      it "raises error for window_bits > 25 in LZX DELTA" do
        input = Cabriolet::System::MemoryHandle.new("")
        output = Cabriolet::System::MemoryHandle.new("")

        expect do
          described_class.new(io_system, input, output, 4096,
                              window_bits: 26, is_delta: true)
        end.to raise_error(Cabriolet::ArgumentError, /must be 17-25/)
      end
    end

    it "initializes with reset_interval" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15, reset_interval: 2)

      expect(lzx.reset_interval).to eq(2)
    end

    it "initializes with output_length" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15, output_length: 65_536)

      expect(lzx.output_length).to eq(65_536)
    end
  end

  describe "#set_output_length" do
    it "updates output_length" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15)

      lzx.set_output_length(32_768)
      expect(lzx.output_length).to eq(32_768)
    end

    it "ignores zero or negative length" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15, output_length: 100)

      lzx.set_output_length(0)
      expect(lzx.output_length).to eq(100)

      lzx.set_output_length(-1)
      expect(lzx.output_length).to eq(100)
    end
  end

  describe "#decompress" do
    it "returns 0 for zero bytes requested" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15)

      expect(lzx.decompress(0)).to eq(0)
    end

    it "returns 0 for negative bytes requested" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15)

      expect(lzx.decompress(-1)).to eq(0)
    end
  end

  describe "constants" do
    it "defines FRAME_SIZE" do
      expect(described_class::FRAME_SIZE).to eq(32_768)
    end

    it "defines block types" do
      expect(described_class::BLOCKTYPE_INVALID).to eq(0)
      expect(described_class::BLOCKTYPE_VERBATIM).to eq(1)
      expect(described_class::BLOCKTYPE_ALIGNED).to eq(2)
      expect(described_class::BLOCKTYPE_UNCOMPRESSED).to eq(3)
    end

    it "defines match constants" do
      expect(described_class::MIN_MATCH).to eq(2)
      expect(described_class::MAX_MATCH).to eq(257)
      expect(described_class::NUM_CHARS).to eq(256)
    end

    it "defines tree constants" do
      expect(described_class::PRETREE_NUM_ELEMENTS).to eq(20)
      expect(described_class::PRETREE_MAXSYMBOLS).to eq(20)
      expect(described_class::PRETREE_TABLEBITS).to eq(6)

      expect(described_class::ALIGNED_NUM_ELEMENTS).to eq(8)
      expect(described_class::ALIGNED_MAXSYMBOLS).to eq(8)
      expect(described_class::ALIGNED_TABLEBITS).to eq(7)

      expect(described_class::NUM_PRIMARY_LENGTHS).to eq(7)
      expect(described_class::NUM_SECONDARY_LENGTHS).to eq(249)
      expect(described_class::LENGTH_MAXSYMBOLS).to eq(250)
      expect(described_class::LENGTH_TABLEBITS).to eq(12)
    end

    it "defines position slots" do
      expect(described_class::POSITION_SLOTS).to be_an(Array)
      expect(described_class::POSITION_SLOTS.size).to eq(11)
      expect(described_class::POSITION_SLOTS.first).to eq(30)
      expect(described_class::POSITION_SLOTS.last).to eq(290)
    end

    it "defines extra bits" do
      expect(described_class::EXTRA_BITS).to be_an(Array)
      expect(described_class::EXTRA_BITS.size).to eq(36)
      expect(described_class::EXTRA_BITS[0...4]).to all(eq(0))
    end

    it "defines position base" do
      expect(described_class::POSITION_BASE).to be_an(Array)
      expect(described_class::POSITION_BASE.size).to eq(290)
      expect(described_class::POSITION_BASE.first).to eq(0)
      expect(described_class::POSITION_BASE[1]).to eq(1)
    end
  end

  describe "integration tests with fixtures" do
    let(:fixtures_dir) { File.join(__dir__, "../fixtures/libmspack/cabd") }

    context "with mszip_lzx_qtm.cab" do
      let(:cab_file) { File.join(fixtures_dir, "mszip_lzx_qtm.cab") }

      it "exists" do
        expect(File.exist?(cab_file)).to be true
      end

      # NOTE: Full integration test would require parsing the CAB file
      # and extracting LZX-compressed data. This is a placeholder for
      # when the full CAB parser is integrated.
    end

    context "with LZX-specific fixtures" do
      let(:lzx_premature_matches) do
        File.join(fixtures_dir, "lzx-premature-matches.cab")
      end
      let(:lzx_main_tree_no_lengths) do
        File.join(fixtures_dir, "lzx-main-tree-no-lengths.cab")
      end

      it "has lzx-premature-matches.cab" do
        expect(File.exist?(lzx_premature_matches)).to be true
      end

      it "has lzx-main-tree-no-lengths.cab" do
        expect(File.exist?(lzx_main_tree_no_lengths)).to be true
      end
    end
  end

  describe "window size calculations" do
    it "calculates correct window size for window_bits 15" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15)

      # Window size = 2^15 = 32KB
      expect(lzx.instance_variable_get(:@window_size)).to eq(32_768)
    end

    it "calculates correct window size for window_bits 21" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 21)

      # Window size = 2^21 = 2MB
      expect(lzx.instance_variable_get(:@window_size)).to eq(2_097_152)
    end

    it "calculates correct number of offsets for window_bits 15" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15)

      # POSITION_SLOTS[0] = 30, so num_offsets = 30 << 3 = 240
      expect(lzx.instance_variable_get(:@num_offsets)).to eq(240)
    end
  end

  describe "state initialization" do
    it "initializes R0, R1, R2 to 1" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15)

      expect(lzx.instance_variable_get(:@r0)).to eq(1)
      expect(lzx.instance_variable_get(:@r1)).to eq(1)
      expect(lzx.instance_variable_get(:@r2)).to eq(1)
    end

    it "initializes block state" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15)

      expect(lzx.instance_variable_get(:@block_type)).to eq(0)
      expect(lzx.instance_variable_get(:@block_length)).to eq(0)
      expect(lzx.instance_variable_get(:@block_remaining)).to eq(0)
      expect(lzx.instance_variable_get(:@header_read)).to be false
    end

    it "initializes Intel E8 state" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15)

      expect(lzx.instance_variable_get(:@intel_filesize)).to eq(0)
      expect(lzx.instance_variable_get(:@intel_started)).to be false
    end

    it "initializes frame tracking" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15)

      expect(lzx.instance_variable_get(:@window_posn)).to eq(0)
      expect(lzx.instance_variable_get(:@frame_posn)).to eq(0)
      expect(lzx.instance_variable_get(:@frame)).to eq(0)
      expect(lzx.instance_variable_get(:@offset)).to eq(0)
    end
  end

  describe "Huffman tree initialization" do
    it "initializes all tree length arrays" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15)

      pretree_lengths = lzx.instance_variable_get(:@pretree_lengths)
      expect(pretree_lengths).to be_an(Array)
      expect(pretree_lengths.size).to eq(20)
      expect(pretree_lengths).to all(eq(0))

      maintree_lengths = lzx.instance_variable_get(:@maintree_lengths)
      expect(maintree_lengths).to be_an(Array)
      expect(maintree_lengths.size).to eq(256 + 240) # NUM_CHARS + num_offsets

      length_lengths = lzx.instance_variable_get(:@length_lengths)
      expect(length_lengths).to be_an(Array)
      expect(length_lengths.size).to eq(250)

      aligned_lengths = lzx.instance_variable_get(:@aligned_lengths)
      expect(aligned_lengths).to be_an(Array)
      expect(aligned_lengths.size).to eq(8)
    end

    it "initializes tree objects to nil" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15)

      expect(lzx.instance_variable_get(:@pretree)).to be_nil
      expect(lzx.instance_variable_get(:@maintree)).to be_nil
      expect(lzx.instance_variable_get(:@length_tree)).to be_nil
      expect(lzx.instance_variable_get(:@aligned_tree)).to be_nil
    end
  end
end
