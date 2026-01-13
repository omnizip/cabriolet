# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "tempfile"
require_relative "../support/fixtures"

RSpec.describe Cabriolet::KWAJ::Decompressor do
  let(:decompressor) { described_class.new }

  describe "#open" do
    context "with basic KWAJ fixtures" do
      let(:fixture) { Fixtures.for(:kwaj).path(:f00) }

      it "opens and parses a valid KWAJ file" do
        header = decompressor.open(fixture)

        expect(header).to be_a(Cabriolet::Models::KWAJHeader)
        expect(header.comp_type).to eq(Cabriolet::Constants::KWAJ_COMP_NONE)
        decompressor.close(header)
      end
    end

    context "with multiple KWAJ fixtures" do
      Fixtures.for(:kwaj).scenario(:basic).each_with_index do |fixture, i|
        context "KWAJ fixture #{i + 1}" do
          let(:kwaj_fixture) { fixture }

          it "opens successfully" do
            header = decompressor.open(kwaj_fixture)
            expect(header).to be_a(Cabriolet::Models::KWAJHeader)
            decompressor.close(header)
          end
        end
      end
    end

    context "with invalid file" do
      it "raises ParseError for non-KWAJ file" do
        cab_fixture = Fixtures.for(:cab).path(:basic)

        expect do
          decompressor.open(cab_fixture)
        end.to raise_error(Cabriolet::ParseError)
      end
    end
  end

  describe "#close" do
    it "closes a KWAJ header without error" do
      fixture = Fixtures.for(:kwaj).path(:f00)
      header = decompressor.open(fixture)

      expect { decompressor.close(header) }.not_to raise_error
    end
  end

  describe "#extract" do
    context "with basic KWAJ fixtures" do
      let(:fixture) { Fixtures.for(:kwaj).path(:f00) }

      it "extracts data successfully" do
        header = decompressor.open(fixture)

        output = Tempfile.new(["kwaj", ".bin"])
        bytes = decompressor.extract(header, fixture, output.path)

        expect(bytes).to be > 0
        expect(File.exist?(output.path)).to be true
        expect(File.size(output.path)).to eq(bytes)

        output.close
        output.unlink
        decompressor.close(header)
      end
    end

    context "with multiple KWAJ fixtures" do
      Fixtures.for(:kwaj).scenario(:basic).each_with_index do |fixture, i|
        context "KWAJ fixture #{i + 1}" do
          let(:kwaj_fixture) { fixture }

          it "extracts successfully" do
            header = decompressor.open(kwaj_fixture)

            output = Tempfile.new(["kwaj_#{i}", ".bin"])
            bytes = decompressor.extract(header, kwaj_fixture, output.path)

            expect(bytes).to be >= 0
            expect(File.exist?(output.path)).to be true

            output.close
            output.unlink
            decompressor.close(header)
          end
        end
      end
    end
  end

  describe "#decompress" do
    it "performs one-shot decompression" do
      input = Fixtures.for(:kwaj).path(:f00)
      output = Tempfile.new(["kwaj", ".bin"])

      bytes = decompressor.decompress(input, output.path)

      expect(bytes).to be > 0
      expect(File.exist?(output.path)).to be true

      output.close
      output.unlink
    end

    it "extracts to correct output" do
      input = Fixtures.for(:kwaj).path(:f00)
      output = Tempfile.new(["kwaj", ".bin"])

      decompressor.decompress(input, output.path)

      expect(File.size(output.path)).to be > 0

      output.close
      output.unlink
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

  describe "round-trip compatibility" do
    let(:compressor) { Cabriolet::KWAJ::Compressor.new }

    it "compresses and decompresses data correctly" do
      Dir.mktmpdir do |tmpdir|
        original_data = "Round-trip KWAJ test data!"
        compressed = File.join(tmpdir, "test.kwj")
        decompressed = File.join(tmpdir, "test.out")

        # Compress
        compressor.compress_data(
          original_data,
          compressed,
          compression: :szdd,
          include_length: true,
        )

        # Decompress
        bytes = decompressor.decompress(compressed, decompressed)

        expect(bytes).to eq(original_data.bytesize)
        result = File.read(decompressed)
        expect(result).to eq(original_data)
      end
    end
  end
end
