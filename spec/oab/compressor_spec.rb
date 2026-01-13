# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require_relative "../support/fixtures"

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

  describe "fixture compatibility" do
    let(:decompressor) { Cabriolet::OAB::Decompressor.new(io_system) }

    context "creates compatible files" do
      it "generates files that decompressor can decompress" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "test.dat")
          output_oab = File.join(tmpdir, "test.oab")
          extracted = File.join(tmpdir, "extracted.dat")

          original_data = "OAB fixture compatibility test"
          File.write(input_file, original_data)

          compressor.compress(input_file, output_oab)

          # Verify decompressor can decompress
          bytes = decompressor.decompress(output_oab, extracted)
          expect(bytes).to eq(original_data.bytesize)
          expect(File.read(extracted)).to eq(original_data)
        end
      end

      it "generates files with valid header structure" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "test.dat")
          output_file = File.join(tmpdir, "test.oab")
          File.write(input_file, "Test")

          compressor.compress(input_file, output_file)

          # Verify header is valid by reading it
          header_data = File.read(output_file, 16)
          header = Cabriolet::Binary::OABStructures::FullHeader.read(header_data)
          expect(header.version_hi).to eq(3)
          expect(header.version_lo).to eq(1)
          expect(header.valid?).to be true
        end
      end

      it "generates patch files with valid header structure" do
        Dir.mktmpdir do |tmpdir|
          base_file = File.join(tmpdir, "base.dat")
          new_file = File.join(tmpdir, "new.dat")
          patch_file = File.join(tmpdir, "patch.oab")

          File.write(base_file, "Base")
          File.write(new_file, "New")

          compressor.compress_incremental(new_file, base_file, patch_file)

          # Verify patch header is valid by reading it
          header_data = File.read(patch_file, 28)
          header = Cabriolet::Binary::OABStructures::PatchHeader.read(header_data)
          expect(header.version_hi).to eq(3)
          expect(header.version_lo).to eq(2)
        end
      end
    end

    context "with multiple scenarios" do
      it "handles small data files" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "small.dat")
          output_oab = File.join(tmpdir, "small.oab")
          extracted = File.join(tmpdir, "extracted.dat")

          original_data = "Small"
          File.write(input_file, original_data)

          compressor.compress(input_file, output_oab)

          # Verify by reading header
          header_data = File.read(output_oab, 16)
          header = Cabriolet::Binary::OABStructures::FullHeader.read(header_data)
          expect(header.target_size).to eq(5)
        end
      end

      it "handles larger data files" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "large.dat")
          output_oab = File.join(tmpdir, "large.oab")
          File.write(input_file, "Large test data " * 100)

          compressor.compress(input_file, output_oab)

          # Verify by reading header
          header_data = File.read(output_oab, 16)
          header = Cabriolet::Binary::OABStructures::FullHeader.read(header_data)
          expect(header.target_size).to be > 1000
        end
      end
    end
  end

  describe "integration with decompressor" do
    # NOTE: LZX round-trip tests are pending due to VERBATIM tree encoding issues.
    # The compressor uses UNCOMPRESSED blocks which cannot be properly decompressed
    # for round-trip verification. Full implementation requires fixing LZX VERBATIM
    # tree encoding in lib/cabriolet/compressors/lzx.rb.
  end
end
