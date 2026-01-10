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

    # NOTE: Incremental patch testing requires base file generation
    # This is a complex feature that depends on LZX VERBATIM implementation
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

    # NOTE: LZX round-trip tests depend on LZX VERBATIM implementation
    # which is incomplete in cabriolet (uses UNCOMPRESSED blocks only)

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

    # NOTE: Larger block tests depend on LZX VERBATIM implementation
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
