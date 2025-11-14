# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Cabriolet::LIT::Compressor do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:compressor) { described_class.new(io_system) }

  describe "#initialize" do
    it "creates a compressor with default I/O system" do
      comp = described_class.new
      expect(comp.io_system).to be_a(Cabriolet::System::IOSystem)
      expect(comp.files).to eq([])
    end

    it "creates a compressor with custom I/O system" do
      custom_io = Cabriolet::System::IOSystem.new
      comp = described_class.new(custom_io)
      expect(comp.io_system).to eq(custom_io)
    end
  end

  describe "#add_file" do
    it "adds a file to the archive" do
      Dir.mktmpdir do |dir|
        source = File.join(dir, "test.txt")
        File.write(source, "test content")

        compressor.add_file(source, "test.txt")

        expect(compressor.files.size).to eq(1)
        expect(compressor.files.first[:source]).to eq(source)
        expect(compressor.files.first[:lit_path]).to eq("test.txt")
        expect(compressor.files.first[:compress]).to be true
      end
    end

    it "adds a file without compression" do
      Dir.mktmpdir do |dir|
        source = File.join(dir, "test.txt")
        File.write(source, "test content")

        compressor.add_file(source, "test.txt", compress: false)

        expect(compressor.files.size).to eq(1)
        expect(compressor.files.first[:compress]).to be false
      end
    end

    it "adds multiple files" do
      Dir.mktmpdir do |dir|
        file1 = File.join(dir, "file1.txt")
        file2 = File.join(dir, "file2.txt")
        File.write(file1, "content 1")
        File.write(file2, "content 2")

        compressor.add_file(file1, "file1.txt")
        compressor.add_file(file2, "file2.txt")

        expect(compressor.files.size).to eq(2)
      end
    end
  end

  describe "#generate" do
    it "raises error when no files added" do
      Dir.mktmpdir do |dir|
        output = File.join(dir, "test.lit")

        expect { compressor.generate(output) }.to raise_error(
          ArgumentError,
          /No files added to archive/,
        )
      end
    end

    it "raises NotImplementedError when encryption requested" do
      Dir.mktmpdir do |dir|
        source = File.join(dir, "test.txt")
        output = File.join(dir, "test.lit")
        File.write(source, "test")

        compressor.add_file(source, "test.txt")

        expect { compressor.generate(output, encrypt: true) }.to raise_error(
          NotImplementedError,
          /DES encryption is not implemented/,
        )
      end
    end

    it "creates a LIT file with single uncompressed file" do
      Dir.mktmpdir do |dir|
        source = File.join(dir, "test.txt")
        output = File.join(dir, "test.lit")
        File.write(source, "Hello World")

        compressor.add_file(source, "test.txt", compress: false)
        bytes = compressor.generate(output)

        expect(bytes).to be > 0
        expect(File.exist?(output)).to be true
      end
    end

    it "creates a LIT file with single compressed file",
       skip: "LZX compressor integration needed" do
      # Would test compression if LZX compressor is fully integrated
    end

    it "creates a LIT file with multiple files",
       skip: "Full round-trip testing needed" do
      # Would test multi-file archives with round-trip verification
    end
  end

  describe "round-trip compression" do
    it "compresses and decompresses data correctly",
       skip: "No LIT test fixtures for verification" do
      # Would test: create LIT → extract → verify content matches
    end
  end
end
