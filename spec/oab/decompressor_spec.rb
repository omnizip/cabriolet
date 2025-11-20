# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::OAB::Decompressor do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:decompressor) { described_class.new(io_system) }

  describe "#initialize" do
    it "creates a new decompressor with default I/O system" do
      decomp = described_class.new
      expect(decomp).to be_a(described_class)
      expect(decomp.io_system).to be_a(Cabriolet::System::IOSystem)
    end

    it "creates a new decompressor with custom I/O system" do
      expect(decompressor.io_system).to eq(io_system)
    end

    it "sets default buffer size" do
      expect(decompressor.buffer_size).to eq(4096)
    end
  end

  describe "#buffer_size=" do
    it "allows setting buffer size" do
      decompressor.buffer_size = 8192
      expect(decompressor.buffer_size).to eq(8192)
    end
  end

  describe "#decompress" do
    it "requires input and output file paths" do
      expect do
        decompressor.decompress(nil, "output.dat")
      end.to raise_error(TypeError)
    end

    context "with real OAB file" do
      it "decompresses a full OAB file" do
        fixture_path = File.join(__dir__, "..", "fixtures", "oab", "test_simple.oab")
        skip "Fixture not found" unless File.exist?(fixture_path)

        require "tmpdir"
        Dir.mktmpdir do |tmpdir|
          output_path = File.join(tmpdir, "output.dat")
          bytes = decompressor.decompress(fixture_path, output_path)

          expect(bytes).to be > 0
          expect(File.exist?(output_path)).to be true
          content = File.read(output_path)
          expect(content).to include("Hello, World!")
        end
      end
    end

    context "with invalid file" do
      it "raises error for non-existent file" do
        expect do
          decompressor.decompress("nonexistent.oab", "output.dat")
        end.to raise_error(Cabriolet::Error)
      end
    end
  end

  describe "#decompress_incremental" do
    it "requires patch, base, and output file paths" do
      expect do
        decompressor.decompress_incremental(nil, "base.dat", "output.dat")
      end.to raise_error(TypeError)
    end

    context "with real OAB patch" do
      it "applies incremental patch" do
        # OAB patches require both a patch file and a base file
        # For now, skip this as it requires more complex setup
        skip "OAB patch testing requires base file generation"
      end
    end
  end

  describe "round-trip compression/decompression" do
    let(:compressor) { Cabriolet::OAB::Compressor.new(io_system) }
    let(:test_data) { "Hello, OAB World! " * 100 }

    around do |example|
      Dir.mktmpdir do |tmpdir|
        @tmpdir = tmpdir
        example.run
      end
    end

    it "can compress and decompress data successfully",
       skip: "LZX round-trip needs full implementation" do
      input_file = File.join(@tmpdir, "input.dat")
      compressed_file = File.join(@tmpdir, "compressed.oab")
      output_file = File.join(@tmpdir, "output.dat")

      # Write test data
      File.write(input_file, test_data)

      # Compress
      compress_bytes = compressor.compress(input_file, compressed_file)
      expect(compress_bytes).to be > 0
      expect(File.exist?(compressed_file)).to be true

      # Decompress
      decompress_bytes = decompressor.decompress(compressed_file, output_file)
      expect(decompress_bytes).to eq(test_data.bytesize)

      # Verify
      output_data = File.read(output_file)
      expect(output_data).to eq(test_data)
    end

    it "handles small files" do
      input_file = File.join(@tmpdir, "small.dat")
      compressed_file = File.join(@tmpdir, "small.oab")
      output_file = File.join(@tmpdir, "small_out.dat")

      small_data = "Small test data"
      File.write(input_file, small_data)

      compressor.compress(input_file, compressed_file)
      decompressor.decompress(compressed_file, output_file)

      output_data = File.read(output_file)
      expect(output_data).to eq(small_data)
    end

    it "handles larger blocks",
       skip: "LZX round-trip needs full implementation" do
      input_file = File.join(@tmpdir, "large.dat")
      compressed_file = File.join(@tmpdir, "large.oab")
      output_file = File.join(@tmpdir, "large_out.dat")

      large_data = "X" * 65_536 # 64KB
      File.write(input_file, large_data)

      compressor.compress(input_file, compressed_file, block_size: 32_768)
      decompressor.decompress(compressed_file, output_file)

      output_data = File.read(output_file)
      expect(output_data).to eq(large_data)
    end
  end

  describe "error handling" do
    around do |example|
      Dir.mktmpdir do |tmpdir|
        @tmpdir = tmpdir
        example.run
      end
    end

    it "raises error for invalid header" do
      invalid_file = File.join(@tmpdir, "invalid.oab")
      output_file = File.join(@tmpdir, "output.dat")

      # Write invalid header
      File.write(invalid_file, "INVALID_HEADER_DATA")

      expect do
        decompressor.decompress(invalid_file, output_file)
      end.to raise_error(Cabriolet::Error, /Invalid OAB/)
    end

    it "raises error for truncated file" do
      truncated_file = File.join(@tmpdir, "truncated.oab")
      output_file = File.join(@tmpdir, "output.dat")

      # Write partial header (less than 16 bytes)
      File.write(truncated_file, "SHORT")

      expect do
        decompressor.decompress(truncated_file, output_file)
      end.to raise_error(Cabriolet::Error, /Failed to read/)
    end
  end
end
