# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::Decompressors::MSZIP do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:buffer_size) { 4096 }

  describe "#initialize" do
    it "initializes with required parameters" do
      input = Cabriolet::System::MemoryHandle.new("test data")
      output = Cabriolet::System::MemoryHandle.new("")

      decompressor = described_class.new(io_system, input, output, buffer_size)

      expect(decompressor).to be_a(described_class)
      expect(decompressor.io_system).to eq(io_system)
      expect(decompressor.input).to eq(input)
      expect(decompressor.output).to eq(output)
      expect(decompressor.buffer_size).to eq(buffer_size)
    end

    it "accepts fix_mszip option" do
      input = Cabriolet::System::MemoryHandle.new("test data")
      output = Cabriolet::System::MemoryHandle.new("")

      decompressor = described_class.new(
        io_system, input, output, buffer_size, fix_mszip: true
      )

      expect(decompressor).to be_a(described_class)
    end
  end

  describe "constants" do
    it "defines FRAME_SIZE as 32768" do
      expect(described_class::FRAME_SIZE).to eq(32_768)
    end

    it "defines LITERAL_MAXSYMBOLS as 288" do
      expect(described_class::LITERAL_MAXSYMBOLS).to eq(288)
    end

    it "defines DISTANCE_MAXSYMBOLS as 32" do
      expect(described_class::DISTANCE_MAXSYMBOLS).to eq(32)
    end

    it "defines LITERAL_TABLEBITS as 9" do
      expect(described_class::LITERAL_TABLEBITS).to eq(9)
    end

    it "defines DISTANCE_TABLEBITS as 6" do
      expect(described_class::DISTANCE_TABLEBITS).to eq(6)
    end
  end

  describe "lookup tables" do
    it "defines LIT_LENGTHS with 29 elements" do
      expect(described_class::LIT_LENGTHS.size).to eq(29)
      expect(described_class::LIT_LENGTHS.first).to eq(3)
      expect(described_class::LIT_LENGTHS.last).to eq(258)
    end

    it "defines DIST_OFFSETS with 30 elements" do
      expect(described_class::DIST_OFFSETS.size).to eq(30)
      expect(described_class::DIST_OFFSETS.first).to eq(1)
      expect(described_class::DIST_OFFSETS.last).to eq(24_577)
    end

    it "defines LIT_EXTRABITS with 29 elements" do
      expect(described_class::LIT_EXTRABITS.size).to eq(29)
      described_class::LIT_EXTRABITS.each do |bits|
        expect(bits).to be >= 0
        expect(bits).to be <= 5
      end
    end

    it "defines DIST_EXTRABITS with 30 elements" do
      expect(described_class::DIST_EXTRABITS.size).to eq(30)
      described_class::DIST_EXTRABITS.each do |bits|
        expect(bits).to be >= 0
        expect(bits).to be <= 13
      end
    end

    it "defines BITLEN_ORDER with 19 elements" do
      expect(described_class::BITLEN_ORDER.size).to eq(19)
      expect(described_class::BITLEN_ORDER).to include(0, 1, 2, 3, 4, 5, 6, 7,
                                                       8)
    end
  end

  describe "#decompress" do
    context "with simple stored block" do
      it "decompresses uncompressed data" do
        # Create a simple stored block with CK signature
        # CK + final block flag (1) + block type (00) + length (5, little-endian) + complement + data
        compressed = [
          0x43, 0x4B,           # CK signature
          0x01,                 # final block, type 0 (stored)
          0x05, 0x00,           # length = 5
          0xFA, 0xFF,           # complement = ~5
          0x48, 0x65, 0x6C, 0x6C, 0x6F # "Hello"
        ].pack("C*")

        input = Cabriolet::System::MemoryHandle.new(compressed, Cabriolet::Constants::MODE_READ)
        output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        decompressor = described_class.new(io_system, input, output,
                                           buffer_size)

        result = decompressor.decompress(5)

        expect(result).to eq(5)
        expect(output.data).to eq("Hello")
      end
    end

    context "with invalid signature" do
      it "searches for CK signature in stream" do
        # Add some garbage before CK signature
        compressed = [
          0x00, 0x11, 0x22,     # Garbage
          0x43, 0x4B,           # CK signature
          0x01,                 # final block, type 0
          0x03, 0x00,           # length = 3
          0xFC, 0xFF,           # complement
          0x41, 0x42, 0x43      # "ABC"
        ].pack("C*")

        input = Cabriolet::System::MemoryHandle.new(compressed, Cabriolet::Constants::MODE_READ)
        output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        decompressor = described_class.new(io_system, input, output,
                                           buffer_size)

        result = decompressor.decompress(3)

        expect(result).to eq(3)
        expect(output.data).to eq("ABC")
      end
    end

    context "with invalid block type" do
      it "raises error for block type 3" do
        compressed = [
          0x43, 0x4B,           # CK signature
          0x07                  # final block (1), type 3 (11 in binary)
        ].pack("C*")

        input = Cabriolet::System::MemoryHandle.new(compressed, Cabriolet::Constants::MODE_READ)
        output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        decompressor = described_class.new(io_system, input, output,
                                           buffer_size)

        expect do
          decompressor.decompress(10)
        end.to raise_error(Cabriolet::DecompressionError, /Invalid block type/)
      end
    end

    context "with length complement mismatch" do
      it "raises error for stored block with wrong complement" do
        compressed = [
          0x43, 0x4B,           # CK signature
          0x01,                 # final block, type 0
          0x05, 0x00,           # length = 5
          0x00, 0x00,           # Wrong complement
          0x48, 0x65, 0x6C, 0x6C, 0x6F
        ].pack("C*")

        input = Cabriolet::System::MemoryHandle.new(compressed, Cabriolet::Constants::MODE_READ)
        output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        decompressor = described_class.new(io_system, input, output,
                                           buffer_size)

        expect do
          decompressor.decompress(5)
        end.to raise_error(Cabriolet::DecompressionError, /complement mismatch/)
      end
    end

    context "with fix_mszip mode" do
      it "handles errors by padding with zeros" do
        # Corrupted data that will cause decompression error
        compressed = [
          0x43, 0x4B,           # CK signature
          0x07                  # final block, invalid type
        ].pack("C*")

        input = Cabriolet::System::MemoryHandle.new(compressed, Cabriolet::Constants::MODE_READ)
        output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        decompressor = described_class.new(
          io_system, input, output, buffer_size, fix_mszip: true
        )

        # In fix mode, should pad with zeros instead of raising
        result = decompressor.decompress(100)
        expect(result).to eq(100)
        # Output should be padded with zeros
        expect(output.data.bytes).to all(eq(0))
      end
    end
  end

  describe "window management" do
    it "uses 32KB sliding window" do
      # Window should wrap around at FRAME_SIZE
      input = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_READ)
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
      decompressor = described_class.new(io_system, input, output, buffer_size)

      # Access private instance variables for testing
      window = decompressor.instance_variable_get(:@window)
      expect(window.bytesize).to eq(described_class::FRAME_SIZE)
    end
  end

  # NOTE: Integration tests with CAB fixtures are tested in spec/cab/libmspack_parity_spec.rb

  describe "error handling" do
    it "handles EOF during signature read gracefully" do
      input = Cabriolet::System::MemoryHandle.new("\x43", Cabriolet::Constants::MODE_READ) # Just 'C', no 'K'
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
      decompressor = described_class.new(io_system, input, output, buffer_size)

      expect do
        decompressor.decompress(10)
      end.to raise_error(Cabriolet::DecompressionError)
    end

    it "handles truncated block gracefully" do
      compressed = [
        0x43, 0x4B,           # CK signature
        0x01                  # Block header but no more data
      ].pack("C*")

      input = Cabriolet::System::MemoryHandle.new(compressed, Cabriolet::Constants::MODE_READ)
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
      decompressor = described_class.new(io_system, input, output, buffer_size)

      expect do
        decompressor.decompress(10)
      end.to raise_error(Cabriolet::DecompressionError)
    end
  end
end
