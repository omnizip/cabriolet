# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::Decompressors::LZSS do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:buffer_size) { 512 }

  describe "#initialize" do
    it "initializes with default MODE_EXPAND" do
      input = Cabriolet::System::MemoryHandle.new("",
                                                  Cabriolet::Constants::MODE_READ)
      output = Cabriolet::System::MemoryHandle.new("",
                                                   Cabriolet::Constants::MODE_WRITE)
      decompressor = described_class.new(io_system, input, output,
                                         buffer_size)

      expect(decompressor.mode).to eq(described_class::MODE_EXPAND)
      expect(decompressor.window).to be_an(Array)
      expect(decompressor.window.size).to eq(described_class::WINDOW_SIZE)
      expect(decompressor.window.first).to eq(described_class::WINDOW_FILL)
    end

    it "initializes window position correctly for MODE_EXPAND" do
      input = Cabriolet::System::MemoryHandle.new("",
                                                  Cabriolet::Constants::MODE_READ)
      output = Cabriolet::System::MemoryHandle.new("",
                                                   Cabriolet::Constants::MODE_WRITE)
      decompressor = described_class.new(io_system, input, output,
                                         buffer_size,
                                         described_class::MODE_EXPAND)

      expected_pos = described_class::WINDOW_SIZE - 16
      expect(decompressor.window_pos).to eq(expected_pos)
    end

    it "initializes window position correctly for MODE_QBASIC" do
      input = Cabriolet::System::MemoryHandle.new("",
                                                  Cabriolet::Constants::MODE_READ)
      output = Cabriolet::System::MemoryHandle.new("",
                                                   Cabriolet::Constants::MODE_WRITE)
      decompressor = described_class.new(io_system, input, output,
                                         buffer_size,
                                         described_class::MODE_QBASIC)

      expected_pos = described_class::WINDOW_SIZE - 18
      expect(decompressor.window_pos).to eq(expected_pos)
    end
  end

  describe "#decompress" do
    context "with literal bytes only" do
      it "decompresses single literal byte" do
        # Control byte: 0xFF (all bits set = 8 literals)
        # Followed by 8 literal bytes
        compressed_data = [0xFF, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47,
                           0x48].pack("C*")
        input = Cabriolet::System::MemoryHandle.new(compressed_data,
                                                    Cabriolet::Constants::MODE_READ)
        output = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)

        decompressor = described_class.new(io_system, input, output,
                                           buffer_size)
        bytes_written = decompressor.decompress(0)

        expect(bytes_written).to eq(8)

        io_system.seek(output, 0, Cabriolet::Constants::SEEK_START)
        result = io_system.read(output, 100)
        expect(result).to eq("ABCDEFGH")
      end

      it "decompresses multiple control bytes with literals" do
        # Two control bytes with all bits set, 16 literal bytes total
        compressed_data = [
          0xFF, 0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x57, 0x6F,
          0xFF, 0x72, 0x6C, 0x64, 0x21, 0x00, 0x00, 0x00, 0x00
        ].pack("C*")
        input = Cabriolet::System::MemoryHandle.new(compressed_data,
                                                    Cabriolet::Constants::MODE_READ)
        output = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)

        decompressor = described_class.new(io_system, input, output,
                                           buffer_size)
        bytes_written = decompressor.decompress(0)

        expect(bytes_written).to eq(16)

        io_system.seek(output, 0, Cabriolet::Constants::SEEK_START)
        result = io_system.read(output, 100)
        expect(result).to eq("Hello World!\x00\x00\x00\x00")
      end
    end

    context "with match from window" do
      it "decompresses simple match" do
        # First, write some literals to the window
        # Control byte: 0x0F (bits 0-3 set = 4 literals, bits 4-7 clear = 4
        #   matches)
        # 4 literal bytes: "TEST"
        # 1 match: copy "TEST" again (offset points back to start of "TEST")
        #   Match: offset 4080, length 4 (encoded as 1)
        #   Offset 4080 = 0x0FF0 = low byte 0xF0, high nibble 0x0F
        #   Length 4 - 3 = 1, so second byte = 0xF1

        compressed_data = [
          0x0F, # Control byte: 4 literals, then 4 matches
          0x54, 0x45, 0x53, 0x54, # "TEST"
          0xF0, 0xF1 # Match: offset 4080, length 4
        ].pack("C*")

        input = Cabriolet::System::MemoryHandle.new(compressed_data,
                                                    Cabriolet::Constants::MODE_READ)
        output = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)

        decompressor = described_class.new(io_system, input, output,
                                           buffer_size)
        bytes_written = decompressor.decompress(0)

        expect(bytes_written).to eq(8)

        io_system.seek(output, 0, Cabriolet::Constants::SEEK_START)
        result = io_system.read(output, 100)
        expect(result).to eq("TESTTEST")
      end

      it "decompresses match with maximum length" do
        # Control byte: 0xFF (8 literals)
        # 8 literal bytes
        # Control byte: 0x00 (8 matches)
        # Match with max length (15 + 3 = 18 bytes)
        compressed_data = [
          0xFF,                                    # 8 literals
          0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48,
          0x00,                                    # 8 matches (we'll only use
          #   1)
          0xF8, 0xFF # Match: offset 4088, length
          #   18
        ].pack("C*")

        input = Cabriolet::System::MemoryHandle.new(compressed_data,
                                                    Cabriolet::Constants::MODE_READ)
        output = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)

        decompressor = described_class.new(io_system, input, output,
                                           buffer_size)
        bytes_written = decompressor.decompress(0)

        # 8 literals + 18 from match
        expect(bytes_written).to eq(26)

        io_system.seek(output, 0, Cabriolet::Constants::SEEK_START)
        result = io_system.read(output, 100)
        expect(result.start_with?("ABCDEFGH")).to be true
        expect(result.size).to eq(26)
      end
    end

    context "with window wraparound" do
      it "handles window position wraparound correctly" do
        # Create enough data to wrap around the window
        # Fill window with a pattern, then verify wraparound
        literals = Array.new(100, 0x41).pack("C*") # 100 'A's

        # Control bytes to write 100 literals (13 control bytes needed)
        compressed_data = ""
        (100 / 8).times do
          compressed_data += [0xFF].pack("C")
          compressed_data += literals.slice!(0, 8)
        end
        # Remaining 4 bytes
        compressed_data += [0x0F].pack("C")
        compressed_data += literals

        input = Cabriolet::System::MemoryHandle.new(compressed_data,
                                                    Cabriolet::Constants::MODE_READ)
        output = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)

        decompressor = described_class.new(io_system, input, output,
                                           buffer_size)
        bytes_written = decompressor.decompress(0)

        expect(bytes_written).to eq(100)

        io_system.seek(output, 0, Cabriolet::Constants::SEEK_START)
        result = io_system.read(output, 200)
        expect(result).to eq("A" * 100)
      end
    end

    context "with MODE_MSHELP" do
      it "inverts control byte for MSHELP mode" do
        # In MSHELP mode, control bytes are inverted
        # So 0x00 with inversion = 0xFF (all literals)
        compressed_data = [0x00, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47,
                           0x48].pack("C*")
        input = Cabriolet::System::MemoryHandle.new(compressed_data,
                                                    Cabriolet::Constants::MODE_READ)
        output = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)

        decompressor = described_class.new(io_system, input, output,
                                           buffer_size,
                                           described_class::MODE_MSHELP)
        bytes_written = decompressor.decompress(0)

        expect(bytes_written).to eq(8)

        io_system.seek(output, 0, Cabriolet::Constants::SEEK_START)
        result = io_system.read(output, 100)
        expect(result).to eq("ABCDEFGH")
      end
    end

    context "with empty input" do
      it "returns 0 bytes for empty input" do
        input = Cabriolet::System::MemoryHandle.new("",
                                                    Cabriolet::Constants::MODE_READ)
        output = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)

        decompressor = described_class.new(io_system, input, output,
                                           buffer_size)
        bytes_written = decompressor.decompress(0)

        expect(bytes_written).to eq(0)
      end
    end

    context "with partial data" do
      it "handles EOF gracefully during literal read" do
        # Control byte indicates 8 literals, but only 4 are provided
        compressed_data = [0xFF, 0x41, 0x42, 0x43, 0x44].pack("C*")
        input = Cabriolet::System::MemoryHandle.new(compressed_data,
                                                    Cabriolet::Constants::MODE_READ)
        output = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)

        decompressor = described_class.new(io_system, input, output,
                                           buffer_size)
        bytes_written = decompressor.decompress(0)

        expect(bytes_written).to eq(4)

        io_system.seek(output, 0, Cabriolet::Constants::SEEK_START)
        result = io_system.read(output, 100)
        expect(result).to eq("ABCD")
      end

      it "handles EOF gracefully during match read" do
        # Control byte indicates match, but only one byte provided
        compressed_data = [0x00, 0xF0].pack("C*")
        input = Cabriolet::System::MemoryHandle.new(compressed_data,
                                                    Cabriolet::Constants::MODE_READ)
        output = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)

        decompressor = described_class.new(io_system, input, output,
                                           buffer_size)
        bytes_written = decompressor.decompress(0)

        expect(bytes_written).to eq(0)
      end
    end

    context "with mixed literals and matches" do
      it "decompresses complex pattern correctly" do
        # Pattern: "ABCD" then match to repeat "BCD" (3 bytes)
        # Control byte: 0x1F (5 literals, 3 matches)
        # Literals: A, B, C, D, X
        # Match: copy "BCD" from position 4081 (where B was written)
        compressed_data = [
          0x1F, # 5 literals, then matches
          0x41, 0x42, 0x43, 0x44, 0x58, # "ABCDX"
          0xF1, 0xF0 # Match: offset 4081, length 3
        ].pack("C*")

        input = Cabriolet::System::MemoryHandle.new(compressed_data,
                                                    Cabriolet::Constants::MODE_READ)
        output = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)

        decompressor = described_class.new(io_system, input, output,
                                           buffer_size)
        bytes_written = decompressor.decompress(0)

        expect(bytes_written).to eq(8)

        io_system.seek(output, 0, Cabriolet::Constants::SEEK_START)
        result = io_system.read(output, 100)
        expect(result).to eq("ABCDXBCD")
      end
    end
  end
end
