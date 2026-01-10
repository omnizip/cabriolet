# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Cabriolet::HLP::Decompressor do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:decompressor) { described_class.new(io_system) }

  describe "#initialize" do
    it "creates a new decompressor" do
      expect(decompressor).to be_a(described_class)
    end

    it "uses default IO system when none provided" do
      dec = described_class.new
      expect(dec.io_system).to be_a(Cabriolet::System::IOSystem)
    end

    it "uses provided IO system" do
      expect(decompressor.io_system).to eq(io_system)
    end

    it "creates a parser" do
      expect(decompressor.parser).to be_a(Cabriolet::HLP::Parser)
    end
  end

  describe "#open" do
    context "with WinHelp file" do
      it "opens and parses WinHelp 4.x file" do
        fixture_path = File.join(__dir__, "..", "fixtures", "masm32_hlp", "SE.HLP")
        skip "Fixture not found" unless File.exist?(fixture_path)

        header = decompressor.open(fixture_path)
        expect(header).to be_a(Cabriolet::Models::WinHelpHeader)
        decompressor.close(header)
      end

      it "sets filename in header" do
        fixture_path = File.join(__dir__, "..", "fixtures", "masm32_hlp", "SE.HLP")
        skip "Fixture not found" unless File.exist?(fixture_path)

        header = decompressor.open(fixture_path)
        expect(header.filename).to eq(fixture_path)
        decompressor.close(header)
      end
    end

    context "with QuickHelp file (generated)" do
      let(:compressor) { Cabriolet::HLP::Compressor.new(io_system) }

      around do |example|
        Dir.mktmpdir do |tmpdir|
          @tmpdir = tmpdir
          example.run
        end
      end

      it "opens and parses generated QuickHelp file" do
        # Generate a QuickHelp file
        compressor.add_data("Test content", "test.txt")
        output_file = File.join(@tmpdir, "test.hlp")
        compressor.generate(output_file)

        # Open and parse it
        header = decompressor.open(output_file)
        expect(header).to be_a(Cabriolet::Models::HLPHeader)
        expect(header.topics).not_to be_empty
        decompressor.close(header)
      end

      it "extracts content from generated QuickHelp file" do
        # Generate a QuickHelp file
        compressor.add_data("Hello, QuickHelp World!", "test.txt")
        output_file = File.join(@tmpdir, "test.hlp")
        compressor.generate(output_file)

        # Open and extract
        header = decompressor.open(output_file)
        topic = header.topics.first
        content = decompressor.extract_file_to_memory(header, topic)
        expect(content).to eq("Hello, QuickHelp World!")
        decompressor.close(header)
      end
    end

    context "with invalid file" do
      it "raises ParseError for non-existent file" do
        expect do
          decompressor.open("nonexistent.hlp")
        end.to raise_error(Cabriolet::Error)
      end
    end
  end

  describe "#close" do
    it "closes header without error" do
      header = Cabriolet::Models::HLPHeader.new
      expect { decompressor.close(header) }.not_to raise_error
    end

    it "returns nil" do
      header = Cabriolet::Models::HLPHeader.new
      expect(decompressor.close(header)).to be_nil
    end
  end

  describe "#extract_file" do
    it "raises ArgumentError when header is nil" do
      file = Cabriolet::Models::HLPFile.new
      expect do
        decompressor.extract_file(nil, file, "output.txt")
      end.to raise_error(ArgumentError, /Header must not be nil/)
    end

    it "raises ArgumentError when hlp_file is nil" do
      header = Cabriolet::Models::HLPHeader.new
      expect do
        decompressor.extract_file(header, nil, "output.txt")
      end.to raise_error(ArgumentError, /HLP file must not be nil/)
    end

    it "raises ArgumentError when output_path is nil" do
      header = Cabriolet::Models::HLPHeader.new
      file = Cabriolet::Models::HLPFile.new
      expect do
        decompressor.extract_file(header, file, nil)
      end.to raise_error(ArgumentError, /Output path must not be nil/)
    end

    context "with generated QuickHelp file" do
      let(:compressor) { Cabriolet::HLP::Compressor.new(io_system) }

      around do |example|
        Dir.mktmpdir do |tmpdir|
          @tmpdir = tmpdir
          example.run
        end
      end

      it "extracts file to disk" do
        # Generate a QuickHelp file
        compressor.add_data("Extracted content", "test.txt")
        output_file = File.join(@tmpdir, "test.hlp")
        compressor.generate(output_file)

        # Open and extract to file
        header = decompressor.open(output_file)
        topic = header.topics.first

        output_txt = File.join(@tmpdir, "output.txt")
        bytes = decompressor.extract_file(header, topic, output_txt)

        expect(bytes).to eq(17)
        expect(File.exist?(output_txt)).to be true
        expect(File.read(output_txt)).to eq("Extracted content")

        decompressor.close(header)
      end
    end
  end

  describe "#extract_file_to_memory" do
    it "raises ArgumentError when header is nil" do
      file = Cabriolet::Models::HLPFile.new
      expect do
        decompressor.extract_file_to_memory(nil, file)
      end.to raise_error(ArgumentError, /Header must not be nil/)
    end

    it "raises ArgumentError when hlp_file is nil" do
      header = Cabriolet::Models::HLPHeader.new
      expect do
        decompressor.extract_file_to_memory(header, nil)
      end.to raise_error(ArgumentError, /HLP file must not be nil/)
    end

    context "with generated QuickHelp file" do
      let(:compressor) { Cabriolet::HLP::Compressor.new(io_system) }

      around do |example|
        Dir.mktmpdir do |tmpdir|
          @tmpdir = tmpdir
          example.run
        end
      end

      it "extracts file to memory" do
        # Generate a QuickHelp file
        compressor.add_data("Memory content", "test.txt")
        output_file = File.join(@tmpdir, "test.hlp")
        compressor.generate(output_file)

        # Open and extract to memory
        header = decompressor.open(output_file)
        topic = header.topics.first
        content = decompressor.extract_file_to_memory(header, topic)

        expect(content).to be_a(String)
        expect(content).to eq("Memory content")

        decompressor.close(header)
      end
    end
  end

  describe "#extract_all" do
    it "raises ArgumentError when header is nil" do
      expect do
        decompressor.extract_all(nil, "output_dir")
      end.to raise_error(ArgumentError, /Header must not be nil/)
    end

    it "raises ArgumentError when output_dir is nil" do
      header = Cabriolet::Models::HLPHeader.new
      expect do
        decompressor.extract_all(header, nil)
      end.to raise_error(ArgumentError, /Output directory must not be nil/)
    end

    context "with generated QuickHelp file" do
      let(:compressor) { Cabriolet::HLP::Compressor.new(io_system) }

      around do |example|
        Dir.mktmpdir do |tmpdir|
          @tmpdir = tmpdir
          example.run
        end
      end

      it "extracts all files to directory" do
        # Generate a QuickHelp file with multiple topics
        compressor.add_data("Content 1", "file1.txt")
        compressor.add_data("Content 2", "file2.txt")
        output_file = File.join(@tmpdir, "test.hlp")
        compressor.generate(output_file)

        # Extract all
        header = decompressor.open(output_file)
        output_dir = File.join(@tmpdir, "output")
        Dir.mkdir(output_dir)
        decompressor.extract_all(header, output_dir)

        # Verify
        expect(Dir.children(output_dir).size).to eq(2)

        decompressor.close(header)
      end
    end
  end

  describe "round-trip compression/decompression" do
    let(:compressor) { Cabriolet::HLP::Compressor.new(io_system) }

    around do |example|
      Dir.mktmpdir do |tmpdir|
        @tmpdir = tmpdir
        example.run
      end
    end

    it "compresses and decompresses data correctly" do
      # Generate a QuickHelp file
      original_data = "Round-trip test data"
      compressor.add_data(original_data, "test.txt")
      output_file = File.join(@tmpdir, "test.hlp")
      compressor.generate(output_file)

      # Decompress it
      header = decompressor.open(output_file)
      topic = header.topics.first
      decompressed = decompressor.extract_file_to_memory(header, topic)

      # Verify
      expect(decompressed).to eq(original_data)

      decompressor.close(header)
    end

    it "handles multiple files in round-trip" do
      # Generate a QuickHelp file with multiple files
      compressor.add_data("First content", "file1.txt")
      compressor.add_data("Second content", "file2.txt")
      output_file = File.join(@tmpdir, "test.hlp")
      compressor.generate(output_file)

      # Decompress all
      header = decompressor.open(output_file)
      header.topics.each_with_index do |topic, index|
        content = decompressor.extract_file_to_memory(header, topic)
        expect(content).to eq(["First content", "Second content"][index])
      end

      decompressor.close(header)
    end
  end
end
