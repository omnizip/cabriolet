# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require_relative "../support/fixtures"

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
    it "creates a minimal valid LIT file" do
      Dir.mktmpdir do |dir|
        source = File.join(dir, "test.txt")
        output = File.join(dir, "test.lit")
        File.write(source, "Hello World")

        compressor.add_file(source, "test.txt")

        bytes_written = compressor.generate(output)

        expect(bytes_written).to be > 0
        expect(File.exist?(output)).to be true
        expect(File.size(output)).to be > 0
      end
    end

    it "creates LIT file with uncompressed files" do
      Dir.mktmpdir do |dir|
        source = File.join(dir, "test.txt")
        output = File.join(dir, "test.lit")
        File.write(source, "Hello World")

        compressor.add_file(source, "test.txt", compress: false)

        bytes_written = compressor.generate(output)

        expect(bytes_written).to be > 0
        expect(File.exist?(output)).to be true
      end
    end

    it "creates LIT file with multiple files" do
      Dir.mktmpdir do |dir|
        file1 = File.join(dir, "file1.txt")
        file2 = File.join(dir, "file2.txt")
        output = File.join(dir, "test.lit")
        File.write(file1, "Content 1")
        File.write(file2, "Content 2")

        compressor.add_file(file1, "file1.txt")
        compressor.add_file(file2, "file2.txt")

        bytes_written = compressor.generate(output)

        expect(bytes_written).to be > 0
        expect(File.exist?(output)).to be true
      end
    end
  end

  describe "round-trip compression" do
    it "compresses and decompresses data correctly" do
      Dir.mktmpdir do |dir|
        # Create source files
        source1 = File.join(dir, "test1.txt")
        source2 = File.join(dir, "test2.html")
        File.write(source1, "Hello World from LIT compression!")
        File.write(source2, "<html><body>Test HTML</body></html>")

        # Compress into LIT file
        lit_file = File.join(dir, "test.lit")
        compressor.add_file(source1, "test1.txt")
        compressor.add_file(source2, "test2.html")
        bytes_written = compressor.generate(lit_file)

        expect(bytes_written).to be > 0
        expect(File.exist?(lit_file)).to be true

        # Decompress the LIT file
        decompressor = Cabriolet::LIT::Decompressor.new(io_system)
        lit_header = decompressor.open(lit_file)

        expect(lit_header).not_to be_nil
        expect(lit_header.directory).not_to be_nil
        expect(lit_header.directory.entries.size).to be >= 2

        # Extract files
        output_dir = File.join(dir, "output")
        FileUtils.mkdir_p(output_dir)

        # Find and extract test1.txt
        entry1 = lit_header.directory.entries.find { |e| e.name == "test1.txt" }
        expect(entry1).not_to be_nil

        output1 = File.join(output_dir, "test1.txt")
        decompressor.extract_file(lit_header, "test1.txt", output1)

        expect(File.exist?(output1)).to be true
        extracted_content1 = File.read(output1)
        expect(extracted_content1).to eq("Hello World from LIT compression!")

        # Find and extract test2.html
        entry2 = lit_header.directory.entries.find do |e|
          e.name == "test2.html"
        end
        expect(entry2).not_to be_nil

        output2 = File.join(output_dir, "test2.html")
        decompressor.extract_file(lit_header, "test2.html", output2)

        expect(File.exist?(output2)).to be true
        extracted_content2 = File.read(output2)
        expect(extracted_content2).to eq("<html><body>Test HTML</body></html>")

        decompressor.close(lit_header)
      end
    end
  end

  describe "fixture compatibility" do
    let(:decompressor) { Cabriolet::LIT::Decompressor.new(io_system) }

    context "can decompress real LIT fixture files" do
      it "opens all LIT fixture files" do
        all_fixtures = Fixtures.for(:lit).scenario(:all)

        all_fixtures.each do |fixture_path|
          lit_header = decompressor.open(fixture_path)
          expect(lit_header).to be_a(Cabriolet::Models::LITFile)
          decompressor.close(lit_header)
        end
      end
    end

    context "creates compatible files" do
      it "generates files that decompressor can parse" do
        Dir.mktmpdir do |tmpdir|
          source = File.join(tmpdir, "test.txt")
          output = File.join(tmpdir, "test.lit")
          File.write(source, "LIT fixture compatibility test")

          compressor.add_file(source, "test.txt")
          compressor.generate(output)

          # Verify decompressor can parse it
          lit_header = decompressor.open(output)
          expect(lit_header).to be_a(Cabriolet::Models::LITFile)
          expect(lit_header.directory.entries).not_to be_empty

          decompressor.close(lit_header)
        end
      end
    end
  end
end
