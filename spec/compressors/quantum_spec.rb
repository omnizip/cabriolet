# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::Compressors::Quantum do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:buffer_size) { 4096 }

  describe "#initialize" do
    it "initializes with valid window bits" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
      compressor = described_class.new(io_system, input, output, buffer_size,
                                       window_bits: 10)
      expect(compressor.window_bits).to eq(10)
      expect(compressor.window_size).to eq(1024)
    end

    it "raises error for invalid window bits" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)

      expect do
        described_class.new(io_system, input, output, buffer_size,
                            window_bits: 9)
      end.to raise_error(ArgumentError, /Quantum window_bits must be 10-21/)

      expect do
        described_class.new(io_system, input, output, buffer_size,
                            window_bits: 22)
      end.to raise_error(ArgumentError, /Quantum window_bits must be 10-21/)
    end
  end

  # Quantum compression implementation status:
  # - Literals: WORKING
  # - Short matches (3-4 bytes): WORKING
  # - Variable matches (5-13 bytes): WORKING
  # - Longer matches (14+ bytes): Has known issues
  #
  # NOTE: Full Quantum compression round-trip is experimental.
  # Some complex patterns have known encoding issues.
  describe "#compress" do
    def compress_and_decompress(data, window_bits: 10)
      # Compress
      input = Cabriolet::System::MemoryHandle.new(data)
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
      compressor = described_class.new(io_system, input, output, buffer_size,
                                       window_bits: window_bits)
      compressor.compress

      # Get compressed data
      compressed = output.data

      # Decompress
      compressed_input = Cabriolet::System::MemoryHandle.new(compressed)
      decompressed_output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
      decompressor = Cabriolet::Decompressors::Quantum.new(
        io_system, compressed_input, decompressed_output, buffer_size, window_bits: window_bits
      )
      decompressor.decompress(data.bytesize)

      # Return decompressed data
      decompressed_output.data
    end

    context "with simple data" do
      it "handles empty data" do
        original = ""
        decompressed = compress_and_decompress(original)
        expect(decompressed).to eq(original)
      end
    end

    context "with different byte patterns" do
      it "handles all byte values 0-255" do
        # High entropy data - literals only, no matches
        original = (0..255).to_a.pack("C*")
        decompressed = compress_and_decompress(original)
        expect(decompressed).to eq(original)
      end
    end
  end
end
