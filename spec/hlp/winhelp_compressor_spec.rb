# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Cabriolet::HLP::WinHelp::Compressor do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:compressor) { described_class.new(io_system) }

  describe "#initialize" do
    it "creates compressor with default IO system" do
      compressor = described_class.new
      expect(compressor.io_system).to be_a(Cabriolet::System::IOSystem)
    end

    it "accepts custom IO system" do
      custom_io = Cabriolet::System::IOSystem.new
      compressor = described_class.new(custom_io)
      expect(compressor.io_system).to eq(custom_io)
    end
  end

  describe "#add_internal_file" do
    it "adds an internal file" do
      compressor.add_internal_file("|SYSTEM", "system data")
      # Verify by generating
      file = Tempfile.new(["test", ".hlp"])
      begin
        expect { compressor.generate(file.path) }.not_to raise_error
      ensure
        file.unlink
      end
    end
  end

  describe "#add_system_file" do
    it "adds system file with title" do
      compressor.add_system_file(title: "Test Help")

      file = Tempfile.new(["test", ".hlp"])
      begin
        bytes = compressor.generate(file.path)
        expect(bytes).to be > 0
      ensure
        file.unlink
      end
    end

    it "adds system file with multiple options" do
      compressor.add_system_file(
        title: "Test Help",
        copyright: "Copyright 2025",
        contents: "contents.hlp",
      )

      file = Tempfile.new(["test", ".hlp"])
      begin
        bytes = compressor.generate(file.path)
        expect(bytes).to be > 0
      ensure
        file.unlink
      end
    end
  end

  describe "#add_topic_file" do
    it "adds topic file with simple text" do
      compressor.add_system_file(title: "Test")
      compressor.add_topic_file(["Topic 1", "Topic 2"])

      file = Tempfile.new(["test", ".hlp"])
      begin
        bytes = compressor.generate(file.path)
        expect(bytes).to be > 0
      ensure
        file.unlink
      end
    end
  end

  describe "#generate" do
    context "with WinHelp 3.x format" do
      it "generates valid WinHelp 3.x file" do
        compressor.add_system_file(title: "Test Help 3.x")
        compressor.add_topic_file(["Test Topic"])

        file = Tempfile.new(["winhelp3", ".hlp"])
        begin
          bytes = compressor.generate(file.path, version: :winhelp3)

          # Verify file was created
          expect(File.exist?(file.path)).to be true
          expect(File.size(file.path)).to eq(bytes)

          # Verify header magic
          File.open(file.path, "rb") do |f|
            magic = f.read(2).unpack1("v")
            expect(magic).to eq(0x35F3)
          end
        ensure
          file.unlink
        end
      end

      it "generates file with correct directory" do
        compressor.add_internal_file("|SYSTEM", "system")
        compressor.add_internal_file("|TOPIC", "topic")

        file = Tempfile.new(["winhelp3_dir", ".hlp"])
        begin
          compressor.generate(file.path, version: :winhelp3)

          # Parse and verify
          decompressor = Cabriolet::HLP::WinHelp::Decompressor.new(file.path, io_system)
          header = decompressor.parse

          expect(header.internal_filenames).to include("|SYSTEM", "|TOPIC")
        ensure
          file.unlink
        end
      end
    end

    context "with WinHelp 4.x format" do
      it "generates valid WinHelp 4.x file" do
        compressor.add_system_file(title: "Test Help 4.x")
        compressor.add_topic_file(["Test Topic"])

        file = Tempfile.new(["winhelp4", ".hlp"])
        begin
          bytes = compressor.generate(file.path, version: :winhelp4)

          # Verify file was created
          expect(File.exist?(file.path)).to be true
          expect(File.size(file.path)).to eq(bytes)

          # Verify header magic
          File.open(file.path, "rb") do |f|
            magic = f.read(4).unpack1("V")
            expect(magic & 0xFFFF).to eq(0x3F5F)
          end
        ensure
          file.unlink
        end
      end
    end

    context "error handling" do
      it "raises error when no files added" do
        file = Tempfile.new(["empty", ".hlp"])
        begin
          expect { compressor.generate(file.path) }.to raise_error(ArgumentError, /No internal files/)
        ensure
          file.unlink
        end
      end

      it "raises error for invalid version" do
        compressor.add_system_file(title: "Test")

        file = Tempfile.new(["invalid", ".hlp"])
        begin
          expect do
            compressor.generate(file.path, version: :invalid)
          end.to raise_error(ArgumentError, /Invalid version/)
        ensure
          file.unlink
        end
      end
    end

    context "round-trip testing" do
      it "creates file that can be parsed" do
        compressor.add_system_file(title: "Round Trip Test")
        compressor.add_topic_file(["Topic 1", "Topic 2"])

        file = Tempfile.new(["roundtrip", ".hlp"])
        begin
          compressor.generate(file.path)

          # Parse it back
          decompressor = Cabriolet::HLP::WinHelp::Decompressor.new(file.path, io_system)
          header = decompressor.parse

          expect(header.version).to eq(:winhelp3)
          expect(header.internal_files.length).to eq(2)
        ensure
          file.unlink
        end
      end
    end
  end
end
