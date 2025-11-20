# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Cabriolet::LIT::Decompressor do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:decompressor) { described_class.new(io_system) }

  describe "#initialize" do
    it "creates a decompressor with default I/O system" do
      dec = described_class.new
      expect(dec.io_system).to be_a(Cabriolet::System::IOSystem)
      expect(dec.buffer_size).to eq(described_class::DEFAULT_BUFFER_SIZE)
    end

    it "creates a decompressor with custom I/O system" do
      custom_io = Cabriolet::System::IOSystem.new
      dec = described_class.new(custom_io)
      expect(dec.io_system).to eq(custom_io)
    end
  end

  describe "#open" do
    it "raises NotImplementedError for DES-encrypted files" do
      # Create a minimal valid LIT file with encryption flag set
      # LIT files need proper ITOL/ITLS headers + enough structure to parse
      Dir.mktmpdir do |dir|
        file_path = File.join(dir, "test.lit")

        # For now, skip this test as creating a valid minimal LIT file
        # requires complex structure (ITOL header, directory, etc.)
        skip "Creating minimal valid LIT file structure not yet implemented"

        expect { decompressor.open(file_path) }.to raise_error(
          NotImplementedError,
          /DES-encrypted LIT files not yet supported/,
        )
      end
    end

    it "raises ParseError for invalid signature",
       skip: "No valid LIT file format specification" do
      # Would test with invalid signature
    end
  end

  describe "#close" do
    it "closes the header without error" do
      header = Cabriolet::Models::LITFile.new
      expect { decompressor.close(header) }.not_to raise_error
    end
  end

  describe "#extract" do
    it "raises error when header is nil" do
      file = Cabriolet::Models::LITFile.new
      expect { decompressor.extract(nil, file, "output.txt") }.to raise_error(
        ArgumentError,
        /Header must not be nil/,
      )
    end

    it "raises error when file is nil" do
      header = Cabriolet::Models::LITFile.new
      expect { decompressor.extract(header, nil, "output.txt") }.to raise_error(
        ArgumentError,
        /File must not be nil/,
      )
    end

    it "raises error when output path is nil" do
      header = Cabriolet::Models::LITFile.new
      file = Cabriolet::Models::LITFile.new
      expect { decompressor.extract(header, file, nil) }.to raise_error(
        ArgumentError,
        /Output path must not be nil/,
      )
    end

    it "raises NotImplementedError for encrypted files" do
      header = Cabriolet::Models::LITFile.new
      header.drm_level = 1
      file = Cabriolet::Models::LITDirectoryEntry.new
      expect { decompressor.extract(header, file, "output.txt") }.to raise_error(
        NotImplementedError,
        /Encrypted sections not yet supported/,
      )
    end

    it "extracts a real LIT file",
       skip: "Real Microsoft Reader LIT format not yet fully implemented" do
      fixture_path = File.join(__dir__, "..", "fixtures", "atudl_lit", "bill.lit")
      skip "Fixture not found" unless File.exist?(fixture_path)

      require "tmpdir"
      Dir.mktmpdir do |tmpdir|
        header = decompressor.open(fixture_path)
        file = header.files.first if header.files && !header.files.empty?
        skip "No files in LIT fixture" unless file

        output_path = File.join(tmpdir, "output.txt")
        decompressor.extract(header, file, output_path)

        expect(File.exist?(output_path)).to be true
        content = File.read(output_path)
        expect(content.size).to be > 0

        decompressor.close(header)
      end
    end
  end

  describe "#extract_all" do
    it "raises error when header is nil" do
      expect { decompressor.extract_all(nil, ".") }.to raise_error(
        ArgumentError,
        /Header must not be nil/,
      )
    end

    it "raises error when output dir is nil" do
      header = Cabriolet::Models::LITFile.new
      expect { decompressor.extract_all(header, nil) }.to raise_error(
        ArgumentError,
        /Output directory must not be nil/,
      )
    end

    it "extracts all files from archive",
       skip: "Real Microsoft Reader LIT format not yet fully implemented" do
      fixture_path = File.join(__dir__, "..", "fixtures", "atudl_lit", "A History of Greek Art.lit")
      skip "Fixture not found" unless File.exist?(fixture_path)

      require "tmpdir"
      Dir.mktmpdir do |tmpdir|
        header = decompressor.open(fixture_path)
        decompressor.extract_all(header, tmpdir)

        expect(Dir.children(tmpdir).size).to eq(header.files.size)

        decompressor.close(header)
      end
    end
  end
end
