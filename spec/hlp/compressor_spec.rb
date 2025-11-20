# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "tempfile"

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
    it "creates HLP that can be decompressed",
       skip: "QuickHelp decompressor needs parser.rb adjustment for generated files" do
      # Will work after parser adjustment
    end

    it "handles multiple files in round-trip",
       skip: "QuickHelp decompressor needs parser.rb adjustment for generated files" do
      # Will work after parser adjustment
    end
  end
end
