# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::Compressors::MSZIP do
  let(:io_system) { Cabriolet::System::IOSystem.new }

  describe "#compress" do
    context "with simple text data" do
      it "compresses and decompresses correctly" do
        original = "Hello, World! This is a test."

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original)
        output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(io_system, input, output, 4096)
        compressor.compress

        # Get compressed data
        compressed = output.data

        # Verify signature present
        expect(compressed[0, 2]).to eq("CK")

        # Decompress
        compressed_input = Cabriolet::System::MemoryHandle.new(compressed)
        decompressed_output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::MSZIP.new(
          io_system, compressed_input, decompressed_output, 4096
        )
        decompressor.decompress(original.bytesize)

        # Verify
        expect(decompressed_output.data).to eq(original)
      end
    end

    context "with repetitive data" do
      it "compresses data with repeated patterns" do
        original = "abcabc" * 100

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original)
        output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(io_system, input, output, 4096)
        compressor.compress

        # Get compressed data
        compressed = output.data

        # Verify compression occurred (should be smaller)
        expect(compressed.bytesize).to be < original.bytesize

        # Decompress
        compressed_input = Cabriolet::System::MemoryHandle.new(compressed)
        decompressed_output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::MSZIP.new(
          io_system, compressed_input, decompressed_output, 4096
        )
        decompressor.decompress(original.bytesize)

        # Verify
        expect(decompressed_output.data).to eq(original)
      end
    end

    context "with binary data" do
      it "handles binary data correctly" do
        original = (0..255).to_a.pack("C*") * 10

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original)
        output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(io_system, input, output, 4096)
        compressor.compress

        # Decompress
        compressed = output.data
        compressed_input = Cabriolet::System::MemoryHandle.new(compressed)
        decompressed_output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::MSZIP.new(
          io_system, compressed_input, decompressed_output, 4096
        )
        decompressor.decompress(original.bytesize)

        # Verify
        expect(decompressed_output.data).to eq(original)
      end
    end

    context "with empty data" do
      it "handles empty input" do
        original = ""

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original)
        output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(io_system, input, output, 4096)
        compressor.compress

        # Verify at least signature written
        compressed = output.data
        expect(compressed.bytesize).to be >= 2
      end
    end

    context "with large data" do
      it "handles data larger than frame size" do
        # Create data larger than one frame (32KB)
        original = "Test data " * 5000 # ~50KB

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original)
        output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(io_system, input, output, 4096)
        compressor.compress

        # Decompress
        compressed = output.data
        compressed_input = Cabriolet::System::MemoryHandle.new(compressed)
        decompressed_output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::MSZIP.new(
          io_system, compressed_input, decompressed_output, 4096
        )
        decompressor.decompress(original.bytesize)

        # Verify
        expect(decompressed_output.data).to eq(original)
      end
    end

    context "with long matches" do
      it "handles long repeated sequences" do
        original = "A" * 1000

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original)
        output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(io_system, input, output, 4096)
        compressor.compress

        # Get compressed data
        compressed = output.data

        # Should compress well
        expect(compressed.bytesize).to be < original.bytesize / 2

        # Decompress
        compressed_input = Cabriolet::System::MemoryHandle.new(compressed)
        decompressed_output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::MSZIP.new(
          io_system, compressed_input, decompressed_output, 4096
        )
        decompressor.decompress(original.bytesize)

        # Verify
        expect(decompressed_output.data).to eq(original)
      end
    end

    context "with various data patterns" do
      it "handles mixed literal and match data" do
        original = "The quick brown fox jumps over the lazy dog. " * 50

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original)
        output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(io_system, input, output, 4096)
        compressor.compress

        # Decompress
        compressed = output.data
        compressed_input = Cabriolet::System::MemoryHandle.new(compressed)
        decompressed_output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::MSZIP.new(
          io_system, compressed_input, decompressed_output, 4096
        )
        decompressor.decompress(original.bytesize)

        # Verify
        expect(decompressed_output.data).to eq(original)
      end
    end
  end

  describe "signature writing" do
    it "writes CK signature at the start of each block" do
      original = "Test"

      input = Cabriolet::System::MemoryHandle.new(original)
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
      compressor = described_class.new(io_system, input, output, 4096)
      compressor.compress

      compressed = output.data

      # First two bytes should be 'CK'
      expect(compressed[0].ord).to eq(0x43) # 'C'
      expect(compressed[1].ord).to eq(0x4B) # 'K'
    end
  end
end
