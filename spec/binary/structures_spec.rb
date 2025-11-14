# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::Binary do
  let(:fixture_file) do
    File.join(__dir__, "../fixtures/libmspack/cabd/normal_2files_1folder.cab")
  end
  let(:fixture_data) { File.binread(fixture_file) }

  describe Cabriolet::Binary::CFHeader do
    let(:header) { described_class.read(fixture_data) }

    it "parses the CAB signature" do
      expect(header.signature).to eq("MSCF")
    end

    it "parses version information" do
      expect(header.major_version.to_i).to be_a(Integer)
      expect(header.minor_version.to_i).to be_a(Integer)
    end

    it "parses folder and file counts" do
      expect(header.num_folders).to be > 0
      expect(header.num_files).to be > 0
    end

    it "parses flags" do
      expect(header.flags.to_i).to be_a(Integer)
    end

    it "parses set information" do
      expect(header.set_id.to_i).to be_a(Integer)
      expect(header.cabinet_index.to_i).to be_a(Integer)
    end

    it "parses offsets and sizes" do
      expect(header.cabinet_size).to be > 0
      expect(header.files_offset).to be > 0
    end

    it "parses reserved fields" do
      expect(header.reserved1.to_i).to be_a(Integer)
      expect(header.reserved2.to_i).to be_a(Integer)
      expect(header.reserved3.to_i).to be_a(Integer)
    end

    context "with reserved header present" do
      let(:reserve_file) do
        File.join(__dir__, "../fixtures/libmspack/cabd/reserve_HFD.cab")
      end
      let(:reserve_data) { File.binread(reserve_file) }
      let(:header_with_reserve) { described_class.read(reserve_data[0, Cabriolet::Constants::CFHEADER_SIZE]) }

      it "parses header even when flag indicates reserve data" do
        expect(header_with_reserve.flags.anybits?(Cabriolet::Constants::FLAG_RESERVE_PRESENT)).to be(true)
        # NOTE: Reserved data is handled separately by Parser, not by CFHeader structure
      end
    end

    context "with invalid signature" do
      let(:bad_sig_file) do
        File.join(__dir__, "../fixtures/libmspack/cabd/bad_signature.cab")
      end
      let(:bad_data) { File.binread(bad_sig_file) }

      it "still parses but has wrong signature" do
        bad_header = described_class.read(bad_data)
        expect(bad_header.signature).not_to eq("MSCF")
      end
    end
  end

  describe Cabriolet::Binary::CFFolder do
    it "parses folder structure" do
      # Skip to first folder (after header)
      Cabriolet::Binary::CFHeader.read(fixture_data)
      folder_offset = Cabriolet::Constants::CFHEADER_SIZE
      folder_data = fixture_data[folder_offset..]

      folder = described_class.read(folder_data)

      expect(folder.data_offset.to_i).to be_a(Integer)
      expect(folder.num_blocks).to be > 0
      expect(folder.comp_type.to_i).to be_a(Integer)
    end

    it "has correct structure size" do
      expect(Cabriolet::Constants::CFFOLDER_SIZE).to eq(8)
    end

    it "parses compression type" do
      Cabriolet::Binary::CFHeader.read(fixture_data)
      folder_offset = Cabriolet::Constants::CFHEADER_SIZE
      folder_data = fixture_data[folder_offset..]

      folder = described_class.read(folder_data)
      comp_method = folder.comp_type & Cabriolet::Constants::COMP_TYPE_MASK

      expect([
               Cabriolet::Constants::COMP_TYPE_NONE,
               Cabriolet::Constants::COMP_TYPE_MSZIP,
               Cabriolet::Constants::COMP_TYPE_LZX,
               Cabriolet::Constants::COMP_TYPE_QUANTUM,
             ]).to include(comp_method)
    end
  end

  describe Cabriolet::Binary::CFFile do
    it "parses file structure" do
      # Create a minimal file structure for testing
      file_data = [
        0x1000,     # uncompressed_size (uint32)
        0x0000,     # folder_offset (uint32)
        0x0000,     # folder_index (uint16)
        0x4D21,     # date (uint16) - example date
        0xBF7D,     # time (uint16) - example time
        0x0020, # attribs (uint16)
      ].pack("VVvvvv")

      file = described_class.read(file_data)

      expect(file.uncompressed_size).to eq(0x1000)
      expect(file.folder_offset).to eq(0)
      expect(file.folder_index).to eq(0)
      expect(file.date.to_i).to be_a(Integer)
      expect(file.time.to_i).to be_a(Integer)
      expect(file.attribs.to_i).to be_a(Integer)
    end

    it "has correct structure size" do
      expect(Cabriolet::Constants::CFFILE_SIZE).to eq(16)
    end
  end

  describe Cabriolet::Binary::CFData do
    it "parses data block structure" do
      data_block = [
        0x12345678, # checksum (uint32)
        0x1000,     # compressed_size (uint16)
        0x2000, # uncompressed_size (uint16)
      ].pack("Vvv")

      cfdata = described_class.read(data_block)

      expect(cfdata.checksum).to eq(0x12345678)
      expect(cfdata.compressed_size).to eq(0x1000)
      expect(cfdata.uncompressed_size).to eq(0x2000)
    end

    it "has correct structure size" do
      expect(Cabriolet::Constants::CFDATA_SIZE).to eq(8)
    end
  end

  describe "structure field ordering" do
    it "uses little-endian byte order" do
      # Create a simple 16-bit value: 0x1234
      data = [0x1234].pack("v") # little-endian
      expect(data).to eq("\x34\x12")
    end

    it "correctly reads multi-byte fields" do
      # Test uint32 field
      data = [0x12345678].pack("V")
      expect(data).to eq("\x78\x56\x34\x12")
    end
  end
end
