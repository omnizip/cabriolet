# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::Models::KWAJHeader do
  let(:header) { described_class.new }

  describe "#initialize" do
    it "sets default values" do
      expect(header.comp_type).to eq(Cabriolet::Constants::KWAJ_COMP_NONE)
      expect(header.data_offset).to eq(0)
      expect(header.headers).to eq(0)
      expect(header.length).to be_nil
      expect(header.filename).to be_nil
      expect(header.extra).to be_nil
      expect(header.extra_length).to eq(0)
    end
  end

  describe "#compression_name" do
    it "returns 'None' for KWAJ_COMP_NONE" do
      header.comp_type = Cabriolet::Constants::KWAJ_COMP_NONE
      expect(header.compression_name).to eq("None")
    end

    it "returns 'XOR' for KWAJ_COMP_XOR" do
      header.comp_type = Cabriolet::Constants::KWAJ_COMP_XOR
      expect(header.compression_name).to eq("XOR")
    end

    it "returns 'SZDD' for KWAJ_COMP_SZDD" do
      header.comp_type = Cabriolet::Constants::KWAJ_COMP_SZDD
      expect(header.compression_name).to eq("SZDD")
    end

    it "returns 'LZH' for KWAJ_COMP_LZH" do
      header.comp_type = Cabriolet::Constants::KWAJ_COMP_LZH
      expect(header.compression_name).to eq("LZH")
    end

    it "returns 'MSZIP' for KWAJ_COMP_MSZIP" do
      header.comp_type = Cabriolet::Constants::KWAJ_COMP_MSZIP
      expect(header.compression_name).to eq("MSZIP")
    end

    it "returns 'Unknown' for unrecognized type" do
      header.comp_type = 999
      expect(header.compression_name).to eq("Unknown (999)")
    end
  end

  describe "#has_length?" do
    it "returns true when length flag is set" do
      header.headers = Cabriolet::Constants::KWAJ_HDR_HASLENGTH
      expect(header.has_length?).to be true
    end

    it "returns false when length flag is not set" do
      header.headers = 0
      expect(header.has_length?).to be false
    end
  end

  describe "#has_filename?" do
    it "returns true when filename flag is set" do
      header.headers = Cabriolet::Constants::KWAJ_HDR_HASFILENAME
      expect(header.has_filename?).to be true
    end

    it "returns false when filename flag is not set" do
      header.headers = 0
      expect(header.has_filename?).to be false
    end
  end

  describe "#has_file_extension?" do
    it "returns true when file extension flag is set" do
      header.headers = Cabriolet::Constants::KWAJ_HDR_HASFILEEXT
      expect(header.has_file_extension?).to be true
    end

    it "returns false when file extension flag is not set" do
      header.headers = 0
      expect(header.has_file_extension?).to be false
    end
  end

  describe "#has_extra_text?" do
    it "returns true when extra text flag is set" do
      header.headers = Cabriolet::Constants::KWAJ_HDR_HASEXTRATEXT
      expect(header.has_extra_text?).to be true
    end

    it "returns false when extra text flag is not set" do
      header.headers = 0
      expect(header.has_extra_text?).to be false
    end
  end
end
