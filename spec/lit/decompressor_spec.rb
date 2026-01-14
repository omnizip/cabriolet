# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require_relative "../support/fixtures"

RSpec.describe Cabriolet::LIT::Decompressor do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:decompressor) { described_class.new(io_system) }

  describe "#initialize" do
    it "creates a decompressor with default I/O system" do
      dec = described_class.new
      expect(dec.io_system).to be_a(Cabriolet::System::IOSystem)
      expect(dec.buffer_size).to eq(described_class::DEFAULT_BUFFER_SIZE)
    end

    it "creates a decompressor with custom I/O system" do
      custom_io = Cabriolet::System::IOSystem.new
      dec = described_class.new(custom_io)
      expect(dec.io_system).to eq(custom_io)
    end
  end

  describe "#open" do
    context "with generated LIT file" do
      let(:compressor) { Cabriolet::LIT::Compressor.new(io_system) }

      around do |example|
        Dir.mktmpdir do |tmpdir|
          @tmpdir = tmpdir
          example.run
        end
      end

      it "opens and parses generated LIT file" do
        # Create input file
        input_file = File.join(@tmpdir, "input.txt")
        File.write(input_file, "Test content")

        # Generate LIT file
        compressor.add_file(input_file, "test.txt")
        output_file = File.join(@tmpdir, "test.lit")
        compressor.generate(output_file)

        # Open and parse
        header = decompressor.open(output_file)
        expect(header).to be_a(Cabriolet::Models::LITFile)
        expect(header.directory).not_to be_nil

        decompressor.close(header)
      end
    end

    context "with invalid file" do
      it "raises error for non-existent file" do
        expect do
          decompressor.open("nonexistent.lit")
        end.to raise_error(Cabriolet::IOError)
      end
    end
  end

  describe "#close" do
    it "closes the header without error" do
      header = Cabriolet::Models::LITFile.new
      expect { decompressor.close(header) }.not_to raise_error
    end
  end

  describe "#extract" do
    it "raises error when header is nil" do
      file = Cabriolet::Models::LITFile.new
      expect { decompressor.extract(nil, file, "output.txt") }.to raise_error(
        ArgumentError,
        /Header must not be nil/,
      )
    end

    it "raises error when file is nil" do
      header = Cabriolet::Models::LITFile.new
      expect { decompressor.extract(header, nil, "output.txt") }.to raise_error(
        ArgumentError,
        /File must not be nil/,
      )
    end

    it "raises error when output path is nil" do
      header = Cabriolet::Models::LITFile.new
      file = Cabriolet::Models::LITFile.new
      expect { decompressor.extract(header, file, nil) }.to raise_error(
        ArgumentError,
        /Output path must not be nil/,
      )
    end

    it "raises NotImplementedError for encrypted files" do
      header = Cabriolet::Models::LITFile.new
      header.drm_level = 1
      file = Cabriolet::Models::LITDirectoryEntry.new
      expect do
        decompressor.extract(header, file, "output.txt")
      end.to raise_error(
        NotImplementedError,
        /Encrypted sections not yet supported/,
      )
    end

    context "with generated LIT file" do
      let(:compressor) { Cabriolet::LIT::Compressor.new(io_system) }

      around do |example|
        Dir.mktmpdir do |tmpdir|
          @tmpdir = tmpdir
          example.run
        end
      end

      it "extracts a file from generated LIT" do
        # Create input file
        input_file = File.join(@tmpdir, "input.txt")
        File.write(input_file, "Extract me!")

        # Generate LIT file
        compressor.add_file(input_file, "test.txt")
        output_file = File.join(@tmpdir, "test.lit")
        compressor.generate(output_file)

        # Open and extract
        header = decompressor.open(output_file)

        output_path = File.join(@tmpdir, "output.txt")
        bytes = decompressor.extract(header, "test.txt", output_path)

        expect(bytes).to eq(11)
        expect(File.exist?(output_path)).to be true
        expect(File.read(output_path)).to eq("Extract me!")

        decompressor.close(header)
      end
    end
  end

  describe "#extract_all" do
    it "raises error when header is nil" do
      expect do
        decompressor.extract_all(nil, ".")
      end.to raise_error(
        ArgumentError,
        /Header must not be nil/,
      )
    end

    it "raises error when output dir is nil" do
      header = Cabriolet::Models::LITFile.new
      expect do
        decompressor.extract_all(header, nil)
      end.to raise_error(
        ArgumentError,
        /Output directory must not be nil/,
      )
    end

    context "with generated LIT file" do
      let(:compressor) { Cabriolet::LIT::Compressor.new(io_system) }

      around do |example|
        Dir.mktmpdir do |tmpdir|
          @tmpdir = tmpdir
          example.run
        end
      end

      it "extracts all files from archive" do
        # Create input files
        File.write(File.join(@tmpdir, "file1.txt"), "Content 1")
        File.write(File.join(@tmpdir, "file2.txt"), "Content 2")

        # Generate LIT file
        compressor.add_file(File.join(@tmpdir, "file1.txt"), "file1.txt")
        compressor.add_file(File.join(@tmpdir, "file2.txt"), "file2.txt")
        output_file = File.join(@tmpdir, "test.lit")
        compressor.generate(output_file)

        # Open and extract all
        header = decompressor.open(output_file)
        output_dir = File.join(@tmpdir, "output")
        count = decompressor.extract_all(header, output_dir)

        # Verify specific user files exist (not internal LIT metadata)
        expect(File.exist?(File.join(output_dir, "file1.txt"))).to be true
        expect(File.exist?(File.join(output_dir, "file2.txt"))).to be true
        expect(count).to be >= 2

        decompressor.close(header)
      end
    end
  end

  describe "fixture compatibility" do
    context "with real LIT fixture files" do
      it "opens all LIT fixture files" do
        all_fixtures = Fixtures.for(:lit).scenario(:all)

        all_fixtures.each do |fixture_path|
          header = decompressor.open(fixture_path)
          expect(header).to be_a(Cabriolet::Models::LITFile)
          expect(header.directory).not_to be_nil
          expect(header.directory.entries).not_to be_empty
          decompressor.close(header)
        end
      end
    end

    context "with multiple LIT fixtures" do
      Fixtures.for(:lit).scenario(:all).each_with_index do |fixture, i|
        context "LIT fixture #{i + 1}" do
          let(:lit_fixture) { fixture }

          it "opens successfully" do
            header = decompressor.open(lit_fixture)
            expect(header).to be_a(Cabriolet::Models::LITFile)
            decompressor.close(header)
          end
        end
      end
    end
  end

  describe "round-trip compatibility" do
    let(:compressor) { Cabriolet::LIT::Compressor.new(io_system) }

    it "compresses and decompresses data correctly" do
      Dir.mktmpdir do |tmpdir|
        original_data = "Round-trip LIT test data!"

        input_file = File.join(tmpdir, "input.txt")
        File.write(input_file, original_data)

        lit_file = File.join(tmpdir, "test.lit")

        # Compress
        compressor.add_file(input_file, "input.txt")
        compressor.generate(lit_file)

        # Decompress
        header = decompressor.open(lit_file)
        output_file = File.join(tmpdir, "output.txt")
        decompressor.extract(header, "input.txt", output_file)

        expect(File.read(output_file)).to eq(original_data)

        decompressor.close(header)
      end
    end
  end
end
