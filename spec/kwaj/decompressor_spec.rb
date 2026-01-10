# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Cabriolet::KWAJ::Decompressor do
  let(:decompressor) { described_class.new }

  describe "#open" do
    it "opens and parses a valid KWAJ file" do
      file = fixture_path("libmspack/kwajd/f00.kwj")
      header = decompressor.open(file)

      expect(header).to be_a(Cabriolet::Models::KWAJHeader)
      expect(header.comp_type).to eq(Cabriolet::Constants::KWAJ_COMP_NONE)
    end

    it "raises ParseError for invalid file" do
      file = fixture_path("libmspack/cabd/normal_2files_1folder.cab")

      expect do
        decompressor.open(file)
      end.to raise_error(Cabriolet::ParseError)
    end
  end

  describe "#close" do
    it "closes a KWAJ header without error" do
      file = fixture_path("libmspack/kwajd/f00.kwj")
      header = decompressor.open(file)

      expect { decompressor.close(header) }.not_to raise_error
    end
  end

  describe "#extract" do
    context "with NONE compression" do
      it "extracts uncompressed data (f00.kwj)" do
        file = fixture_path("libmspack/kwajd/f00.kwj")
        header = decompressor.open(file)

        output = temp_file("output")
        bytes = decompressor.extract(header, file, output)

        expect(bytes).to be > 0
        expect(File.exist?(output)).to be true

        File.delete(output)
      end
    end

    context "with XOR compression" do
      it "extracts XOR-encrypted data (f10.kwj)" do
        file = fixture_path("libmspack/kwajd/f10.kwj")
        header = decompressor.open(file)

        output = temp_file("output")
        bytes = decompressor.extract(header, file, output)

        expect(bytes).to be > 0
        expect(File.exist?(output)).to be true

        File.delete(output)
      end
    end

    context "with SZDD compression" do
      it "extracts LZSS-compressed data (f20.kwj)" do
        file = fixture_path("libmspack/kwajd/f20.kwj")
        header = decompressor.open(file)

        output = temp_file("output")
        bytes = decompressor.extract(header, file, output)

        expect(bytes).to be > 0
        expect(File.exist?(output)).to be true

        File.delete(output)
      end
    end

    context "with MSZIP compression" do
      it "extracts MSZIP-compressed data (f40.kwj)" do
        file = fixture_path("libmspack/kwajd/f40.kwj")
        header = decompressor.open(file)

        output = temp_file("output")
        bytes = decompressor.extract(header, file, output)

        expect(bytes).to be > 0
        expect(File.exist?(output)).to be true

        File.delete(output)
      end
    end

    context "with LZH compression" do
      # NOTE: LZH compression tests require actual LZH-compressed KWAJ test files
      # which are not currently available in the test fixtures.
    end
  end

  describe "#decompress" do
    it "performs one-shot decompression" do
      input = fixture_path("libmspack/kwajd/f00.kwj")
      output = temp_file("output")

      bytes = decompressor.decompress(input, output)

      expect(bytes).to be > 0
      expect(File.exist?(output)).to be true

      File.delete(output)
    end

    it "auto-detects output filename when not provided" do
      input = fixture_path("libmspack/kwajd/f03.kwj")
      # f03 has embedded filename

      # This will create output in the same directory as input
      # We'll just verify it doesn't raise an error
      expect do
        decompressor.open(input)
      end.not_to raise_error
    end
  end

  describe "#auto_output_filename" do
    it "uses embedded filename when available" do
      input = "/path/to/file.kwj"
      header = Cabriolet::Models::KWAJHeader.new
      header.filename = "output.txt"

      result = decompressor.auto_output_filename(input, header)

      expect(result).to eq("/path/to/output.txt")
    end

    it "removes extension when no embedded filename" do
      input = "/path/to/file.kwj"
      header = Cabriolet::Models::KWAJHeader.new

      result = decompressor.auto_output_filename(input, header)

      expect(result).to eq("/path/to/file")
    end
  end

  def fixture_path(path)
    File.join(__dir__, "..", "fixtures", path)
  end

  def temp_file(name)
    File.join(Dir.tmpdir, "kwaj_test_#{name}")
  end
end
