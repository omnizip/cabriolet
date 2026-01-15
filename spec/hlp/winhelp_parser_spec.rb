# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Cabriolet::HLP::WinHelp::Parser do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:parser) { described_class.new(io_system) }

  describe "#initialize" do
    it "creates parser with default IO system" do
      parser = described_class.new
      expect(parser.io_system).to be_a(Cabriolet::System::IOSystem)
    end

    it "creates parser with custom IO system" do
      custom_io = Cabriolet::System::IOSystem.new
      parser = described_class.new(custom_io)
      expect(parser.io_system).to eq(custom_io)
    end
  end

  describe "WinHelp 3.x parsing" do
    let(:winhelp3_data) do
      # WinHelp 3.x file header (28 bytes)
      data = String.new
      data << [0x35F3].pack("v")      # Magic number
      data << [0x0001].pack("v")      # Unknown/version
      data << [0x001C].pack("V")      # Directory offset (after header)
      data << [0x0000].pack("V")      # Free list offset
      data << [0x0100].pack("V")      # File size (256 bytes)
      data << ("\x00" * 12)           # Reserved
      data
    end

    it "detects WinHelp 3.x format" do
      file = Tempfile.new(["winhelp3", ".hlp"])
      begin
        file.write(winhelp3_data)
        file.close

        header = parser.parse(file.path)
        expect(header).to be_a(Cabriolet::Models::WinHelpHeader)
        expect(header.version).to eq(:winhelp3)
        expect(header.magic).to eq(0x35F3)
      ensure
        file.unlink
      end
    end

    it "parses WinHelp 3.x header fields" do
      file = Tempfile.new(["winhelp3", ".hlp"])
      begin
        file.write(winhelp3_data)
        file.close

        header = parser.parse(file.path)
        expect(header.directory_offset).to eq(0x001C)
        expect(header.free_list_offset).to eq(0x0000)
        expect(header.file_size).to eq(0x0100)
      ensure
        file.unlink
      end
    end

    it "validates magic number" do
      invalid_data = winhelp3_data.dup
      invalid_data[0..1] = [0x1234].pack("v")

      file = Tempfile.new(["invalid", ".hlp"])
      begin
        file.write(invalid_data)
        file.close

        expect { parser.parse(file.path) }.to raise_error(Cabriolet::ParseError, /magic/)
      ensure
        file.unlink
      end
    end
  end

  describe "WinHelp 4.x parsing" do
    let(:winhelp4_data) do
      # WinHelp 4.x file header (32 bytes)
      data = String.new
      data << [0x00003F5F].pack("V")  # Magic number (4 bytes)
      data << [0x00000020].pack("V")  # Directory offset (after header)
      data << [0x00000000].pack("V")  # Free list offset
      data << [0x00000200].pack("V")  # File size (512 bytes)
      data << ("\x00" * 16)           # Reserved
      data
    end

    it "detects WinHelp 4.x format" do
      file = Tempfile.new(["winhelp4", ".hlp"])
      begin
        file.write(winhelp4_data)
        file.close

        header = parser.parse(file.path)
        expect(header).to be_a(Cabriolet::Models::WinHelpHeader)
        expect(header.version).to eq(:winhelp4)
        expect(header.magic & 0xFFFF).to eq(0x3F5F)
      ensure
        file.unlink
      end
    end

    it "parses WinHelp 4.x header fields" do
      file = Tempfile.new(["winhelp4", ".hlp"])
      begin
        file.write(winhelp4_data)
        file.close

        header = parser.parse(file.path)
        expect(header.directory_offset).to eq(0x00000020)
        expect(header.free_list_offset).to eq(0x00000000)
        expect(header.file_size).to eq(0x00000200)
      ensure
        file.unlink
      end
    end
  end

  describe "directory parsing" do
    it "parses internal file directory" do
      # Create WinHelp 3.x file with directory
      data = String.new
      data << [0x35F3].pack("v")      # Magic
      data << [0x0001].pack("v")      # Unknown
      data << [0x001C].pack("V")      # Directory offset
      data << [0x0000].pack("V")      # Free list offset
      data << [0x0100].pack("V")      # File size
      data << ("\x00" * 12)           # Reserved

      # Directory starts at offset 0x1C (28 bytes)
      # Entry 1: |SYSTEM file
      data << [0x0050].pack("V")      # File size: 80 bytes
      data << [0x0001].pack("v")      # Starting block: 1
      data << "|SYSTEM\x00"           # Filename (8 bytes, even)
      # No padding needed - already aligned

      # Entry 2: |TOPIC file
      data << [0x0100].pack("V")      # File size: 256 bytes
      data << [0x0002].pack("v")      # Starting block: 2
      data << "|TOPIC\x00"            # Filename (7 bytes, odd)
      data << "\x00"                  # Alignment padding to even boundary

      # End of directory
      data << [0x0000].pack("V")      # Zero size = end

      file = Tempfile.new(["winhelp_dir", ".hlp"])
      begin
        file.write(data)
        file.close

        header = parser.parse(file.path)
        expect(header.internal_files.length).to eq(2)

        system_file = header.internal_files[0]
        expect(system_file[:filename]).to eq("|SYSTEM")
        expect(system_file[:file_size]).to eq(0x0050)
        expect(system_file[:starting_block]).to eq(0x0001)

        topic_file = header.internal_files[1]
        expect(topic_file[:filename]).to eq("|TOPIC")
        expect(topic_file[:file_size]).to eq(0x0100)
        expect(topic_file[:starting_block]).to eq(0x0002)
      ensure
        file.unlink
      end
    end

    it "handles empty directory" do
      # WinHelp file with no directory (offset = 0)
      data = String.new
      data << [0x35F3].pack("v")
      data << [0x0001].pack("v")
      data << [0x0000].pack("V")      # Directory offset = 0 (none)
      data << [0x0000].pack("V")
      data << [0x001C].pack("V")
      data << ("\x00" * 12)

      file = Tempfile.new(["winhelp_nodir", ".hlp"])
      begin
        file.write(data)
        file.close

        header = parser.parse(file.path)
        expect(header.internal_files).to be_empty
      ensure
        file.unlink
      end
    end
  end

  describe "error handling" do
    it "raises error for file too small" do
      file = Tempfile.new(["tiny", ".hlp"])
      begin
        file.write("AB")  # Only 2 bytes
        file.close

        expect { parser.parse(file.path) }.to raise_error(Cabriolet::ParseError)
      ensure
        file.unlink
      end
    end

    it "raises error for invalid magic number" do
      data = "\xFF\xFF" + ("\x00" * 26)
      file = Tempfile.new(["invalid_magic", ".hlp"])
      begin
        file.write(data)
        file.close

        expect { parser.parse(file.path) }.to raise_error(Cabriolet::ParseError, /magic/)
      ensure
        file.unlink
      end
    end
  end
end
