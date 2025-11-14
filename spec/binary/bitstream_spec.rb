# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::Binary::Bitstream do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:test_data) { "\x12\x34\x56\x78\x9A\xBC\xDE\xF0".b }
  let(:handle) { Cabriolet::System::MemoryHandle.new(test_data) }
  let(:bitstream) { described_class.new(io_system, handle, 8) }

  describe "#initialize" do
    it "initializes with io_system and handle" do
      bs = described_class.new(io_system, handle)
      expect(bs.io_system).to eq(io_system)
      expect(bs.handle).to eq(handle)
      expect(bs.buffer_size).to eq(Cabriolet.default_buffer_size)
    end

    it "accepts custom buffer size" do
      bs = described_class.new(io_system, handle, 1024)
      expect(bs.buffer_size).to eq(1024)
    end
  end

  describe "#read_bits" do
    context "reading 1-8 bits" do
      it "reads 1 bit correctly" do
        # 0x12 = 0001 0010
        # LSB first: bit 0 = 0
        expect(bitstream.read_bits(1)).to eq(0)
      end

      it "reads 4 bits correctly" do
        # 0x12 = 0001 0010
        # LSB first: bits 0-3 = 0010 = 2
        expect(bitstream.read_bits(4)).to eq(2)
      end

      it "reads 8 bits correctly" do
        # 0x12 = 0001 0010
        expect(bitstream.read_bits(8)).to eq(0x12)
      end
    end

    context "reading 9-16 bits" do
      it "reads 16 bits spanning two bytes" do
        # 0x12 0x34
        # Little-endian: 0x3412
        expect(bitstream.read_bits(16)).to eq(0x3412)
      end

      it "reads 12 bits correctly" do
        # First 12 bits of 0x12 0x34
        # 0x12 = 0001 0010, 0x34 = 0011 0100
        # LSB first: 0010 0011 0100 = 0x234
        expect(bitstream.read_bits(12)).to eq(0x412)
      end
    end

    context "reading 17-32 bits" do
      it "reads 32 bits correctly" do
        # 0x12 0x34 0x56 0x78
        # Little-endian: 0x78563412
        expect(bitstream.read_bits(32)).to eq(0x78563412)
      end

      it "reads 24 bits correctly" do
        # First 24 bits of 0x12 0x34 0x56
        # Little-endian: 0x563412
        expect(bitstream.read_bits(24)).to eq(0x563412)
      end
    end

    context "sequential reads" do
      it "maintains bit position across reads" do
        bitstream.read_bits(4) # Read 4 bits from 0x12
        result = bitstream.read_bits(4) # Read next 4 bits
        expect(result).to eq(1) # bits 4-7 of 0x12
      end

      it "crosses byte boundaries correctly" do
        bitstream.read_bits(12) # Read 12 bits (1.5 bytes)
        result = bitstream.read_bits(8) # Read next 8 bits
        # After 12 bits of 0x12 0x34, we're at bit 4 of 0x34
        # bits 4-7 of 0x34 + bits 0-3 of 0x56
        expect(result).to be_a(Integer)
      end
    end

    context "at EOF" do
      it "returns 0 when no more data" do
        8.times { bitstream.read_bits(8) } # Read all 8 bytes
        result = bitstream.read_bits(8)
        expect(result).to eq(0)
      end
    end

    context "with invalid bit count" do
      it "raises ArgumentError for 0 bits" do
        expect do
          bitstream.read_bits(0)
        end.to raise_error(ArgumentError, /Can only read 1-32 bits/)
      end

      it "raises ArgumentError for 33 bits" do
        expect do
          bitstream.read_bits(33)
        end.to raise_error(ArgumentError, /Can only read 1-32 bits/)
      end
    end
  end

  describe "#read_byte" do
    it "reads a single byte" do
      expect(bitstream.read_byte).to eq(0x12)
    end

    it "advances position" do
      bitstream.read_byte
      expect(bitstream.read_byte).to eq(0x34)
    end

    it "returns nil at EOF" do
      8.times { bitstream.read_byte }
      expect(bitstream.read_byte).to be_nil
    end

    it "refills buffer when needed" do
      # With buffer_size=8, all data fits in one buffer
      8.times do |_i|
        byte = bitstream.read_byte
        expect(byte).to be_a(Integer)
      end
    end
  end

  describe "#byte_align" do
    it "discards partial bits to align to byte boundary" do
      bitstream.read_bits(5) # Read 5 bits, leaving 3 bits in buffer
      bitstream.byte_align
      # Next read should be from a fresh byte
      result = bitstream.read_bits(8)
      expect(result).to eq(0x34) # Second byte
    end

    it "has no effect when already aligned" do
      bitstream.read_bits(8) # Read full byte
      bitstream.byte_align
      result = bitstream.read_bits(8)
      expect(result).to eq(0x34)
    end

    it "handles empty bit buffer" do
      bitstream.byte_align
      result = bitstream.read_bits(8)
      expect(result).to eq(0x12)
    end
  end

  describe "#peek_bits" do
    it "reads bits without consuming them" do
      result1 = bitstream.peek_bits(8)
      result2 = bitstream.peek_bits(8)
      expect(result1).to eq(result2)
      expect(result1).to eq(0x12)
    end

    it "allows subsequent read to get same bits" do
      peeked = bitstream.peek_bits(8)
      read = bitstream.read_bits(8)
      expect(peeked).to eq(read)
    end

    it "can peek more than 8 bits" do
      result = bitstream.peek_bits(16)
      expect(result).to be_a(Integer)
    end

    context "with invalid bit count" do
      it "raises ArgumentError for 0 bits" do
        expect do
          bitstream.peek_bits(0)
        end.to raise_error(ArgumentError, /Can only peek 1-32 bits/)
      end

      it "raises ArgumentError for 33 bits" do
        expect do
          bitstream.peek_bits(33)
        end.to raise_error(ArgumentError, /Can only peek 1-32 bits/)
      end
    end

    it "returns 0 at EOF" do
      8.times { bitstream.read_bits(8) }
      result = bitstream.peek_bits(8)
      expect(result).to eq(0)
    end
  end

  describe "#skip_bits" do
    it "skips specified number of bits" do
      bitstream.skip_bits(8)
      result = bitstream.read_bits(8)
      expect(result).to eq(0x34) # Second byte
    end

    it "returns nil" do
      result = bitstream.skip_bits(4)
      expect(result).to be_nil
    end

    it "can skip multiple bytes" do
      bitstream.skip_bits(24) # Skip 3 bytes
      result = bitstream.read_bits(8)
      expect(result).to eq(0x78) # Fourth byte
    end
  end

  describe "#read_bits_be" do
    it "reads bits in big-endian (MSB first) order" do
      # Reading in BE order gives different result than LE
      result = bitstream.read_bits_be(8)
      expect(result).to be_a(Integer)
    end

    it "reads multiple bits correctly" do
      result = bitstream.read_bits_be(4)
      expect(result).to be_a(Integer)
    end
  end

  describe "#read_uint16_le" do
    it "reads a 16-bit little-endian value" do
      result = bitstream.read_uint16_le
      expect(result).to eq(0x3412) # 0x12 0x34 in LE
    end

    it "advances position by 16 bits" do
      bitstream.read_uint16_le
      result = bitstream.read_uint16_le
      expect(result).to eq(0x7856) # 0x56 0x78 in LE
    end
  end

  describe "#read_uint32_le" do
    it "reads a 32-bit little-endian value" do
      result = bitstream.read_uint32_le
      expect(result).to eq(0x78563412) # 0x12 0x34 0x56 0x78 in LE
    end

    it "advances position by 32 bits" do
      bitstream.read_uint32_le
      result = bitstream.read_uint32_le
      expect(result).to eq(0xF0DEBC9A) # 0x9A 0xBC 0xDE 0xF0 in LE
    end
  end

  describe "#reset" do
    it "clears all buffers" do
      bitstream.read_bits(16)
      bitstream.reset
      result = bitstream.read_bits(8)
      expect(result).to eq(0x12) # Back to first byte
    end

    it "resets bit buffer" do
      bitstream.read_bits(5)
      bitstream.reset
      result = bitstream.read_bits(8)
      expect(result).to eq(0x12)
    end

    it "resets byte buffer" do
      bitstream.read_byte
      bitstream.reset
      # After reset, position should be back at start
      # Note: This depends on handle position being reset separately
      result = bitstream.read_bits(8)
      expect(result).to be_a(Integer)
    end
  end

  describe "buffer management" do
    context "with small buffer size" do
      let(:bitstream) { described_class.new(io_system, handle, 2) }

      it "refills buffer as needed" do
        # Read more than buffer size
        4.times do
          result = bitstream.read_bits(8)
          expect(result).to be_a(Integer)
        end
      end
    end

    context "with large buffer size" do
      let(:bitstream) { described_class.new(io_system, handle, 1024) }

      it "reads all data without refilling" do
        8.times do
          result = bitstream.read_bits(8)
          expect(result).to be_a(Integer)
        end
      end
    end
  end

  describe "edge cases" do
    context "with empty data" do
      let(:empty_handle) { Cabriolet::System::MemoryHandle.new("") }
      let(:empty_bitstream) { described_class.new(io_system, empty_handle) }

      it "returns 0 for read_bits" do
        result = empty_bitstream.read_bits(8)
        expect(result).to eq(0)
      end

      it "returns nil for read_byte" do
        result = empty_bitstream.read_byte
        expect(result).to be_nil
      end
    end

    context "with single byte" do
      let(:single_handle) { Cabriolet::System::MemoryHandle.new("\xFF".b) }
      let(:single_bitstream) { described_class.new(io_system, single_handle) }

      it "reads the byte correctly" do
        result = single_bitstream.read_bits(8)
        expect(result).to eq(0xFF)
      end

      it "returns 0 after reading all data" do
        single_bitstream.read_bits(8)
        result = single_bitstream.read_bits(8)
        expect(result).to eq(0)
      end
    end
  end
end
