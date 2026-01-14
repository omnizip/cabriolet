# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"

RSpec.describe "HLP Format Integration" do
  let(:io_system) { Cabriolet::System::IOSystem.new }

  describe "Windows Help 3.x end-to-end" do
    it "creates and extracts WinHelp 3.x file successfully" do
      # Create WinHelp file
      compressor = Cabriolet::HLP::WinHelp::Compressor.new(io_system)
      compressor.add_system_file(
        title: "Test Help File",
        copyright: "Copyright 2025",
      )
      compressor.add_topic_file(["Topic 1 text", "Topic 2 text"])

      hlp_file = Tempfile.new(["test3x", ".hlp"])
      output_dir = Dir.mktmpdir

      begin
        # Generate file
        bytes = compressor.generate(hlp_file.path, version: :winhelp3)
        expect(bytes).to be > 0

        # Parse it
        parser = Cabriolet::HLP::Parser.new(io_system)
        header = parser.parse(hlp_file.path)

        expect(header).to be_a(Cabriolet::Models::WinHelpHeader)
        expect(header.version).to eq(:winhelp3)
        expect(header.magic).to eq(0x35F3)

        # Extract files
        decompressor = Cabriolet::HLP::WinHelp::Decompressor.new(hlp_file.path,
                                                                 io_system)
        count = decompressor.extract_all(output_dir)
        expect(count).to eq(2) # |SYSTEM and |TOPIC
      ensure
        hlp_file.unlink
        FileUtils.rm_rf(output_dir)
      end
    end

    it "compresses and decompresses topics correctly" do
      topic_text = "This is a test topic with some repetitive text. " * 10

      compressor = Cabriolet::HLP::WinHelp::Compressor.new(io_system)
      compressor.add_system_file(title: "Test")
      compressor.add_topic_file([topic_text], compress: true)

      hlp_file = Tempfile.new(["compress3x", ".hlp"])

      begin
        compressor.generate(hlp_file.path, version: :winhelp3)

        # Extract and verify
        decompressor = Cabriolet::HLP::WinHelp::Decompressor.new(hlp_file.path,
                                                                 io_system)
        topic_data = decompressor.extract_topic_file

        expect(topic_data).not_to be_nil
        expect(topic_data.bytesize).to be > 0
      ensure
        hlp_file.unlink
      end
    end
  end

  describe "Windows Help 4.x end-to-end" do
    it "creates and extracts WinHelp 4.x file successfully" do
      compressor = Cabriolet::HLP::WinHelp::Compressor.new(io_system)
      compressor.add_system_file(title: "Test Help 4.x")
      compressor.add_topic_file(["Topic 1", "Topic 2"])

      hlp_file = Tempfile.new(["test4x", ".hlp"])
      output_dir = Dir.mktmpdir

      begin
        bytes = compressor.generate(hlp_file.path, version: :winhelp4)
        expect(bytes).to be > 0

        # Parse it
        parser = Cabriolet::HLP::Parser.new(io_system)
        header = parser.parse(hlp_file.path)

        expect(header).to be_a(Cabriolet::Models::WinHelpHeader)
        expect(header.version).to eq(:winhelp4)
        expect(header.magic & 0xFFFF).to eq(0x3F5F)

        # Extract files
        decompressor = Cabriolet::HLP::WinHelp::Decompressor.new(hlp_file.path,
                                                                 io_system)
        count = decompressor.extract_all(output_dir)
        expect(count).to eq(2)
      ensure
        hlp_file.unlink
        FileUtils.rm_rf(output_dir)
      end
    end
  end

  describe "Format detection" do
    it "correctly identifies QuickHelp format" do
      # Create minimal QuickHelp file with proper header
      header = Cabriolet::Binary::HLPStructures::FileHeader.new
      header.signature = Cabriolet::Binary::HLPStructures::SIGNATURE
      header.version = 2 # Required
      header.attributes = 0
      header.control_character = 0x3A
      header.padding1 = 0
      header.topic_count = 0
      header.context_count = 0
      header.display_width = 80
      header.padding2 = 0
      header.predefined_ctx_count = 0
      header.database_name = "test".ljust(14, "\x00")
      header.reserved1 = 0
      header.topic_index_offset = 70
      header.context_strings_offset = 74 # After 1 DWORD
      header.context_map_offset = 74
      header.keywords_offset = 0
      header.huffman_tree_offset = 0
      header.topic_text_offset = 74
      header.reserved2 = 0
      header.reserved3 = 0
      header.database_size = 74

      data = header.to_binary_s
      # Add topic index (topic_count + 1 = 1 DWORD for empty list)
      data += [0].pack("V")

      file = Tempfile.new(["quickhelp", ".hlp"])
      begin
        file.write(data)
        file.close

        parser = Cabriolet::HLP::Parser.new(io_system)
        header = parser.parse(file.path)
        expect(header).to be_a(Cabriolet::Models::HLPHeader)
      ensure
        file.unlink
      end
    end

    it "correctly identifies WinHelp 3.x format" do
      data = [0x35F3].pack("v") + ("\x00" * 26)

      file = Tempfile.new(["winhelp3", ".hlp"])
      begin
        file.write(data)
        file.close

        parser = Cabriolet::HLP::Parser.new(io_system)
        header = parser.parse(file.path)
        expect(header).to be_a(Cabriolet::Models::WinHelpHeader)
        expect(header.version).to eq(:winhelp3)
      ensure
        file.unlink
      end
    end

    it "correctly identifies WinHelp 4.x format" do
      data = [0x00003F5F].pack("V") + ("\x00" * 28)

      file = Tempfile.new(["winhelp4", ".hlp"])
      begin
        file.write(data)
        file.close

        parser = Cabriolet::HLP::Parser.new(io_system)
        header = parser.parse(file.path)
        expect(header).to be_a(Cabriolet::Models::WinHelpHeader)
        expect(header.version).to eq(:winhelp4)
      ensure
        file.unlink
      end
    end
  end

  describe "HLP::Decompressor routing" do
    it "routes WinHelp files correctly" do
      compressor = Cabriolet::HLP::WinHelp::Compressor.new(io_system)
      compressor.add_system_file(title: "Test")
      compressor.add_topic_file(["Test"])

      hlp_file = Tempfile.new(["routing", ".hlp"])
      output_dir = Dir.mktmpdir

      begin
        compressor.generate(hlp_file.path)

        # Use class method for extraction
        count = Cabriolet::HLP::Decompressor.extract(hlp_file.path, output_dir,
                                                     io_system)
        expect(count).to eq(2)
      ensure
        hlp_file.unlink
        FileUtils.rm_rf(output_dir)
      end
    end
  end
end
