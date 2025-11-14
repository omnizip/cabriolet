# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Cabriolet::SZDD::Compressor do
  let(:compressor) { described_class.new }
  let(:decompressor) { Cabriolet::SZDD::Decompressor.new }

  describe "#initialize" do
    it "creates a compressor with default IO system" do
      expect(compressor.io_system).to be_a(Cabriolet::System::IOSystem)
    end

    it "accepts a custom IO system" do
      custom_io = Cabriolet::System::IOSystem.new
      compressor = described_class.new(custom_io)
      expect(compressor.io_system).to eq(custom_io)
    end
  end

  describe "#compress_data" do
    let(:temp_output) { Tempfile.new(["test", ".tx_"]) }

    after do
      temp_output.close
      temp_output.unlink
    end

    context "with simple data" do
      it "compresses data to SZDD format" do
        data = "Hello, world!"
        bytes = compressor.compress_data(data, temp_output.path)

        expect(bytes).to be > 0
        expect(File.exist?(temp_output.path)).to be true
        expect(File.size(temp_output.path)).to eq(bytes)
      end

      it "creates valid SZDD file with NORMAL format" do
        data = "Hello, world!"
        compressor.compress_data(data, temp_output.path, format: :normal)

        # Verify header
        header = decompressor.open(temp_output.path)
        expect(header.format).to eq(:normal)
        expect(header.length).to eq(data.bytesize)
      end

      it "creates valid SZDD file with QBASIC format" do
        data = "Hello, world!"
        compressor.compress_data(data, temp_output.path, format: :qbasic)

        # Verify header
        header = decompressor.open(temp_output.path)
        expect(header.format).to eq(:qbasic)
        expect(header.length).to eq(data.bytesize)
      end
    end

    context "with missing character" do
      it "stores missing character in header" do
        data = "Test data"
        compressor.compress_data(data, temp_output.path,
                                 missing_char: "t")

        header = decompressor.open(temp_output.path)
        expect(header.missing_char).to eq("t")
      end

      it "validates missing character is single character" do
        expect do
          compressor.compress_data("data", temp_output.path,
                                   missing_char: "ab")
        end.to raise_error(ArgumentError, /single character/)
      end
    end

    context "round-trip compression" do
      it "compresses and decompresses simple text correctly" do
        original = "Hello, world!"
        compressor.compress_data(original, temp_output.path)

        header = decompressor.open(temp_output.path)
        decompressed = decompressor.extract_to_memory(header)

        expect(decompressed).to eq(original)
      end

      it "handles repeated text" do
        original = "Hello, world! " * 100
        compressor.compress_data(original, temp_output.path)

        header = decompressor.open(temp_output.path)
        decompressed = decompressor.extract_to_memory(header)

        expect(decompressed).to eq(original)
      end

      it "handles binary data" do
        original = (0..255).to_a.pack("C*") * 10
        compressor.compress_data(original, temp_output.path)

        header = decompressor.open(temp_output.path)
        decompressed = decompressor.extract_to_memory(header)

        expect(decompressed).to eq(original)
      end

      it "works with NORMAL format" do
        original = "NORMAL format test " * 50
        compressor.compress_data(original, temp_output.path, format: :normal)

        header = decompressor.open(temp_output.path)
        decompressed = decompressor.extract_to_memory(header)

        expect(header.format).to eq(:normal)
        expect(decompressed).to eq(original)
      end

      it "works with QBASIC format" do
        original = "QBASIC format test " * 50
        compressor.compress_data(original, temp_output.path, format: :qbasic)

        header = decompressor.open(temp_output.path)
        decompressed = decompressor.extract_to_memory(header)

        expect(header.format).to eq(:qbasic)
        expect(decompressed).to eq(original)
      end
    end

    context "with empty data" do
      it "compresses empty data" do
        original = ""
        compressor.compress_data(original, temp_output.path)

        header = decompressor.open(temp_output.path)
        expect(header.length).to eq(0)

        decompressed = decompressor.extract_to_memory(header)
        expect(decompressed).to eq(original)
      end
    end

    context "with large data" do
      it "handles data larger than window size" do
        original = "A" * 10_000
        compressor.compress_data(original, temp_output.path)

        header = decompressor.open(temp_output.path)
        decompressed = decompressor.extract_to_memory(header)

        expect(decompressed).to eq(original)
      end

      it "compresses repetitive data efficiently" do
        original = "ABCD" * 1000
        bytes = compressor.compress_data(original, temp_output.path)

        # Compressed should be smaller than original for repetitive data
        expect(bytes).to be < original.bytesize
      end
    end
  end

  describe "#compress" do
    let(:temp_input) { Tempfile.new(["input", ".txt"]) }
    let(:temp_output) { Tempfile.new(["output", ".tx_"]) }

    after do
      temp_input.close
      temp_input.unlink
      temp_output.close
      temp_output.unlink
    end

    it "compresses a file to SZDD format" do
      temp_input.write("File content here")
      temp_input.close

      bytes = compressor.compress(temp_input.path, temp_output.path)

      expect(bytes).to be > 0
      expect(File.exist?(temp_output.path)).to be true
    end

    it "performs round-trip file compression" do
      original = "This is a test file content. " * 20
      temp_input.write(original)
      temp_input.close

      compressor.compress(temp_input.path, temp_output.path)

      header = decompressor.open(temp_output.path)
      decompressed = decompressor.extract_to_memory(header)

      expect(decompressed).to eq(original)
    end

    it "accepts format option" do
      temp_input.write("Test")
      temp_input.close

      compressor.compress(temp_input.path, temp_output.path, format: :qbasic)

      header = decompressor.open(temp_output.path)
      expect(header.format).to eq(:qbasic)
    end

    it "accepts missing_char option" do
      temp_input.write("Test")
      temp_input.close

      compressor.compress(temp_input.path, temp_output.path, missing_char: "x")

      header = decompressor.open(temp_output.path)
      expect(header.missing_char).to eq("x")
    end

    it "validates format parameter" do
      temp_input.write("Test")
      temp_input.close

      expect do
        compressor.compress(temp_input.path, temp_output.path, format: :invalid)
      end.to raise_error(ArgumentError, /Format must be/)
    end
  end

  describe "error handling" do
    it "raises error for invalid format" do
      expect do
        compressor.compress_data("data", "output.tx_", format: :bad)
      end.to raise_error(ArgumentError, /Format must be/)
    end

    it "raises error for invalid missing_char" do
      expect do
        compressor.compress_data("data", "output.tx_", missing_char: "ab")
      end.to raise_error(ArgumentError, /single character/)
    end

    it "raises error for non-string missing_char" do
      expect do
        compressor.compress_data("data", "output.tx_", missing_char: 123)
      end.to raise_error(ArgumentError, /single character/)
    end
  end

  describe "integration with existing SZDD files" do
    let(:fixture_dir) { File.join(__dir__, "..", "fixtures", "szdd") }

    # Test that our compressor creates files compatible with the decompressor
    it "creates files that match expected structure" do
      temp_output = Tempfile.new(["test", ".tx_"])

      begin
        original = "Test data for validation"
        compressor.compress_data(original, temp_output.path)

        # Read raw file to check structure
        data = File.binread(temp_output.path)

        # Check signature
        expect(data[0, 4]).to eq("SZDD")
        expect(data[4, 4]).to eq("\x88\xF0\x27\x33".b)

        # Check compression mode
        expect(data[8].ord).to eq(0x41) # 'A'

        # Check uncompressed size (little-endian)
        size = data[10, 4].unpack1("V")
        expect(size).to eq(original.bytesize)
      ensure
        temp_output.close
        temp_output.unlink
      end
    end
  end
end
