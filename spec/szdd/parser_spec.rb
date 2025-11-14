# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Cabriolet::SZDD::Parser do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:parser) { described_class.new(io_system) }

  describe "#parse_handle" do
    context "with NORMAL format SZDD" do
      it "parses valid NORMAL format header" do
        # Create NORMAL format SZDD header in memory
        # Signature: SZDD\x88\xF0\x27\x33 (8 bytes)
        # Compression mode: 0x41 (1 byte)
        # Missing char: 't' (1 byte)
        # Uncompressed size: 1234 (4 bytes, little-endian)
        data = [
          0x53, 0x5A, 0x44, 0x44, 0x88, 0xF0, 0x27, 0x33, # Signature
          0x41,                                           # Compression mode
          0x74,                                           # Missing char 't'
          0xD2, 0x04, 0x00, 0x00                          # Size: 1234
        ].pack("C*")

        handle = Cabriolet::System::MemoryHandle.new(data)
        header = parser.parse_handle(handle, "test.tx_")

        expect(header.format).to eq(Cabriolet::Models::SZDDHeader::FORMAT_NORMAL)
        expect(header.length).to eq(1234)
        expect(header.missing_char).to eq("t")
        expect(header.filename).to eq("test.tx_")

        io_system.close(handle)
      end

      it "raises error for invalid compression mode" do
        # Invalid compression mode (not 0x41)
        data = [
          0x53, 0x5A, 0x44, 0x44, 0x88, 0xF0, 0x27, 0x33,
          0x42, # Wrong mode
          0x74,
          0xD2, 0x04, 0x00, 0x00
        ].pack("C*")

        handle = Cabriolet::System::MemoryHandle.new(data)
        expect { parser.parse_handle(handle) }.to raise_error(
          Cabriolet::ParseError,
          /Invalid compression mode/,
        )

        io_system.close(handle)
      end
    end

    context "with QBASIC format SZDD" do
      it "parses valid QBASIC format header" do
        # Create QBASIC format SZDD header in memory
        # Signature: SZDD \x88\xF0\x27\x33\xD1 (8 bytes, note space instead of 'D')
        # Uncompressed size: 5678 (4 bytes, little-endian)
        data = [
          0x53, 0x5A, 0x20, 0x88, 0xF0, 0x27, 0x33, 0xD1, # Signature
          0x2E, 0x16, 0x00, 0x00                          # Size: 5678
        ].pack("C*")

        handle = Cabriolet::System::MemoryHandle.new(data)
        header = parser.parse_handle(handle, "test.dat")

        expect(header.format).to eq(Cabriolet::Models::SZDDHeader::FORMAT_QBASIC)
        expect(header.length).to eq(5678)
        expect(header.missing_char).to be_nil
        expect(header.filename).to eq("test.dat")

        io_system.close(handle)
      end
    end

    context "with invalid signature" do
      it "raises error for completely invalid signature" do
        data = "NOT A SZDD FILE\x00\x00\x00"

        handle = Cabriolet::System::MemoryHandle.new(data)
        expect { parser.parse_handle(handle) }.to raise_error(
          Cabriolet::ParseError,
          /Invalid SZDD signature/,
        )

        io_system.close(handle)
      end

      it "raises error for truncated signature" do
        data = "SZDD"

        handle = Cabriolet::System::MemoryHandle.new(data)
        expect { parser.parse_handle(handle) }.to raise_error(
          Cabriolet::ParseError,
          /Cannot read SZDD signature/,
        )

        io_system.close(handle)
      end
    end

    context "with truncated header" do
      it "raises error for incomplete NORMAL header" do
        data = [
          0x53, 0x5A, 0x44, 0x44, 0x88, 0xF0, 0x27, 0x33,
          0x41,
          0x74
          # Missing uncompressed size
        ].pack("C*")

        handle = Cabriolet::System::MemoryHandle.new(data)
        expect { parser.parse_handle(handle) }.to raise_error(
          Cabriolet::ParseError,
          /Cannot read SZDD header/,
        )

        io_system.close(handle)
      end

      it "raises error for incomplete QBASIC header" do
        data = [
          0x53, 0x5A, 0x20, 0x88, 0xF0, 0x27, 0x33, 0xD1,
          0x2E, 0x16 # Incomplete size (only 2 bytes instead of 4)
        ].pack("C*")

        handle = Cabriolet::System::MemoryHandle.new(data)
        expect { parser.parse_handle(handle) }.to raise_error(
          Cabriolet::ParseError,
          /Cannot read SZDD header/,
        )

        io_system.close(handle)
      end
    end
  end

  describe "#data_offset" do
    it "returns 14 for NORMAL format" do
      offset = parser.data_offset(Cabriolet::Models::SZDDHeader::FORMAT_NORMAL)
      expect(offset).to eq(14)
    end

    it "returns 12 for QBASIC format" do
      offset = parser.data_offset(Cabriolet::Models::SZDDHeader::FORMAT_QBASIC)
      expect(offset).to eq(12)
    end
  end
end
