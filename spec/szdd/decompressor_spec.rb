# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Cabriolet::SZDD::Decompressor do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:decompressor) { described_class.new(io_system) }

  describe "#initialize" do
    it "creates a decompressor with default I/O system" do
      dec = described_class.new
      expect(dec.io_system).to be_a(Cabriolet::System::IOSystem)
      expect(dec.parser).to be_a(Cabriolet::SZDD::Parser)
      expect(dec.buffer_size).to eq(described_class::DEFAULT_BUFFER_SIZE)
    end

    it "creates a decompressor with custom I/O system" do
      custom_io = Cabriolet::System::IOSystem.new
      dec = described_class.new(custom_io)
      expect(dec.io_system).to eq(custom_io)
    end
  end

  describe "#open" do
    it "opens and parses an SZDD file" do
      # Create a minimal NORMAL format SZDD file
      data = [
        0x53, 0x5A, 0x44, 0x44, 0x88, 0xF0, 0x27, 0x33,
        0x41,
        0x74,
        0x0A, 0x00, 0x00, 0x00
      ].pack("C*")

      Dir.mktmpdir do |dir|
        file_path = File.join(dir, "test.tx_")
        File.binwrite(file_path, data)

        header = decompressor.open(file_path)

        expect(header).to be_a(Cabriolet::Models::SZDDHeader)
        expect(header.format).to eq(Cabriolet::Models::SZDDHeader::FORMAT_NORMAL)
        expect(header.length).to eq(10)
        expect(header.missing_char).to eq("t")
        expect(header.filename).to eq(file_path)
      end
    end
  end

  describe "#close" do
    it "closes the header without error" do
      header = Cabriolet::Models::SZDDHeader.new
      expect { decompressor.close(header) }.not_to raise_error
    end
  end

  describe "#extract" do
    it "extracts NORMAL format SZDD file using LZSS decompression" do
      # Create SZDD header + simple LZSS compressed data
      # For simplicity, use literal bytes (control byte with all bits set)
      header_data = [
        0x53, 0x5A, 0x44, 0x44, 0x88, 0xF0, 0x27, 0x33, # Signature
        0x41,                                           # Compression mode
        0x74,                                           # Missing char
        0x05, 0x00, 0x00, 0x00                          # Size: 5 bytes
      ].pack("C*")

      # LZSS compressed data: control byte 0xFF (all literals) + 5 bytes
      compressed_data = [
        0xFF,                          # Control: 8 literals
        0x48, 0x65, 0x6C, 0x6C, 0x6F   # "Hello"
      ].pack("C*")

      Dir.mktmpdir do |dir|
        input_path = File.join(dir, "test.tx_")
        output_path = File.join(dir, "test.txt")

        File.binwrite(input_path, header_data + compressed_data)

        header = decompressor.open(input_path)
        bytes = decompressor.extract(header, output_path)

        expect(bytes).to eq(5)
        expect(File.exist?(output_path)).to be true
        expect(File.binread(output_path)).to eq("Hello")

        decompressor.close(header)
      end
    end

    it "raises error when header is nil" do
      expect { decompressor.extract(nil, "output.txt") }.to raise_error(
        ArgumentError,
        /Header must not be nil/,
      )
    end

    it "raises error when output path is nil" do
      header = Cabriolet::Models::SZDDHeader.new
      expect { decompressor.extract(header, nil) }.to raise_error(
        ArgumentError,
        /Output path must not be nil/,
      )
    end
  end

  describe "#decompress" do
    it "decompresses in one shot with auto-detected output name" do
      # Create test SZDD file
      header_data = [
        0x53, 0x5A, 0x44, 0x44, 0x88, 0xF0, 0x27, 0x33,
        0x41,
        0x74,
        0x04, 0x00, 0x00, 0x00
      ].pack("C*")

      compressed_data = [
        0xFF,
        0x54, 0x65, 0x73, 0x74 # "Test"
      ].pack("C*")

      Dir.mktmpdir do |dir|
        input_path = File.join(dir, "file.tx_")
        File.binwrite(input_path, header_data + compressed_data)

        # Call decompress without output path
        bytes = decompressor.decompress(input_path)

        expect(bytes).to eq(4)

        # Check auto-detected output file was created
        output_path = File.join(dir, "file.txt")
        expect(File.exist?(output_path)).to be true
        expect(File.binread(output_path)).to eq("Test")
      end
    end

    it "decompresses with explicit output path" do
      header_data = [
        0x53, 0x5A, 0x44, 0x44, 0x88, 0xF0, 0x27, 0x33,
        0x41,
        0x78,
        0x03, 0x00, 0x00, 0x00
      ].pack("C*")

      compressed_data = [
        0xFF,
        0x46, 0x6F, 0x6F # "Foo"
      ].pack("C*")

      Dir.mktmpdir do |dir|
        input_path = File.join(dir, "test.dl_")
        output_path = File.join(dir, "custom.dll")

        File.binwrite(input_path, header_data + compressed_data)

        bytes = decompressor.decompress(input_path, output_path)

        expect(bytes).to eq(3)
        expect(File.binread(output_path)).to eq("Foo")
      end
    end
  end

  describe "#auto_output_filename" do
    it "generates output filename by replacing underscore" do
      header = Cabriolet::Models::SZDDHeader.new(
        missing_char: "t",
      )

      result = decompressor.auto_output_filename("dir/file.tx_", header)
      expect(result).to eq("dir/file.txT")
    end

    it "preserves directory path" do
      header = Cabriolet::Models::SZDDHeader.new(
        missing_char: "l",
      )

      result = decompressor.auto_output_filename("/path/to/setup.dl_", header)
      expect(result).to eq("/path/to/setup.dlL")
    end

    it "handles relative paths" do
      header = Cabriolet::Models::SZDDHeader.new(
        missing_char: "e",
      )

      result = decompressor.auto_output_filename("../docs/readme.tx_", header)
      expect(result).to eq("../docs/readme.txE")
    end
  end
end
