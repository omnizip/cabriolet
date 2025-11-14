# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::Models::Cabinet do
  subject(:cabinet) { described_class.new }

  describe "#initialize" do
    it "initializes with default values" do
      expect(cabinet.filename).to be_nil
      expect(cabinet.base_offset).to eq(0)
      expect(cabinet.length).to eq(0)
      expect(cabinet.set_id).to eq(0)
      expect(cabinet.set_index).to eq(0)
      expect(cabinet.flags).to eq(0)
      expect(cabinet.header_resv).to eq(0)
      expect(cabinet.folders).to eq([])
      expect(cabinet.files).to eq([])
    end

    it "accepts a filename parameter" do
      cab = described_class.new("test.cab")
      expect(cab.filename).to eq("test.cab")
    end

    it "initializes optional fields to nil" do
      expect(cabinet.prevname).to be_nil
      expect(cabinet.nextname).to be_nil
      expect(cabinet.previnfo).to be_nil
      expect(cabinet.nextinfo).to be_nil
      expect(cabinet.next_cabinet).to be_nil
      expect(cabinet.prev_cabinet).to be_nil
    end

    it "initializes blocks_offset and block_resv" do
      expect(cabinet.blocks_offset).to eq(0)
      expect(cabinet.block_resv).to eq(0)
    end
  end

  describe "#has_prev?" do
    context "when FLAG_PREV_CABINET is set" do
      it "returns true" do
        cabinet.flags = Cabriolet::Constants::FLAG_PREV_CABINET
        expect(cabinet.has_prev?).to be(true)
      end
    end

    context "when FLAG_PREV_CABINET is not set" do
      it "returns false" do
        cabinet.flags = 0
        expect(cabinet.has_prev?).to be(false)
      end
    end

    context "with combined flags" do
      it "detects FLAG_PREV_CABINET in combination" do
        cabinet.flags = Cabriolet::Constants::FLAG_PREV_CABINET |
          Cabriolet::Constants::FLAG_RESERVE_PRESENT
        expect(cabinet.has_prev?).to be(true)
      end
    end
  end

  describe "#has_next?" do
    context "when FLAG_NEXT_CABINET is set" do
      it "returns true" do
        cabinet.flags = Cabriolet::Constants::FLAG_NEXT_CABINET
        expect(cabinet.has_next?).to be(true)
      end
    end

    context "when FLAG_NEXT_CABINET is not set" do
      it "returns false" do
        cabinet.flags = 0
        expect(cabinet.has_next?).to be(false)
      end
    end

    context "with combined flags" do
      it "detects FLAG_NEXT_CABINET in combination" do
        cabinet.flags = Cabriolet::Constants::FLAG_NEXT_CABINET |
          Cabriolet::Constants::FLAG_RESERVE_PRESENT
        expect(cabinet.has_next?).to be(true)
      end
    end
  end

  describe "#has_reserve?" do
    context "when FLAG_RESERVE_PRESENT is set" do
      it "returns true" do
        cabinet.flags = Cabriolet::Constants::FLAG_RESERVE_PRESENT
        expect(cabinet.has_reserve?).to be(true)
      end
    end

    context "when FLAG_RESERVE_PRESENT is not set" do
      it "returns false" do
        cabinet.flags = 0
        expect(cabinet.has_reserve?).to be(false)
      end
    end

    context "with all flags set" do
      it "detects FLAG_RESERVE_PRESENT in combination" do
        cabinet.flags = Cabriolet::Constants::FLAG_PREV_CABINET |
          Cabriolet::Constants::FLAG_NEXT_CABINET |
          Cabriolet::Constants::FLAG_RESERVE_PRESENT
        expect(cabinet.has_reserve?).to be(true)
      end
    end
  end

  describe "#set_blocks_info" do
    it "sets blocks_offset and block_resv" do
      cabinet.set_blocks_info(1000, 8)
      expect(cabinet.blocks_offset).to eq(1000)
      expect(cabinet.block_resv).to eq(8)
    end

    it "updates existing values" do
      cabinet.set_blocks_info(500, 4)
      cabinet.set_blocks_info(1000, 8)
      expect(cabinet.blocks_offset).to eq(1000)
      expect(cabinet.block_resv).to eq(8)
    end
  end

  describe "#file_count" do
    it "returns 0 when no files" do
      expect(cabinet.file_count).to eq(0)
    end

    it "returns number of files in array" do
      cabinet.files = [double("file1"), double("file2"), double("file3")]
      expect(cabinet.file_count).to eq(3)
    end
  end

  describe "#folder_count" do
    it "returns 0 when no folders" do
      expect(cabinet.folder_count).to eq(0)
    end

    it "returns number of folders in array" do
      cabinet.folders = [double("folder1"), double("folder2")]
      expect(cabinet.folder_count).to eq(2)
    end
  end

  describe "attribute accessors" do
    it "allows setting and getting filename" do
      cabinet.filename = "archive.cab"
      expect(cabinet.filename).to eq("archive.cab")
    end

    it "allows setting and getting base_offset" do
      cabinet.base_offset = 512
      expect(cabinet.base_offset).to eq(512)
    end

    it "allows setting and getting length" do
      cabinet.length = 10_240
      expect(cabinet.length).to eq(10_240)
    end

    it "allows setting and getting set_id" do
      cabinet.set_id = 12_345
      expect(cabinet.set_id).to eq(12_345)
    end

    it "allows setting and getting set_index" do
      cabinet.set_index = 2
      expect(cabinet.set_index).to eq(2)
    end

    it "allows setting and getting flags" do
      cabinet.flags = 0x07
      expect(cabinet.flags).to eq(0x07)
    end

    it "allows setting and getting header_resv" do
      cabinet.header_resv = 16
      expect(cabinet.header_resv).to eq(16)
    end

    it "allows setting and getting prevname" do
      cabinet.prevname = "prev.cab"
      expect(cabinet.prevname).to eq("prev.cab")
    end

    it "allows setting and getting nextname" do
      cabinet.nextname = "next.cab"
      expect(cabinet.nextname).to eq("next.cab")
    end

    it "allows setting and getting previnfo" do
      cabinet.previnfo = "Previous disk"
      expect(cabinet.previnfo).to eq("Previous disk")
    end

    it "allows setting and getting nextinfo" do
      cabinet.nextinfo = "Next disk"
      expect(cabinet.nextinfo).to eq("Next disk")
    end

    it "allows setting and getting next_cabinet" do
      next_cab = described_class.new
      cabinet.next_cabinet = next_cab
      expect(cabinet.next_cabinet).to eq(next_cab)
    end

    it "allows setting and getting prev_cabinet" do
      prev_cab = described_class.new
      cabinet.prev_cabinet = prev_cab
      expect(cabinet.prev_cabinet).to eq(prev_cab)
    end
  end

  describe "read-only attributes" do
    it "allows reading blocks_offset" do
      cabinet.set_blocks_info(1000, 8)
      expect(cabinet.blocks_offset).to eq(1000)
    end

    it "allows reading block_resv" do
      cabinet.set_blocks_info(1000, 8)
      expect(cabinet.block_resv).to eq(8)
    end

    it "does not allow direct setting of blocks_offset" do
      expect(cabinet).not_to respond_to(:blocks_offset=)
    end

    it "does not allow direct setting of block_resv" do
      expect(cabinet).not_to respond_to(:block_resv=)
    end
  end
end
