# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Cabriolet::KWAJ::Compressor do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:compressor) { described_class.new(io_system) }
  let(:decompressor) { Cabriolet::KWAJ::Decompressor.new(io_system) }

  describe "#compress with NONE compression" do
    it "compresses and decompresses data correctly" do
      original_data = "Test data for KWAJ NONE compression!"

      Dir.mktmpdir do |dir|
        compressed = File.join(dir, "test.kwj")
        decompressed = File.join(dir, "test.out")

        # Compress
        bytes = compressor.compress_data(
          original_data,
          compressed,
          compression: :none,
        )

        expect(bytes).to be > 0
        expect(File.exist?(compressed)).to be true

        # Decompress and verify
        header = decompressor.open(compressed)
        expect(header.comp_type).to eq(Cabriolet::Constants::KWAJ_COMP_NONE)

        result_bytes = decompressor.extract(header, compressed, decompressed)
        expect(result_bytes).to eq(original_data.bytesize)

        result = File.read(decompressed)
        expect(result).to eq(original_data)
      end
    end

    it "handles large data with NONE compression" do
      original_data = "Large test data " * 1000

      Dir.mktmpdir do |dir|
        compressed = File.join(dir, "large.kwj")
        decompressed = File.join(dir, "large.out")

        bytes = compressor.compress_data(
          original_data,
          compressed,
          compression: :none,
        )

        expect(bytes).to be > original_data.bytesize

        header = decompressor.open(compressed)
        decompressor.extract(header, compressed, decompressed)

        result = File.read(decompressed)
        expect(result).to eq(original_data)
      end
    end
  end

  describe "#compress with XOR compression" do
    it "compresses and decompresses data correctly" do
      original_data = "Test data for KWAJ XOR compression!"

      Dir.mktmpdir do |dir|
        compressed = File.join(dir, "test.kwj")
        decompressed = File.join(dir, "test.out")

        # Compress
        bytes = compressor.compress_data(
          original_data,
          compressed,
          compression: :xor,
        )

        expect(bytes).to be > 0
        expect(File.exist?(compressed)).to be true

        # Decompress and verify
        header = decompressor.open(compressed)
        expect(header.comp_type).to eq(Cabriolet::Constants::KWAJ_COMP_XOR)

        result_bytes = decompressor.extract(header, compressed, decompressed)
        expect(result_bytes).to eq(original_data.bytesize)

        result = File.read(decompressed)
        expect(result).to eq(original_data)
      end
    end

    it "handles binary data with XOR compression" do
      original_data = (0..255).to_a.pack("C*") * 10

      Dir.mktmpdir do |dir|
        compressed = File.join(dir, "binary.kwj")
        decompressed = File.join(dir, "binary.out")

        bytes = compressor.compress_data(
          original_data,
          compressed,
          compression: :xor,
        )

        expect(bytes).to be > original_data.bytesize

        header = decompressor.open(compressed)
        decompressor.extract(header, compressed, decompressed)

        result = File.read(decompressed, mode: "rb")
        expect(result).to eq(original_data)
      end
    end
  end

  describe "#compress with SZDD compression" do
    it "compresses and decompresses data correctly" do
      original_data = "Test data for KWAJ SZDD compression! " * 10

      Dir.mktmpdir do |dir|
        compressed = File.join(dir, "test.kwj")
        decompressed = File.join(dir, "test.out")

        # Compress
        bytes = compressor.compress_data(
          original_data,
          compressed,
          compression: :szdd,
        )

        expect(bytes).to be > 0
        expect(File.exist?(compressed)).to be true

        # Decompress and verify
        header = decompressor.open(compressed)
        expect(header.comp_type).to eq(Cabriolet::Constants::KWAJ_COMP_SZDD)

        result_bytes = decompressor.extract(header, compressed, decompressed)
        expect(result_bytes).to eq(original_data.bytesize)

        result = File.read(decompressed)
        expect(result).to eq(original_data)
      end
    end

    it "achieves compression on repetitive data" do
      original_data = "AAAA" * 100

      Dir.mktmpdir do |dir|
        compressed = File.join(dir, "repeat.kwj")

        bytes = compressor.compress_data(
          original_data,
          compressed,
          compression: :szdd,
        )

        # SZDD should compress repetitive data
        expect(bytes).to be < (original_data.bytesize + 20)
      end
    end
  end

  describe "#compress with optional headers" do
    it "includes uncompressed length when requested" do
      original_data = "Test data with length header"

      Dir.mktmpdir do |dir|
        compressed = File.join(dir, "with_length.kwj")

        compressor.compress_data(
          original_data,
          compressed,
          compression: :none,
          include_length: true,
        )

        header = decompressor.open(compressed)
        expect(header.has_length?).to be true
        expect(header.length).to eq(original_data.bytesize)
      end
    end

    it "embeds filename when provided" do
      original_data = "Test data with filename"

      Dir.mktmpdir do |dir|
        compressed = File.join(dir, "with_name.kwj")

        compressor.compress_data(
          original_data,
          compressed,
          compression: :none,
          filename: "test.txt",
        )

        header = decompressor.open(compressed)
        expect(header.has_filename?).to be true
        expect(header.filename).to eq("test.txt")
      end
    end

    it "splits filename into name and extension" do
      original_data = "Test with extension"

      Dir.mktmpdir do |dir|
        compressed = File.join(dir, "with_ext.kwj")

        compressor.compress_data(
          original_data,
          compressed,
          compression: :none,
          filename: "document.pdf",
        )

        header = decompressor.open(compressed)
        expect(header.has_filename?).to be true
        expect(header.has_file_extension?).to be true
        expect(header.filename).to eq("document.pdf")
      end
    end

    it "handles long filenames by truncating" do
      original_data = "Test long filename"

      Dir.mktmpdir do |dir|
        compressed = File.join(dir, "long_name.kwj")

        compressor.compress_data(
          original_data,
          compressed,
          compression: :none,
          filename: "verylongfilename.txt",
        )

        header = decompressor.open(compressed)
        expect(header.has_filename?).to be true
        # Name should be truncated to 8 chars, extension to 3
        expect(header.filename.length).to be <= 12 # 8 + . + 3
      end
    end

    it "includes extra data when provided" do
      original_data = "Test with extra data"
      extra = "This is extra metadata"

      Dir.mktmpdir do |dir|
        compressed = File.join(dir, "with_extra.kwj")

        compressor.compress_data(
          original_data,
          compressed,
          compression: :none,
          extra_data: extra,
        )

        header = decompressor.open(compressed)
        expect(header.has_extra_text?).to be true
        expect(header.extra).to eq(extra)
      end
    end

    it "combines multiple optional headers" do
      original_data = "Test all headers"

      Dir.mktmpdir do |dir|
        compressed = File.join(dir, "all_headers.kwj")

        compressor.compress_data(
          original_data,
          compressed,
          compression: :szdd,
          include_length: true,
          filename: "test.dat",
          extra_data: "metadata",
        )

        header = decompressor.open(compressed)
        expect(header.has_length?).to be true
        expect(header.has_filename?).to be true
        expect(header.has_extra_text?).to be true
        expect(header.comp_type).to eq(Cabriolet::Constants::KWAJ_COMP_SZDD)
        expect(header.length).to eq(original_data.bytesize)
        expect(header.filename).to eq("test.dat")
        expect(header.extra).to eq("metadata")
      end
    end
  end

  describe "#compress from file" do
    it "compresses a file and preserves content" do
      original_data = "File compression test " * 50

      Dir.mktmpdir do |dir|
        input = File.join(dir, "input.txt")
        compressed = File.join(dir, "output.kwj")
        decompressed = File.join(dir, "output.txt")

        # Create input file
        File.write(input, original_data)

        # Compress file
        bytes = compressor.compress(
          input,
          compressed,
          compression: :szdd,
          include_length: true,
        )

        expect(bytes).to be > 0
        expect(File.exist?(compressed)).to be true

        # Decompress and verify
        header = decompressor.open(compressed)
        decompressor.extract(header, compressed, decompressed)

        result = File.read(decompressed)
        expect(result).to eq(original_data)
      end
    end
  end

  describe "error handling" do
    it "raises error for invalid compression type" do
      expect do
        compressor.compress_data("test", "out.kwj", compression: :invalid)
      end.to raise_error(ArgumentError, /Compression type must be one of/)
    end

    it "raises error for MSZIP compression (not implemented)" do
      Dir.mktmpdir do |dir|
        compressed = File.join(dir, "mszip.kwj")

        expect do
          compressor.compress_data(
            "test",
            compressed,
            compression: :mszip,
          )
        end.to raise_error(Cabriolet::Error, /MSZIP/)
      end
    end
  end

  describe "header calculations" do
    it "calculates correct data offset without optional fields" do
      Dir.mktmpdir do |dir|
        compressed = File.join(dir, "minimal.kwj")

        compressor.compress_data(
          "test",
          compressed,
          compression: :none,
        )

        header = decompressor.open(compressed)
        # Base header only: 14 bytes
        expect(header.data_offset).to eq(14)
      end
    end

    it "calculates correct data offset with length field" do
      Dir.mktmpdir do |dir|
        compressed = File.join(dir, "with_length.kwj")

        compressor.compress_data(
          "test",
          compressed,
          compression: :none,
          include_length: true,
        )

        header = decompressor.open(compressed)
        # Base header (14) + length field (4) = 18
        expect(header.data_offset).to eq(18)
      end
    end

    it "calculates correct data offset with all fields" do
      Dir.mktmpdir do |dir|
        compressed = File.join(dir, "all_fields.kwj")

        compressor.compress_data(
          "test",
          compressed,
          compression: :none,
          include_length: true,
          filename: "test.txt",
          extra_data: "extra",
        )

        header = decompressor.open(compressed)
        # Base (14) + length (4) + filename (5+1) + ext (4+1) + extra (2+5) = 36
        # But test.txt is actually "test" (4) + "." skipped + "txt" (3)
        # So: 14 + 4 + (4+1) + (3+1) + (2+5) = 34
        expect(header.data_offset).to eq(34)
      end
    end
  end

  describe "round-trip compatibility" do
    it "produces files compatible with KWAJ decompressor" do
      test_cases = [
        { data: "Simple text", opts: { compression: :none } },
        { data: "XOR test", opts: { compression: :xor } },
        { data: "SZDD " * 20, opts: { compression: :szdd } },
        {
          data: "With headers",
          opts: {
            compression: :szdd,
            include_length: true,
            filename: "test.bin",
          },
        },
      ]

      Dir.mktmpdir do |dir|
        test_cases.each_with_index do |test_case, idx|
          compressed = File.join(dir, "test_#{idx}.kwj")
          decompressed = File.join(dir, "test_#{idx}.out")

          # Compress
          compressor.compress_data(
            test_case[:data],
            compressed,
            **test_case[:opts],
          )

          # Decompress
          header = decompressor.open(compressed)
          decompressor.extract(header, compressed, decompressed)

          # Verify
          result = File.read(decompressed)
          expect(result).to eq(test_case[:data])
        end
      end
    end
  end
end
