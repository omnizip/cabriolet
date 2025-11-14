# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::Models::Folder do
  subject(:folder) { described_class.new }

  describe "#initialize" do
    it "initializes with default values" do
      expect(folder.comp_type).to eq(Cabriolet::Constants::COMP_TYPE_NONE)
      expect(folder.num_blocks).to eq(0)
      expect(folder.data_offset).to eq(0)
      expect(folder.data_cab).to be_nil
      expect(folder.next_folder).to be_nil
      expect(folder.merge_prev).to be_nil
      expect(folder.merge_next).to be_nil
    end
  end

  describe "#compression_method" do
    it "extracts compression method from comp_type" do
      folder.comp_type = Cabriolet::Constants::COMP_TYPE_MSZIP
      expect(folder.compression_method).to eq(Cabriolet::Constants::COMP_TYPE_MSZIP)
    end

    it "masks out compression level bits" do
      # Set MSZIP with level bits
      folder.comp_type = Cabriolet::Constants::COMP_TYPE_MSZIP | (5 << 8)
      expect(folder.compression_method).to eq(Cabriolet::Constants::COMP_TYPE_MSZIP)
    end

    it "returns NONE for uncompressed" do
      folder.comp_type = Cabriolet::Constants::COMP_TYPE_NONE
      expect(folder.compression_method).to eq(Cabriolet::Constants::COMP_TYPE_NONE)
    end

    it "returns LZX for LZX compression" do
      folder.comp_type = Cabriolet::Constants::COMP_TYPE_LZX
      expect(folder.compression_method).to eq(Cabriolet::Constants::COMP_TYPE_LZX)
    end

    it "returns Quantum for Quantum compression" do
      folder.comp_type = Cabriolet::Constants::COMP_TYPE_QUANTUM
      expect(folder.compression_method).to eq(Cabriolet::Constants::COMP_TYPE_QUANTUM)
    end
  end

  describe "#compression_level" do
    it "extracts compression level from comp_type" do
      # LZX with window size 15 (stored as level)
      folder.comp_type = Cabriolet::Constants::COMP_TYPE_LZX | (15 << 8)
      expect(folder.compression_level).to eq(15)
    end

    it "returns 0 when no level is set" do
      folder.comp_type = Cabriolet::Constants::COMP_TYPE_MSZIP
      expect(folder.compression_level).to eq(0)
    end

    it "extracts level for Quantum compression" do
      # Quantum with window size 21
      folder.comp_type = Cabriolet::Constants::COMP_TYPE_QUANTUM | (21 << 8)
      expect(folder.compression_level).to eq(21)
    end

    it "masks level to 5 bits" do
      # Set all bits in level field
      folder.comp_type = Cabriolet::Constants::COMP_TYPE_LZX | (0xFF << 8)
      expect(folder.compression_level).to eq(0x1F) # Only lower 5 bits
    end
  end

  describe "#compression_name" do
    it "returns 'None' for uncompressed" do
      folder.comp_type = Cabriolet::Constants::COMP_TYPE_NONE
      expect(folder.compression_name).to eq("None")
    end

    it "returns 'MSZIP' for MSZIP compression" do
      folder.comp_type = Cabriolet::Constants::COMP_TYPE_MSZIP
      expect(folder.compression_name).to eq("MSZIP")
    end

    it "returns 'Quantum' for Quantum compression" do
      folder.comp_type = Cabriolet::Constants::COMP_TYPE_QUANTUM
      expect(folder.compression_name).to eq("Quantum")
    end

    it "returns 'LZX' for LZX compression" do
      folder.comp_type = Cabriolet::Constants::COMP_TYPE_LZX
      expect(folder.compression_name).to eq("LZX")
    end

    it "returns 'Unknown' for invalid compression type" do
      folder.comp_type = 4 # After masking with 0x000F, still 4, which is invalid
      expect(folder.compression_name).to eq("Unknown")
    end

    it "handles compression type with level bits set" do
      folder.comp_type = Cabriolet::Constants::COMP_TYPE_LZX | (15 << 8)
      expect(folder.compression_name).to eq("LZX")
    end
  end

  describe "#uncompressed?" do
    context "when compression is NONE" do
      it "returns true" do
        folder.comp_type = Cabriolet::Constants::COMP_TYPE_NONE
        expect(folder.uncompressed?).to be(true)
      end
    end

    context "when compression is not NONE" do
      it "returns false for MSZIP" do
        folder.comp_type = Cabriolet::Constants::COMP_TYPE_MSZIP
        expect(folder.uncompressed?).to be(false)
      end

      it "returns false for LZX" do
        folder.comp_type = Cabriolet::Constants::COMP_TYPE_LZX
        expect(folder.uncompressed?).to be(false)
      end

      it "returns false for Quantum" do
        folder.comp_type = Cabriolet::Constants::COMP_TYPE_QUANTUM
        expect(folder.uncompressed?).to be(false)
      end
    end
  end

  describe "#needs_prev_merge?" do
    context "when merge_prev is nil" do
      it "returns false" do
        folder.merge_prev = nil
        expect(folder.needs_prev_merge?).to be(false)
      end
    end

    context "when merge_prev is set" do
      it "returns true" do
        folder.merge_prev = double("previous_folder")
        expect(folder.needs_prev_merge?).to be(true)
      end
    end
  end

  describe "#needs_next_merge?" do
    context "when merge_next is nil" do
      it "returns false" do
        folder.merge_next = nil
        expect(folder.needs_next_merge?).to be(false)
      end
    end

    context "when merge_next is set" do
      it "returns true" do
        folder.merge_next = double("next_folder")
        expect(folder.needs_next_merge?).to be(true)
      end
    end
  end

  describe "attribute accessors" do
    it "allows setting and getting comp_type" do
      folder.comp_type = Cabriolet::Constants::COMP_TYPE_LZX
      expect(folder.comp_type).to eq(Cabriolet::Constants::COMP_TYPE_LZX)
    end

    it "allows setting and getting num_blocks" do
      folder.num_blocks = 100
      expect(folder.num_blocks).to eq(100)
    end

    it "allows setting and getting data_offset" do
      folder.data_offset = 2048
      expect(folder.data_offset).to eq(2048)
    end

    it "allows setting and getting data_cab" do
      cabinet = double("cabinet")
      folder.data_cab = cabinet
      expect(folder.data_cab).to eq(cabinet)
    end

    it "allows setting and getting next_folder" do
      next_folder = described_class.new
      folder.next_folder = next_folder
      expect(folder.next_folder).to eq(next_folder)
    end

    it "allows setting and getting merge_prev" do
      prev_folder = described_class.new
      folder.merge_prev = prev_folder
      expect(folder.merge_prev).to eq(prev_folder)
    end

    it "allows setting and getting merge_next" do
      next_folder = described_class.new
      folder.merge_next = next_folder
      expect(folder.merge_next).to eq(next_folder)
    end
  end

  describe "compression type combinations" do
    it "handles MSZIP with various comp_type values" do
      [
        Cabriolet::Constants::COMP_TYPE_MSZIP,
        Cabriolet::Constants::COMP_TYPE_MSZIP | (1 << 8),
        Cabriolet::Constants::COMP_TYPE_MSZIP | (0xFF << 8),
      ].each do |comp_type|
        folder.comp_type = comp_type
        expect(folder.compression_method).to eq(Cabriolet::Constants::COMP_TYPE_MSZIP)
        expect(folder.compression_name).to eq("MSZIP")
      end
    end

    it "handles LZX with different window sizes" do
      [15, 16, 17, 18, 19, 20, 21].each do |window_size|
        folder.comp_type = Cabriolet::Constants::COMP_TYPE_LZX | (window_size << 8)
        expect(folder.compression_method).to eq(Cabriolet::Constants::COMP_TYPE_LZX)
        expect(folder.compression_level).to eq(window_size)
        expect(folder.compression_name).to eq("LZX")
      end
    end

    it "handles Quantum with different window sizes" do
      [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21].each do |window_size|
        folder.comp_type = Cabriolet::Constants::COMP_TYPE_QUANTUM | (window_size << 8)
        expect(folder.compression_method).to eq(Cabriolet::Constants::COMP_TYPE_QUANTUM)
        expect(folder.compression_level).to eq(window_size)
        expect(folder.compression_name).to eq("Quantum")
      end
    end
  end
end
