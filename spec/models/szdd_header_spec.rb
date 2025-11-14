# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::Models::SZDDHeader do
  describe "#initialize" do
    it "creates a NORMAL format header with default values" do
      header = described_class.new
      expect(header.format).to eq(described_class::FORMAT_NORMAL)
      expect(header.length).to eq(0)
      expect(header.missing_char).to be_nil
      expect(header.filename).to be_nil
    end

    it "creates a header with specified values" do
      header = described_class.new(
        format: described_class::FORMAT_QBASIC,
        length: 12_345,
        missing_char: "t",
        filename: "test.txt",
      )

      expect(header.format).to eq(described_class::FORMAT_QBASIC)
      expect(header.length).to eq(12_345)
      expect(header.missing_char).to eq("t")
      expect(header.filename).to eq("test.txt")
    end
  end

  describe "#normal_format?" do
    it "returns true for NORMAL format" do
      header = described_class.new(format: described_class::FORMAT_NORMAL)
      expect(header.normal_format?).to be true
    end

    it "returns false for QBASIC format" do
      header = described_class.new(format: described_class::FORMAT_QBASIC)
      expect(header.normal_format?).to be false
    end
  end

  describe "#qbasic_format?" do
    it "returns true for QBASIC format" do
      header = described_class.new(format: described_class::FORMAT_QBASIC)
      expect(header.qbasic_format?).to be true
    end

    it "returns false for NORMAL format" do
      header = described_class.new(format: described_class::FORMAT_NORMAL)
      expect(header.qbasic_format?).to be false
    end
  end

  describe "#suggested_filename" do
    context "with NORMAL format and missing character" do
      it "replaces trailing underscore with missing character" do
        header = described_class.new(
          format: described_class::FORMAT_NORMAL,
          missing_char: "t",
        )

        expect(header.suggested_filename("file.tx_")).to eq("file.txt")
      end

      it "handles various file extensions" do
        header = described_class.new(
          format: described_class::FORMAT_NORMAL,
          missing_char: "l",
        )

        expect(header.suggested_filename("setup.dl_")).to eq("setup.dll")
      end
    end

    context "with NORMAL format but no missing character" do
      it "returns the original filename" do
        header = described_class.new(
          format: described_class::FORMAT_NORMAL,
          missing_char: nil,
        )

        expect(header.suggested_filename("file.tx_")).to eq("file.tx_")
      end
    end

    context "with QBASIC format" do
      it "returns the original filename" do
        header = described_class.new(
          format: described_class::FORMAT_QBASIC,
          missing_char: nil,
        )

        expect(header.suggested_filename("file.dat")).to eq("file.dat")
      end
    end

    context "with filename not ending in underscore" do
      it "returns the original filename unchanged" do
        header = described_class.new(
          format: described_class::FORMAT_NORMAL,
          missing_char: "t",
        )

        expect(header.suggested_filename("file.txt")).to eq("file.txt")
      end
    end
  end
end
