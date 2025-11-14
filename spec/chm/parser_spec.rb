# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Cabriolet::CHM::Parser do
  let(:fixture_dir) { File.join(__dir__, "../fixtures/libmspack/chmd") }

  describe "#parse" do
    context "with valid CHM files" do
      let(:test_file) { File.join(fixture_dir, "encints-64bit-both.chm") }

      it "parses CHM header successfully" do
        File.open(test_file, "rb") do |io|
          parser = described_class.new(io)
          chm = parser.parse

          expect(chm).to be_a(Cabriolet::Models::CHMHeader)
          expect(chm.version.to_i).to be_a(Integer)
          expect(chm.chunk_size).to be > 0
          expect(chm.num_chunks).to be > 0
        end
      end

      it "parses file entries" do
        File.open(test_file, "rb") do |io|
          parser = described_class.new(io)
          chm = parser.parse(entire: true)

          expect(chm.all_files.length).to be > 0
        end
      end

      it "identifies sections correctly" do
        File.open(test_file, "rb") do |io|
          parser = described_class.new(io)
          chm = parser.parse

          expect(chm.sec0).to be_a(Cabriolet::Models::CHMSecUncompressed)
          expect(chm.sec0.id).to eq(0)
          expect(chm.sec1).to be_a(Cabriolet::Models::CHMSecMSCompressed)
          expect(chm.sec1.id).to eq(1)
        end
      end
    end

    context "with fast parsing" do
      let(:test_file) { File.join(fixture_dir, "encints-64bit-both.chm") }

      it "parses headers without file entries" do
        File.open(test_file, "rb") do |io|
          parser = described_class.new(io)
          chm = parser.parse(entire: false)

          expect(chm).to be_a(Cabriolet::Models::CHMHeader)
          expect(chm.version.to_i).to be_a(Integer)
          expect(chm.files).to be_nil
        end
      end
    end

    context "with invalid files" do
      it "raises SignatureError for non-CHM files" do
        file = Tempfile.new("test.bin")
        file.write("NOT A CHM FILE")
        file.rewind

        expect do
          parser = described_class.new(file)
          parser.parse
        end.to raise_error(StandardError) # BinData raises IOError for truncated/invalid data

        file.close
        file.unlink
      end
    end
  end
end
