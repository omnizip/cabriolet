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
      # Create a minimal LIT file with encryption flag set
      header_data = [
        0x49, 0x54, 0x4F, 0x4C, 0x49, 0x54, 0x4C, 0x53, # Signature: "ITOLITLS"
        0x01, 0x00, 0x00, 0x00,                         # Version: 1
        0x01, 0x00, 0x00, 0x00,                         # Flags: encrypted
        0x00, 0x00, 0x00, 0x00,                         # File count: 0
        0x18, 0x00, 0x00, 0x00                          # Header size: 24
      ].pack("C*")

      Dir.mktmpdir do |dir|
        file_path = File.join(dir, "test.lit")
        File.binwrite(file_path, header_data)

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
      header = Cabriolet::Models::LITHeader.new
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
      header = Cabriolet::Models::LITHeader.new
      expect { decompressor.extract(header, nil, "output.txt") }.to raise_error(
        ArgumentError,
        /File must not be nil/,
      )
    end

    it "raises error when output path is nil" do
      header = Cabriolet::Models::LITHeader.new
      file = Cabriolet::Models::LITFile.new
      expect { decompressor.extract(header, file, nil) }.to raise_error(
        ArgumentError,
        /Output path must not be nil/,
      )
    end

    it "raises NotImplementedError for encrypted files" do
      header = Cabriolet::Models::LITHeader.new
      header.filename = "test.lit"

      file = Cabriolet::Models::LITFile.new
      file.encrypted = true

      expect do
        decompressor.extract(header, file, "output.txt")
      end.to raise_error(
        NotImplementedError,
        /DES-encrypted files not yet supported/,
      )
    end

    it "extracts a real LIT file", skip: "No LIT test fixtures available" do
      # Would test extraction if we had real LIT files
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
      header = Cabriolet::Models::LITHeader.new
      expect { decompressor.extract_all(header, nil) }.to raise_error(
        ArgumentError,
        /Output dir must not be nil/,
      )
    end

    it "extracts all files from archive",
       skip: "No LIT test fixtures available" do
      # Would test extraction if we had real LIT files
    end
  end
end
