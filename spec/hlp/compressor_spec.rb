# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "tempfile"
require_relative "../support/fixtures"

RSpec.describe Cabriolet::HLP::Compressor do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:compressor) { described_class.new(io_system) }

  describe "#initialize" do
    it "creates a new compressor" do
      expect(compressor).to be_a(described_class)
    end

    it "uses default IO system when none provided" do
      comp = described_class.new
      expect(comp.io_system).to be_a(Cabriolet::System::IOSystem)
    end

    it "uses provided IO system" do
      expect(compressor.io_system).to eq(io_system)
    end
  end

  describe "#add_file" do
    it "adds a file to the archive" do
      expect { compressor.add_file("test.txt", "test.txt") }
        .not_to raise_error
    end

    it "allows specifying compression flag" do
      expect { compressor.add_file("test.txt", "test.txt", compress: false) }
        .not_to raise_error
    end
  end

  describe "#add_data" do
    it "adds data to the archive" do
      expect { compressor.add_data("test data", "test.txt") }
        .not_to raise_error
    end

    it "allows specifying compression flag" do
      expect { compressor.add_data("test data", "test.txt", compress: false) }
        .not_to raise_error
    end
  end

  describe "#generate" do
    describe "with data from memory" do
      it "creates a QuickHelp file" do
        output_file = Tempfile.new(["test", ".hlp"])
        begin
          compressor.add_data("Hello QuickHelp!", "topic1")

          bytes_written = compressor.generate(output_file.path)

          expect(bytes_written).to be > 0
          expect(File.exist?(output_file.path)).to be true
          expect(File.size(output_file.path)).to be > 0
        ensure
          output_file.close
          output_file.unlink
        end
      end

      it "creates QuickHelp file with multiple files" do
        output_file = Tempfile.new(["test", ".hlp"])
        begin
          compressor.add_data("Topic 1 text", "topic1")
          compressor.add_data("Topic 2 text", "topic2")

          bytes_written = compressor.generate(output_file.path)

          expect(bytes_written).to be > 0
          expect(File.exist?(output_file.path)).to be true
        ensure
          output_file.close
          output_file.unlink
        end
      end

      it "creates QuickHelp file with compression options" do
        output_file = Tempfile.new(["test", ".hlp"])
        begin
          compressor.add_data("Test content", "topic1", compress: true)

          bytes_written = compressor.generate(output_file.path, database_name: "TestDB")

          expect(bytes_written).to be > 0
          expect(File.exist?(output_file.path)).to be true
        ensure
          output_file.close
          output_file.unlink
        end
      end
    end

    describe "with files from disk" do
      it "generates HLP archive from file" do
        require "tmpdir"
        Dir.mktmpdir do |dir|
          source = File.join(dir, "test.txt")
          output = File.join(dir, "test.hlp")
          File.write(source, "Hello from file!")

          compressor.add_file(source, "topic1")
          bytes_written = compressor.generate(output)

          expect(bytes_written).to be > 0
          expect(File.exist?(output)).to be true
        end
      end
    end

    describe "with options" do
      it "accepts version option" do
        output_file = Tempfile.new(["test", ".hlp"])
        begin
          compressor.add_data("Test", "topic1")

          bytes_written = compressor.generate(output_file.path, version: 2)

          expect(bytes_written).to be > 0
        ensure
          output_file.close
          output_file.unlink
        end
      end
    end
  end

  describe "round-trip with decompressor" do
    let(:io_system) { Cabriolet::System::IOSystem.new }
    let(:compressor) { described_class.new(io_system) }
    let(:decompressor) { Cabriolet::HLP::Decompressor.new(io_system) }

    around do |example|
      Dir.mktmpdir do |tmpdir|
        @tmpdir = tmpdir
        example.run
      end
    end

    it "creates HLP that can be decompressed" do
      compressor.add_data("Hello, World!", "test.txt")

      output_file = File.join(@tmpdir, "test.hlp")
      compressor.generate(output_file)

      header = decompressor.open(output_file)
      expect(header).to be_a(Cabriolet::Models::HLPHeader)
      expect(header.topics).not_to be_empty

      topic = header.topics.first
      content = decompressor.extract_file_to_memory(header, topic)
      expect(content).to eq("Hello, World!")

      decompressor.close(header)
    end

    it "handles multiple files in round-trip" do
      compressor.add_data("Content 1", "file1.txt")
      compressor.add_data("Content 2", "file2.txt")

      output_file = File.join(@tmpdir, "multi.hlp")
      compressor.generate(output_file)

      header = decompressor.open(output_file)
      expect(header.topics.size).to eq(2)

      header.topics.each_with_index do |topic, index|
        content = decompressor.extract_file_to_memory(header, topic)
        expect(content).to eq("Content #{index + 1}")
      end

      decompressor.close(header)
    end
  end

  describe "fixture compatibility" do
    let(:io_system) { Cabriolet::System::IOSystem.new }
    let(:decompressor) { Cabriolet::HLP::Decompressor.new(io_system) }

    context "can open and parse fixture files" do
      it "opens all HLP fixtures" do
        all_fixtures = Fixtures.for(:hlp).scenario(:all)

        all_fixtures.each do |fixture_path|
          header = decompressor.open(fixture_path)
          expect(header).to be_a(Cabriolet::Models::HLPHeader)
          decompressor.close(header)
        end
      end
    end
  end
end
