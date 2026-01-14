# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"

RSpec.describe Cabriolet::HLP::WinHelp::Decompressor do
  let(:io_system) { Cabriolet::System::IOSystem.new }

  describe "#initialize" do
    it "creates decompressor with filename" do
      file = Tempfile.new(["test", ".hlp"])
      begin
        decompressor = described_class.new(file.path)
        expect(decompressor).to be_a(described_class)
        expect(decompressor.io_system).to be_a(Cabriolet::System::IOSystem)
      ensure
        file.unlink
      end
    end

    it "accepts custom IO system" do
      file = Tempfile.new(["test", ".hlp"])
      begin
        custom_io = Cabriolet::System::IOSystem.new
        decompressor = described_class.new(file.path, custom_io)
        expect(decompressor.io_system).to eq(custom_io)
      ensure
        file.unlink
      end
    end
  end

  describe "#parse" do
    it "parses WinHelp file and returns header" do
      # Create minimal WinHelp 3.x file
      data = +""
      data << [0x35F3].pack("v")      # Magic
      data << [0x0001].pack("v")      # Unknown
      data << [0x001C].pack("V")      # Directory offset
      data << [0x0000].pack("V")      # Free list offset
      data << [0x0100].pack("V")      # File size
      data << ("\x00" * 12)           # Reserved

      # Directory (one file)
      data << [0x0010].pack("V")      # File size
      data << [0x0001].pack("v")      # Starting block
      data << "|SYSTEM\x00"           # Filename

      # End marker
      data << [0x0000].pack("V")

      file = Tempfile.new(["winhelp", ".hlp"])
      begin
        file.write(data)
        file.close

        decompressor = described_class.new(file.path, io_system)
        header = decompressor.parse

        expect(header).to be_a(Cabriolet::Models::WinHelpHeader)
        expect(header.version).to eq(:winhelp3)
        expect(header.internal_files.length).to eq(1)
      ensure
        file.unlink
      end
    end
  end

  describe "#extract_internal_file" do
    it "extracts internal file by name" do
      # Create WinHelp file with |SYSTEM file at block 1
      data = +""
      data << [0x35F3].pack("v")
      data << [0x0001].pack("v")
      data << [0x001C].pack("V")
      data << [0x0000].pack("V")
      data << [0x1000].pack("V") # File size (4096 bytes)
      data << ("\x00" * 12)

      # Directory
      data << [0x0010].pack("V")      # |SYSTEM size: 16 bytes
      data << [0x0001].pack("v")      # Starting block: 1
      data << "|SYSTEM\x00"
      data << [0x0000].pack("V")      # End

      # Pad to block 1 (4096 bytes)
      data << ("\x00" * (4096 - data.bytesize))

      # |SYSTEM file data at block 1
      system_data = "SYSTEM FILE DATA"
      data << system_data
      data << ("\x00" * (0x10 - system_data.bytesize)) # Pad to claimed size

      file = Tempfile.new(["winhelp_extract", ".hlp"])
      begin
        file.write(data)
        file.close

        decompressor = described_class.new(file.path, io_system)
        extracted = decompressor.extract_internal_file("|SYSTEM")

        expect(extracted).not_to be_nil
        expect(extracted.bytesize).to eq(0x10)
        expect(extracted[0..15]).to eq("SYSTEM FILE DATA")
      ensure
        file.unlink
      end
    end

    it "returns nil for non-existent file" do
      data = +""
      data << [0x35F3].pack("v")
      data << [0x0001].pack("v")
      data << [0x001C].pack("V")
      data << [0x0000].pack("V")
      data << [0x0100].pack("V")
      data << ("\x00" * 12)
      data << [0x0000].pack("V") # Empty directory

      file = Tempfile.new(["winhelp_none", ".hlp"])
      begin
        file.write(data)
        file.close

        decompressor = described_class.new(file.path, io_system)
        extracted = decompressor.extract_internal_file("|NOTHING")

        expect(extracted).to be_nil
      ensure
        file.unlink
      end
    end
  end

  describe "#decompress_topic" do
    it "decompresses topic data using Zeck LZ77" do
      file = Tempfile.new(["test", ".hlp"])
      begin
        decompressor = described_class.new(file.path, io_system)

        # Create simple compressed data (all literals)
        compressed = [0x00, *"HELLO".bytes].pack("C*")
        decompressed = decompressor.decompress_topic(compressed, 5)

        expect(decompressed).to eq("HELLO")
      ensure
        file.unlink
      end
    end
  end

  describe "#has_system_file?" do
    it "returns true when |SYSTEM exists" do
      data = +""
      data << [0x35F3].pack("v")
      data << [0x0001].pack("v")
      data << [0x001C].pack("V")
      data << [0x0000].pack("V")
      data << [0x0100].pack("V")
      data << ("\x00" * 12)

      # Directory with |SYSTEM
      data << [0x0010].pack("V")
      data << [0x0001].pack("v")
      data << "|SYSTEM\x00"
      data << [0x0000].pack("V")

      file = Tempfile.new(["winhelp", ".hlp"])
      begin
        file.write(data)
        file.close

        decompressor = described_class.new(file.path, io_system)
        expect(decompressor.has_system_file?).to be true
      ensure
        file.unlink
      end
    end
  end

  describe "#internal_filenames" do
    it "returns list of internal files" do
      data = +""
      data << [0x35F3].pack("v")
      data << [0x0001].pack("v")
      data << [0x001C].pack("V")
      data << [0x0000].pack("V")
      data << [0x0100].pack("V")
      data << ("\x00" * 12)

      # Directory with 2 files
      data << [0x0010].pack("V")
      data << [0x0001].pack("v")
      data << "|SYSTEM\x00"

      data << [0x0020].pack("V")
      data << [0x0002].pack("v")
      data << "|TOPIC\x00"
      data << "\x00" # Alignment

      data << [0x0000].pack("V")

      file = Tempfile.new(["winhelp", ".hlp"])
      begin
        file.write(data)
        file.close

        decompressor = described_class.new(file.path, io_system)
        names = decompressor.internal_filenames

        expect(names).to eq(["|SYSTEM", "|TOPIC"])
      ensure
        file.unlink
      end
    end
  end
end
