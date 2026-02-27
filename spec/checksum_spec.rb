# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::Checksum do
  describe ".calculate" do
    it "returns 0 for empty data" do
      expect(described_class.calculate("")).to eq(0)
    end

    it "processes 4-byte aligned data correctly" do
      data = [0x12, 0x34, 0x56, 0x78].pack("C*")
      expected = 0x78563412
      expect(described_class.calculate(data)).to eq(expected)
    end

    it "XORs multiple 4-byte chunks" do
      data = [0x12, 0x34, 0x56, 0x78, 0xAA, 0xBB, 0xCC, 0xDD].pack("C*")
      expected = 0x78563412 ^ 0xDDCCBBAA
      expect(described_class.calculate(data)).to eq(expected)
    end

    context "remainder byte order (libmspack cabd_checksum)" do
      # Per libmspack's C fall-through switch: the first remaining byte
      # gets the highest shift. This matches the C code:
      #   case 3: ul |= *data++ << 16; /* fall-through */
      #   case 2: ul |= *data++ << 8;  /* fall-through */
      #   case 1: ul |= *data;

      it "handles 1-byte remainder" do
        data = [0x12, 0x34, 0x56, 0x78, 0xAB].pack("C*")
        # remainder byte at lowest position
        expected = 0x78563412 ^ 0xAB
        expect(described_class.calculate(data)).to eq(expected)
      end

      it "handles 2-byte remainder with first byte at higher shift" do
        data = [0x12, 0x34, 0x56, 0x78, 0xAB, 0xCD].pack("C*")
        # first remaining byte (0xAB) gets << 8, second (0xCD) gets << 0
        expected = 0x78563412 ^ 0xABCD
        expect(described_class.calculate(data)).to eq(expected)
      end

      it "handles 3-byte remainder with first byte at highest shift" do
        data = [0x12, 0x34, 0x56, 0x78, 0xAB, 0xCD, 0xEF].pack("C*")
        # first remaining byte (0xAB) gets << 16, second (0xCD) gets << 8,
        # third (0xEF) gets << 0
        expected = 0x78563412 ^ 0xABCDEF
        expect(described_class.calculate(data)).to eq(expected)
      end
    end

    it "accepts an initial checksum value" do
      data = [0x01, 0x02, 0x03, 0x04].pack("C*")
      initial = 0xFFFFFFFF
      expected = initial ^ 0x04030201
      expect(described_class.calculate(data, initial)).to eq(expected)
    end

    it "returns a 32-bit value" do
      data = [0xFF, 0xFF, 0xFF, 0xFF].pack("C*")
      result = described_class.calculate(data)
      expect(result).to be <= 0xFFFFFFFF
    end
  end
end
