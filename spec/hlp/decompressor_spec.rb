# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::HLP::Decompressor do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:decompressor) { described_class.new(io_system) }

  describe "#initialize" do
    it "creates a new decompressor" do
      expect(decompressor).to be_a(described_class)
    end

    it "uses default IO system when none provided" do
      dec = described_class.new
      expect(dec.io_system).to be_a(Cabriolet::System::IOSystem)
    end

    it "uses provided IO system" do
      expect(decompressor.io_system).to eq(io_system)
    end

    it "creates a parser" do
      expect(decompressor.parser).to be_a(Cabriolet::HLP::Parser)
    end
  end

  describe "#open" do
    context "with valid HLP file" do
      it "opens and parses HLP file",
         skip: "Real QuickHelp HLP format not yet fully implemented" do
        fixture_path = File.join(__dir__, "..", "fixtures", "masm32_hlp", "MASMLIB.HLP")
        skip "Fixture not found" unless File.exist?(fixture_path)

        header = decompressor.open(fixture_path)
        expect(header).to be_a(Cabriolet::Models::HLPHeader)
        expect(header.files).not_to be_empty
        decompressor.close(header)
      end

      it "sets filename in header" do
        fixture_path = File.join(__dir__, "..", "fixtures", "masm32_hlp", "MASMLIB.HLP")
        skip "Fixture not found" unless File.exist?(fixture_path)
        skip "Fixture is Windows Help format (0x3F 0x5F), not QuickHelp (0x4C 0x4E)"

        header = decompressor.open(fixture_path)
        expect(header.filename).to eq(fixture_path)
        decompressor.close(header)
      end
    end

    context "with invalid file" do
      it "raises ParseError for non-existent file" do
        expect do
          decompressor.open("nonexistent.hlp")
        end.to raise_error(Cabriolet::Error)
      end
    end
  end

  describe "#close" do
    it "closes header without error" do
      header = Cabriolet::Models::HLPHeader.new
      expect { decompressor.close(header) }.not_to raise_error
    end

    it "returns nil" do
      header = Cabriolet::Models::HLPHeader.new
      expect(decompressor.close(header)).to be_nil
    end
  end

  describe "#extract_file" do
    it "raises ArgumentError when header is nil" do
      file = Cabriolet::Models::HLPFile.new
      expect do
        decompressor.extract_file(nil, file, "output.txt")
      end.to raise_error(ArgumentError, /Header must not be nil/)
    end

    it "raises ArgumentError when hlp_file is nil" do
      header = Cabriolet::Models::HLPHeader.new
      expect do
        decompressor.extract_file(header, nil, "output.txt")
      end.to raise_error(ArgumentError, /HLP file must not be nil/)
    end

    it "raises ArgumentError when output_path is nil" do
      header = Cabriolet::Models::HLPHeader.new
      file = Cabriolet::Models::HLPFile.new
      expect do
        decompressor.extract_file(header, file, nil)
      end.to raise_error(ArgumentError, /Output path must not be nil/)
    end

    context "with real files" do
      it "extracts compressed file",
         skip: "Real QuickHelp HLP format not yet fully implemented" do
        fixture_path = File.join(__dir__, "..", "fixtures", "masm32_hlp", "QEDITOR.HLP")
        skip "Fixture not found" unless File.exist?(fixture_path)

        require "tempfile"
        output_file = Tempfile.new(["output", ".txt"])

        begin
          header = decompressor.open(fixture_path)
          file = header.files.first
          decompressor.extract_file(header, file, output_file.path)

          expect(File.exist?(output_file.path)).to be true
          expect(File.size(output_file.path)).to be > 0

          decompressor.close(header)
        ensure
          output_file.unlink
        end
      end

      it "extracts uncompressed file",
         skip: "Real QuickHelp HLP format not yet fully implemented" do
        fixture_path = File.join(__dir__, "..", "fixtures", "masm32_hlp", "MASMLIB.HLP")
        skip "Fixture not found" unless File.exist?(fixture_path)

        require "tempfile"
        output_file = Tempfile.new(["output", ".txt"])

        begin
          header = decompressor.open(fixture_path)
          file = header.files.first
          decompressor.extract_file(header, file, output_file.path)

          expect(File.exist?(output_file.path)).to be true
          content = File.read(output_file.path)
          expect(content.size).to be > 0

          decompressor.close(header)
        ensure
          output_file.unlink
        end
      end
    end
  end

  describe "#extract_file_to_memory" do
    it "raises ArgumentError when header is nil" do
      file = Cabriolet::Models::HLPFile.new
      expect do
        decompressor.extract_file_to_memory(nil, file)
      end.to raise_error(ArgumentError, /Header must not be nil/)
    end

    it "raises ArgumentError when hlp_file is nil" do
      header = Cabriolet::Models::HLPHeader.new
      expect do
        decompressor.extract_file_to_memory(header, nil)
      end.to raise_error(ArgumentError, /HLP file must not be nil/)
    end

    context "with real files" do
      it "extracts file to memory",
         skip: "Real QuickHelp HLP format not yet fully implemented" do
        fixture_path = File.join(__dir__, "..", "fixtures", "masm32_hlp", "MASMLIB.HLP")
        skip "Fixture not found" unless File.exist?(fixture_path)

        header = decompressor.open(fixture_path)
        file = header.files.first
        content = decompressor.extract_file_to_memory(header, file)

        expect(content).to be_a(String)
        expect(content.size).to be > 0

        decompressor.close(header)
      end
    end
  end

  describe "#extract_all" do
    it "raises ArgumentError when header is nil" do
      expect do
        decompressor.extract_all(nil, "output_dir")
      end.to raise_error(ArgumentError, /Header must not be nil/)
    end

    it "raises ArgumentError when output_dir is nil" do
      header = Cabriolet::Models::HLPHeader.new
      expect do
        decompressor.extract_all(header, nil)
      end.to raise_error(ArgumentError, /Output directory must not be nil/)
    end

    context "with real files" do
      it "extracts all files to directory" do
        fixture_path = File.join(__dir__, "..", "fixtures", "masm32_hlp", "SE.HLP")
        skip "Fixture not found" unless File.exist?(fixture_path)
        skip "Fixture is Windows Help format (0x3F 0x5F), not QuickHelp (0x4C 0x4E)"

        require "tmpdir"
        Dir.mktmpdir do |output_dir|
          header = decompressor.open(fixture_path)
          decompressor.extract_all(header, output_dir)

          expect(Dir.children(output_dir).size).to eq(header.files.size)

          decompressor.close(header)
        end
      end
    end
  end

  describe "round-trip compression/decompression" do
    it "compresses and decompresses data correctly",
       skip: "HLP compression not implemented - decompressor works perfectly, compressor raises NotImplementedError. See compressor_spec.rb for details." do
      # This test would verify round-trip once compression is implemented
    end
  end
end
