# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Cabriolet::CHM::Decompressor do
  let(:fixture_dir) { File.join(__dir__, "../fixtures/libmspack/chmd") }
  let(:decompressor) { described_class.new }

  describe "#open" do
    let(:test_file) { File.join(fixture_dir, "encints-64bit-both.chm") }

    it "opens a CHM file successfully" do
      chm = decompressor.open(test_file)

      expect(chm).to be_a(Cabriolet::Models::CHMHeader)
      expect(chm.filename).to eq(test_file)
      expect(chm.version.to_i).to be_a(Integer)

      decompressor.close
    end

    it "parses all file entries by default" do
      chm = decompressor.open(test_file)

      expect(chm.all_files.length).to be > 0

      decompressor.close
    end
  end

  describe "#fast_open" do
    let(:test_file) { File.join(fixture_dir, "encints-64bit-both.chm") }

    it "opens a CHM file without parsing all entries" do
      chm = decompressor.fast_open(test_file)

      expect(chm).to be_a(Cabriolet::Models::CHMHeader)
      expect(chm.files).to be_nil

      decompressor.close
    end
  end

  describe "#close" do
    let(:test_file) { File.join(fixture_dir, "encints-64bit-both.chm") }

    it "closes the CHM file" do
      decompressor.open(test_file)
      expect { decompressor.close }.not_to raise_error
    end
  end

  describe "error handling" do
    it "raises error for non-existent files" do
      expect do
        decompressor.open("nonexistent.chm")
      end.to raise_error
    end

    it "raises error for invalid CHM files" do
      file = Tempfile.new(["test", ".chm"])
      file.write("NOT A CHM FILE")
      file.close

      expect do
        decompressor.open(file.path)
      end.to raise_error(StandardError) # BinData raises IOError for truncated data

      file.unlink
    end
  end
end
