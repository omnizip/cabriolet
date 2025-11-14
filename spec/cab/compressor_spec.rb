# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Cabriolet::CAB::Compressor do
  let(:temp_dir) { Dir.mktmpdir }
  let(:compressor) { described_class.new }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  def create_test_file(filename, content)
    path = File.join(temp_dir, filename)
    File.write(path, content)
    path
  end

  def create_cab_file(filename)
    File.join(temp_dir, filename)
  end

  describe "#initialize" do
    it "creates a new compressor with default settings" do
      expect(compressor.files).to be_empty
      expect(compressor.compression).to eq(:mszip)
      expect(compressor.set_id).to be_a(Integer)
      expect(compressor.cabinet_index).to eq(0)
    end

    it "accepts custom io_system" do
      io_system = Cabriolet::System::IOSystem.new
      comp = described_class.new(io_system)
      expect(comp.io_system).to eq(io_system)
    end
  end

  describe "#add_file" do
    it "adds a file to the cabinet" do
      file1 = create_test_file("test1.txt", "Hello")
      compressor.add_file(file1)
      expect(compressor.files.size).to eq(1)
      expect(compressor.files.first[:source]).to eq(file1)
    end

    it "uses custom cabinet path if provided" do
      file1 = create_test_file("test1.txt", "Hello")
      compressor.add_file(file1, "custom/path.txt")
      expect(compressor.files.first[:cab_path]).to eq("custom/path.txt")
    end

    it "uses basename as default cabinet path" do
      file1 = create_test_file("test1.txt", "Hello")
      compressor.add_file(file1)
      expect(compressor.files.first[:cab_path]).to eq("test1.txt")
    end

    it "raises error for non-existent file" do
      expect { compressor.add_file("/nonexistent/file.txt") }
        .to raise_error(ArgumentError, /does not exist/)
    end

    it "raises error for directory" do
      expect { compressor.add_file(temp_dir) }
        .to raise_error(ArgumentError, /Not a file/)
    end
  end

  describe "#generate" do
    it "raises error if no files added" do
      cab_file = create_cab_file("empty.cab")
      expect { compressor.generate(cab_file) }
        .to raise_error(ArgumentError, /No files to compress/)
    end

    context "with single file" do
      it "creates a valid CAB file" do
        file1 = create_test_file("test1.txt", "Hello, World!")
        compressor.add_file(file1)

        cab_file = create_cab_file("test.cab")
        bytes_written = compressor.generate(cab_file, compression: :none)

        expect(bytes_written).to be > 0
        expect(File.exist?(cab_file)).to be true
        expect(File.size(cab_file)).to eq(bytes_written)
      end

      it "creates extractable CAB file" do
        file1 = create_test_file("test1.txt", "Hello, World!")
        compressor.add_file(file1)

        cab_file = create_cab_file("test.cab")
        compressor.generate(cab_file, compression: :none)

        # Extract and verify
        decompressor = Cabriolet::CAB::Decompressor.new
        cabinet = decompressor.open(cab_file)

        expect(cabinet.files.size).to eq(1)
        expect(cabinet.files.first.filename).to eq("test1.txt")
        expect(cabinet.files.first.length).to eq(13)
      end
    end

    context "with multiple files" do
      it "creates CAB with all files" do
        file1 = create_test_file("file1.txt", "First file")
        file2 = create_test_file("file2.txt", "Second file")
        file3 = create_test_file("file3.txt", "Third file")

        compressor.add_file(file1)
        compressor.add_file(file2)
        compressor.add_file(file3)

        cab_file = create_cab_file("multi.cab")
        compressor.generate(cab_file, compression: :none)

        # Verify
        decompressor = Cabriolet::CAB::Decompressor.new
        cabinet = decompressor.open(cab_file)

        expect(cabinet.files.size).to eq(3)
        expect(cabinet.files.map(&:filename)).to contain_exactly(
          "file1.txt", "file2.txt", "file3.txt"
        )
      end
    end

    context "with different compression types" do
      let(:test_content) { "Hello, World! " * 100 }

      it "creates CAB with no compression" do
        file1 = create_test_file("test.txt", test_content)
        compressor.add_file(file1)

        cab_file = create_cab_file("none.cab")
        compressor.generate(cab_file, compression: :none)

        decompressor = Cabriolet::CAB::Decompressor.new
        cabinet = decompressor.open(cab_file)
        folder = cabinet.folders.first

        expect(folder.comp_type).to eq(Cabriolet::Constants::COMP_TYPE_NONE)
      end

      it "creates CAB with MSZIP compression" do
        file1 = create_test_file("test.txt", test_content)
        compressor.add_file(file1)

        cab_file = create_cab_file("mszip.cab")
        compressor.generate(cab_file, compression: :mszip)

        decompressor = Cabriolet::CAB::Decompressor.new
        cabinet = decompressor.open(cab_file)
        folder = cabinet.folders.first

        expect(folder.comp_type).to eq(Cabriolet::Constants::COMP_TYPE_MSZIP)
      end
    end

    context "with large files" do
      it "handles files requiring multiple blocks" do
        # Create file > 32KB to require multiple blocks
        large_content = "A" * 65_536
        file1 = create_test_file("large.txt", large_content)
        compressor.add_file(file1)

        cab_file = create_cab_file("large.cab")
        compressor.generate(cab_file, compression: :none)

        # Verify
        decompressor = Cabriolet::CAB::Decompressor.new
        cabinet = decompressor.open(cab_file)

        expect(cabinet.files.first.length).to eq(65_536)
        expect(cabinet.folders.first.num_blocks).to be >= 2
      end
    end

    context "round-trip testing" do
      it "preserves file content through compression and extraction" do
        original_content = "This is a test file with some content.\n" * 50
        file1 = create_test_file("original.txt", original_content)
        compressor.add_file(file1)

        cab_file = create_cab_file("roundtrip.cab")
        compressor.generate(cab_file, compression: :none)

        # Extract
        extract_dir = File.join(temp_dir, "extract")
        decompressor = Cabriolet::CAB::Decompressor.new
        cabinet = decompressor.open(cab_file)
        decompressor.extract_all(cabinet, extract_dir)

        # Verify content
        extracted_file = File.join(extract_dir, "original.txt")
        extracted_content = File.read(extracted_file)
        expect(extracted_content).to eq(original_content)
      end

      it "preserves file metadata" do
        file1 = create_test_file("metadata.txt", "Test")
        mtime = File.stat(file1).mtime
        compressor.add_file(file1)

        cab_file = create_cab_file("metadata.cab")
        compressor.generate(cab_file, compression: :none)

        # Check metadata
        decompressor = Cabriolet::CAB::Decompressor.new
        cabinet = decompressor.open(cab_file)
        cab_file_entry = cabinet.files.first

        # CAB format has 2-second granularity
        expect(cab_file_entry.modification_time).to be_within(2).of(mtime)
      end

      it "handles binary files correctly" do
        # Create binary file with various byte values
        binary_content = (0..255).to_a.pack("C*") * 100
        file1 = create_test_file("binary.dat", binary_content)
        compressor.add_file(file1)

        cab_file = create_cab_file("binary.cab")
        compressor.generate(cab_file, compression: :none)

        # Extract and verify
        extract_dir = File.join(temp_dir, "extract")
        decompressor = Cabriolet::CAB::Decompressor.new
        cabinet = decompressor.open(cab_file)
        decompressor.extract_all(cabinet, extract_dir)

        extracted_file = File.join(extract_dir, "binary.dat")
        extracted_content = File.binread(extracted_file)
        expect(extracted_content).to eq(binary_content)
      end
    end

    context "with options" do
      it "accepts custom set_id" do
        file1 = create_test_file("test.txt", "Content")
        compressor.add_file(file1)

        cab_file = create_cab_file("custom.cab")
        compressor.generate(cab_file, set_id: 12_345)

        decompressor = Cabriolet::CAB::Decompressor.new
        cabinet = decompressor.open(cab_file)
        expect(cabinet.set_id).to eq(12_345)
      end

      it "accepts custom cabinet_index" do
        file1 = create_test_file("test.txt", "Content")
        compressor.add_file(file1)

        cab_file = create_cab_file("custom.cab")
        compressor.generate(cab_file, cabinet_index: 5)

        decompressor = Cabriolet::CAB::Decompressor.new
        cabinet = decompressor.open(cab_file)
        expect(cabinet.set_index).to eq(5)
      end
    end

    context "error handling" do
      it "raises error for invalid compression type" do
        file1 = create_test_file("test.txt", "Content")
        compressor.add_file(file1)

        cab_file = create_cab_file("invalid.cab")
        expect { compressor.generate(cab_file, compression: :invalid) }
          .to raise_error(ArgumentError, /Unsupported compression type/)
      end
    end

    context "checksum validation" do
      it "generates valid checksums for data blocks" do
        file1 = create_test_file("test.txt", "Test content for checksum")
        compressor.add_file(file1)

        cab_file = create_cab_file("checksum.cab")
        compressor.generate(cab_file, compression: :none)

        # Extract without salvage mode (which would skip checksum validation)
        extract_dir = File.join(temp_dir, "extract")
        decompressor = Cabriolet::CAB::Decompressor.new
        decompressor.salvage = false
        cabinet = decompressor.open(cab_file)

        # This should not raise checksum errors
        expect do
          decompressor.extract_all(cabinet, extract_dir)
        end.not_to raise_error
      end
    end
  end

  describe "integration with existing CAB files" do
    it "creates CAB compatible with simple.cab structure" do
      # Create similar structure to spec/fixtures/cabextract/simple.cab
      file1 = create_test_file("file1.txt", "Content of file 1")
      compressor.add_file(file1)

      cab_file = create_cab_file("compat.cab")
      compressor.generate(cab_file, compression: :mszip)

      # Should be parseable
      decompressor = Cabriolet::CAB::Decompressor.new
      cabinet = decompressor.open(cab_file)

      expect(cabinet.files.size).to eq(1)
      expect(cabinet.folders.size).to eq(1)
    end
  end
end
