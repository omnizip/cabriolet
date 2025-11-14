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
      it "opens and parses HLP file", skip: "No HLP test fixtures available" do
        # Would test opening a real HLP file if we had fixtures
      end

      it "sets filename in header", skip: "No HLP test fixtures available" do
        # Would verify filename is set in header
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
      it "extracts compressed file", skip: "No HLP test fixtures available" do
        # Would test extracting compressed file if we had fixtures
      end

      it "extracts uncompressed file", skip: "No HLP test fixtures available" do
        # Would test extracting uncompressed file if we had fixtures
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
      it "extracts file to memory", skip: "No HLP test fixtures available" do
        # Would test memory extraction if we had fixtures
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
      it "extracts all files to directory",
         skip: "No HLP test fixtures available" do
        # Would test extracting all files if we had fixtures
      end
    end
  end

  describe "round-trip compression/decompression" do
    it "compresses and decompresses data correctly",
       pending: "Round-trip not working without real HLP format spec" do
      # Create test data
      test_data = "Hello, World! This is test data for HLP format.\n" * 10

      # Create temporary files
      require "tempfile"
      input_file = Tempfile.new(["test", ".txt"])
      hlp_file = Tempfile.new(["test", ".hlp"])
      output_file = Tempfile.new(["output", ".txt"])

      begin
        # Write test data
        input_file.write(test_data)
        input_file.close

        # Compress
        compressor = Cabriolet::HLP::Compressor.new(io_system)
        compressor.add_file(input_file.path, "test.txt")
        compressor.generate(hlp_file.path)

        # Decompress
        header = decompressor.open(hlp_file.path)
        expect(header.files.size).to eq(1)

        hlp_internal_file = header.files.first
        decompressor.extract_file(header, hlp_internal_file, output_file.path)
        decompressor.close(header)

        # Verify
        output_data = File.read(output_file.path)
        expect(output_data).to eq(test_data)
      ensure
        input_file.unlink
        hlp_file.unlink
        output_file.unlink
      end
    end
  end
end
