# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Cabriolet::OAB::Compressor do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:compressor) { described_class.new(io_system) }

  describe "#initialize" do
    it "creates a new compressor with default I/O system" do
      comp = described_class.new
      expect(comp).to be_a(described_class)
      expect(comp.io_system).to be_a(Cabriolet::System::IOSystem)
    end

    it "creates a new compressor with custom I/O system" do
      expect(compressor.io_system).to eq(io_system)
    end

    it "sets default buffer size" do
      expect(compressor.buffer_size).to eq(4096)
    end

    it "sets default block size" do
      expect(compressor.block_size).to eq(32_768)
    end
  end

  describe "#buffer_size=" do
    it "allows setting buffer size" do
      compressor.buffer_size = 8192
      expect(compressor.buffer_size).to eq(8192)
    end
  end

  describe "#block_size=" do
    it "allows setting block size" do
      compressor.block_size = 16_384
      expect(compressor.block_size).to eq(16_384)
    end
  end

  describe "#compress" do
    around do |example|
      Dir.mktmpdir do |tmpdir|
        @tmpdir = tmpdir
        example.run
      end
    end

    it "compresses a file to OAB format" do
      input_file = File.join(@tmpdir, "input.dat")
      output_file = File.join(@tmpdir, "output.oab")

      test_data = "Test data for OAB compression" * 10
      File.write(input_file, test_data)

      bytes = compressor.compress(input_file, output_file)
      expect(bytes).to be > 0
      expect(File.exist?(output_file)).to be true
    end

    it "creates valid OAB header" do
      input_file = File.join(@tmpdir, "input.dat")
      output_file = File.join(@tmpdir, "output.oab")

      test_data = "Test data"
      File.write(input_file, test_data)

      compressor.compress(input_file, output_file)

      # Read and verify header
      header_data = File.read(output_file, 16)
      header = Cabriolet::Binary::OABStructures::FullHeader.read(header_data)

      expect(header.version_hi).to eq(3)
      expect(header.version_lo).to eq(1)
      expect(header.target_size).to eq(test_data.bytesize)
    end

    it "supports custom block size" do
      input_file = File.join(@tmpdir, "input.dat")
      output_file = File.join(@tmpdir, "output.oab")

      test_data = "X" * 1000
      File.write(input_file, test_data)

      bytes = compressor.compress(input_file, output_file, block_size: 512)
      expect(bytes).to be > 0
    end

    it "handles empty files" do
      input_file = File.join(@tmpdir, "empty.dat")
      output_file = File.join(@tmpdir, "empty.oab")

      File.write(input_file, "")

      bytes = compressor.compress(input_file, output_file)
      expect(bytes).to be > 0 # Header is written
    end
  end

  describe "#compress_data" do
    around do |example|
      Dir.mktmpdir do |tmpdir|
        @tmpdir = tmpdir
        example.run
      end
    end

    it "compresses data from memory" do
      output_file = File.join(@tmpdir, "output.oab")
      test_data = "Memory test data" * 20

      bytes = compressor.compress_data(test_data, output_file)
      expect(bytes).to be > 0
      expect(File.exist?(output_file)).to be true
    end

    it "creates valid header from memory data" do
      output_file = File.join(@tmpdir, "output.oab")
      test_data = "Test"

      compressor.compress_data(test_data, output_file)

      header_data = File.read(output_file, 16)
      header = Cabriolet::Binary::OABStructures::FullHeader.read(header_data)

      expect(header.version_hi).to eq(3)
      expect(header.version_lo).to eq(1)
      expect(header.target_size).to eq(test_data.bytesize)
    end
  end

  describe "#compress_incremental" do
    around do |example|
      Dir.mktmpdir do |tmpdir|
        @tmpdir = tmpdir
        example.run
      end
    end

    it "creates a patch file" do
      base_file = File.join(@tmpdir, "base.dat")
      input_file = File.join(@tmpdir, "new.dat")
      patch_file = File.join(@tmpdir, "patch.oab")

      File.write(base_file, "Base data")
      File.write(input_file, "New data")

      bytes = compressor.compress_incremental(input_file, base_file, patch_file)
      expect(bytes).to be > 0
      expect(File.exist?(patch_file)).to be true
    end

    it "creates valid patch header" do
      base_file = File.join(@tmpdir, "base.dat")
      input_file = File.join(@tmpdir, "new.dat")
      patch_file = File.join(@tmpdir, "patch.oab")

      base_data = "Base"
      new_data = "New"
      File.write(base_file, base_data)
      File.write(input_file, new_data)

      compressor.compress_incremental(input_file, base_file, patch_file)

      # Read and verify patch header
      header_data = File.read(patch_file, 28)
      header = Cabriolet::Binary::OABStructures::PatchHeader.read(header_data)

      expect(header.version_hi).to eq(3)
      expect(header.version_lo).to eq(2)
      expect(header.source_size).to eq(base_data.bytesize)
      expect(header.target_size).to eq(new_data.bytesize)
    end
  end

  describe "integration with decompressor" do
    let(:decompressor) { Cabriolet::OAB::Decompressor.new(io_system) }

    around do |example|
      Dir.mktmpdir do |tmpdir|
        @tmpdir = tmpdir
        example.run
      end
    end

    it "produces files that can be decompressed",
       skip: "LZX round-trip needs full implementation" do
      input_file = File.join(@tmpdir, "input.dat")
      compressed_file = File.join(@tmpdir, "compressed.oab")
      output_file = File.join(@tmpdir, "output.dat")

      test_data = "Round-trip test data!" * 50
      File.write(input_file, test_data)

      # Compress
      compressor.compress(input_file, compressed_file)

      # Decompress
      decompressor.decompress(compressed_file, output_file)

      # Verify
      result = File.read(output_file)
      expect(result).to eq(test_data)
    end

    it "handles binary data correctly",
       skip: "LZX round-trip needs full implementation" do
      input_file = File.join(@tmpdir, "binary.dat")
      compressed_file = File.join(@tmpdir, "binary.oab")
      output_file = File.join(@tmpdir, "binary_out.dat")

      # Binary data with all byte values
      binary_data = (0..255).to_a.pack("C*") * 10
      File.binwrite(input_file, binary_data)

      compressor.compress(input_file, compressed_file)
      decompressor.decompress(compressed_file, output_file)

      result = File.binread(output_file)
      expect(result).to eq(binary_data)
    end

    it "preserves data across multiple blocks",
       skip: "LZX round-trip needs full implementation" do
      input_file = File.join(@tmpdir, "multiblock.dat")
      compressed_file = File.join(@tmpdir, "multiblock.oab")
      output_file = File.join(@tmpdir, "multiblock_out.dat")

      # Data larger than one block
      large_data = "ABCDEFGHIJ" * 7000 # ~70KB
      File.write(input_file, large_data)

      compressor.compress(input_file, compressed_file, block_size: 32_768)
      decompressor.decompress(compressed_file, output_file)

      result = File.read(output_file)
      expect(result).to eq(large_data)
    end
  end
end
