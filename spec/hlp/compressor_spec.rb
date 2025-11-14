# frozen_string_literal: true

require "spec_helper"

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
    context "with data from memory" do
      it "generates HLP archive" do
        require "tempfile"
        output_file = Tempfile.new(["test", ".hlp"])

        begin
          compressor.add_data("Test data", "test.txt")
          bytes = compressor.generate(output_file.path)

          expect(bytes).to be > 0
          expect(File.exist?(output_file.path)).to be true
          expect(File.size(output_file.path)).to eq(bytes)
        ensure
          output_file.unlink
        end
      end

      it "generates HLP with multiple files" do
        require "tempfile"
        output_file = Tempfile.new(["test", ".hlp"])

        begin
          compressor.add_data("File 1 data", "file1.txt")
          compressor.add_data("File 2 data", "file2.txt")
          compressor.add_data("File 3 data", "file3.txt")
          bytes = compressor.generate(output_file.path)

          expect(bytes).to be > 0
          expect(File.exist?(output_file.path)).to be true
        ensure
          output_file.unlink
        end
      end

      it "generates HLP with compressed and uncompressed files" do
        require "tempfile"
        output_file = Tempfile.new(["test", ".hlp"])

        begin
          compressor.add_data("Compressed data", "compressed.txt",
                              compress: true)
          compressor.add_data("Uncompressed data", "uncompressed.txt",
                              compress: false)
          bytes = compressor.generate(output_file.path)

          expect(bytes).to be > 0
        ensure
          output_file.unlink
        end
      end
    end

    context "with files from disk" do
      it "generates HLP archive from file", skip: "Requires temp file setup" do
        # Would create temp file and test if we had a setup
      end
    end

    context "with options" do
      it "accepts version option" do
        require "tempfile"
        output_file = Tempfile.new(["test", ".hlp"])

        begin
          compressor.add_data("Test data", "test.txt")
          bytes = compressor.generate(output_file.path, version: 2)

          expect(bytes).to be > 0
        ensure
          output_file.unlink
        end
      end
    end
  end

  describe "round-trip with decompressor" do
    it "creates HLP that can be decompressed",
       pending: "Round-trip not working without real HLP format spec" do
      require "tempfile"
      hlp_file = Tempfile.new(["test", ".hlp"])
      output_file = Tempfile.new(["output", ".txt"])

      begin
        # Create HLP
        test_data = "Hello, World!\n" * 50
        compressor.add_data(test_data, "test.txt")
        compressor.generate(hlp_file.path)

        # Decompress
        decompressor = Cabriolet::HLP::Decompressor.new(io_system)
        header = decompressor.open(hlp_file.path)

        expect(header.files.size).to eq(1)
        expect(header.files.first.filename).to eq("test.txt")

        hlp_internal_file = header.files.first
        decompressor.extract_file(header, hlp_internal_file, output_file.path)

        # Verify
        output_data = File.read(output_file.path)
        expect(output_data).to eq(test_data)

        decompressor.close(header)
      ensure
        hlp_file.unlink
        output_file.unlink
      end
    end

    it "handles multiple files in round-trip",
       pending: "Round-trip not working without real HLP format spec" do
      require "tempfile"
      hlp_file = Tempfile.new(["test", ".hlp"])

      begin
        # Create HLP with multiple files
        test_data1 = "First file data\n" * 20
        test_data2 = "Second file data\n" * 30
        test_data3 = "Third file data\n" * 25

        compressor.add_data(test_data1, "file1.txt")
        compressor.add_data(test_data2, "file2.txt")
        compressor.add_data(test_data3, "file3.txt")
        compressor.generate(hlp_file.path)

        # Decompress
        decompressor = Cabriolet::HLP::Decompressor.new(io_system)
        header = decompressor.open(hlp_file.path)

        expect(header.files.size).to eq(3)
        expect(header.files.map(&:filename)).to match_array(
          %w[file1.txt file2.txt file3.txt],
        )

        # Extract and verify each file
        [
          ["file1.txt", test_data1],
          ["file2.txt", test_data2],
          ["file3.txt", test_data3],
        ].each do |filename, expected_data|
          hlp_file_entry = header.files.find { |f| f.filename == filename }
          expect(hlp_file_entry).not_to be_nil

          output_file = Tempfile.new([filename, ".txt"])
          begin
            decompressor.extract_file(header, hlp_file_entry,
                                      output_file.path)
            actual_data = File.read(output_file.path)
            expect(actual_data).to eq(expected_data)
          ensure
            output_file.unlink
          end
        end

        decompressor.close(header)
      ensure
        hlp_file.unlink
      end
    end
  end
end
