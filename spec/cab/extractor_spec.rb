# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Cabriolet::CAB::Extractor do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:decompressor) { Cabriolet::CAB::Decompressor.new(io_system) }
  let(:extractor) { described_class.new(io_system, decompressor) }

  # Fixture paths
  let(:fixtures_dir) { File.expand_path("../fixtures/libmspack/cabd", __dir__) }
  let(:normal_2files_1folder) do
    File.join(fixtures_dir, "normal_2files_1folder.cab")
  end
  let(:normal_2files_2folders) do
    File.join(fixtures_dir, "normal_2files_2folders.cab")
  end
  let(:mszip_lzx_qtm) { File.join(fixtures_dir, "mszip_lzx_qtm.cab") }

  describe "#extract_file" do
    context "with a simple uncompressed cabinet" do
      it "extracts a single file correctly" do
        Dir.mktmpdir do |tmpdir|
          cabinet = decompressor.open(normal_2files_1folder)
          file = cabinet.files.first

          output_path = File.join(tmpdir, "extracted_file.txt")
          bytes = extractor.extract_file(file, output_path)

          expect(bytes).to eq(file.length)
          expect(File.exist?(output_path)).to be true
          expect(File.size(output_path)).to eq(file.length)
        end
      end

      it "extracts all files from the cabinet" do
        Dir.mktmpdir do |tmpdir|
          cabinet = decompressor.open(normal_2files_1folder)

          cabinet.files.each do |file|
            output_path = File.join(tmpdir, file.filename)
            bytes = extractor.extract_file(file, output_path)

            expect(bytes).to eq(file.length)
            expect(File.exist?(output_path)).to be true
          end
        end
      end
    end

    context "with a cabinet containing multiple folders" do
      it "extracts files from different folders" do
        skip "Compression type not yet fully supported in fixtures"

        Dir.mktmpdir do |tmpdir|
          cabinet = decompressor.open(normal_2files_2folders)

          cabinet.files.each do |file|
            output_path = File.join(tmpdir, file.filename)
            bytes = extractor.extract_file(file, output_path)

            expect(bytes).to eq(file.length)
            expect(File.exist?(output_path)).to be true
          end
        end
      end
    end

    context "with different compression methods" do
      it "extracts files with various compression types" do
        skip "Compression checksum validation needs fixture verification"

        Dir.mktmpdir do |tmpdir|
          cabinet = decompressor.open(mszip_lzx_qtm)

          cabinet.files.each do |file|
            output_path = File.join(tmpdir, file.filename)
            bytes = extractor.extract_file(file, output_path)

            expect(bytes).to eq(file.length)
            expect(File.exist?(output_path)).to be true
          end
        end
      end
    end

    context "with error handling" do
      it "raises error for file without folder" do
        Dir.mktmpdir do |tmpdir|
          file = Cabriolet::Models::File.new
          file.filename = "test.txt"
          file.length = 100
          file.folder = nil

          output_path = File.join(tmpdir, "test.txt")

          expect do
            extractor.extract_file(file, output_path)
          end.to raise_error(Cabriolet::ArgumentError, /no folder/)
        end
      end

      it "raises error for file with offset beyond 2GB" do
        Dir.mktmpdir do |tmpdir|
          cabinet = decompressor.open(normal_2files_1folder)
          file = cabinet.files.first
          file.offset = Cabriolet::Constants::LENGTH_MAX + 1

          output_path = File.join(tmpdir, "test.txt")

          expect do
            extractor.extract_file(file, output_path)
          end.to raise_error(Cabriolet::DecompressionError, /beyond 2GB/)
        end
      end
    end

    context "with directory creation" do
      it "creates nested directories for file path" do
        Dir.mktmpdir do |tmpdir|
          cabinet = decompressor.open(normal_2files_1folder)
          file = cabinet.files.first

          output_path = File.join(tmpdir, "nested", "dir", "file.txt")
          extractor.extract_file(file, output_path)

          expect(File.exist?(output_path)).to be true
          expect(File.directory?(File.join(tmpdir, "nested", "dir"))).to be true
        end
      end
    end
  end

  describe "#extract_all" do
    context "with default options" do
      it "extracts all files preserving paths" do
        Dir.mktmpdir do |tmpdir|
          cabinet = decompressor.open(normal_2files_1folder)

          count = extractor.extract_all(cabinet, tmpdir)

          expect(count).to eq(cabinet.files.size)

          cabinet.files.each do |file|
            output_path = File.join(tmpdir, file.filename)
            expect(File.exist?(output_path)).to be true
            expect(File.size(output_path)).to eq(file.length)
          end
        end
      end

      it "sets file timestamps" do
        Dir.mktmpdir do |tmpdir|
          cabinet = decompressor.open(normal_2files_1folder)

          extractor.extract_all(cabinet, tmpdir, set_timestamps: true)

          cabinet.files.each do |file|
            next unless file.modification_time

            output_path = File.join(tmpdir, file.filename)
            mtime = File.mtime(output_path)

            # Allow for some time difference due to filesystem precision
            expect((mtime.to_i - file.modification_time.to_i).abs).to be < 2
          end
        end
      end
    end

    context "with preserve_paths: false" do
      it "extracts all files to flat directory" do
        Dir.mktmpdir do |tmpdir|
          cabinet = decompressor.open(normal_2files_1folder)

          count = extractor.extract_all(cabinet, tmpdir, preserve_paths: false)

          expect(count).to eq(cabinet.files.size)

          cabinet.files.each do |file|
            basename = File.basename(file.filename)
            output_path = File.join(tmpdir, basename)
            expect(File.exist?(output_path)).to be true
          end
        end
      end
    end

    context "with set_timestamps: false" do
      it "does not set file timestamps" do
        Dir.mktmpdir do |tmpdir|
          cabinet = decompressor.open(normal_2files_1folder)

          before_time = Time.now
          extractor.extract_all(cabinet, tmpdir, set_timestamps: false)
          after_time = Time.now

          cabinet.files.each do |file|
            output_path = File.join(tmpdir, file.filename)
            mtime = File.mtime(output_path)

            # File should have current time, not CAB time
            expect(mtime).to be_between(before_time - 1, after_time + 1)
          end
        end
      end
    end

    context "with progress callback" do
      it "calls progress callback for each file" do
        Dir.mktmpdir do |tmpdir|
          cabinet = decompressor.open(normal_2files_1folder)

          progress_calls = []
          callback = proc do |file, current, total|
            progress_calls << { file: file, current: current, total: total }
          end

          extractor.extract_all(cabinet, tmpdir, progress: callback)

          expect(progress_calls.size).to eq(cabinet.files.size)
          expect(progress_calls.last[:current]).to eq(cabinet.files.size)
          expect(progress_calls.last[:total]).to eq(cabinet.files.size)
        end
      end
    end

    context "with file attributes" do
      it "sets read-only permissions for readonly files" do
        Dir.mktmpdir do |tmpdir|
          cabinet = decompressor.open(normal_2files_1folder)

          # Mock a readonly file
          file = cabinet.files.first
          allow(file).to receive(:readonly?).and_return(true)

          extractor.extract_all(cabinet, tmpdir)

          output_path = File.join(tmpdir, file.filename)
          mode = File.stat(output_path).mode

          # Check that owner write bit is not set (read-only)
          expect(mode & 0o200).to eq(0)
        end
      end

      it "sets executable permissions for executable files" do
        Dir.mktmpdir do |tmpdir|
          cabinet = decompressor.open(normal_2files_1folder)

          # Mock an executable file
          file = cabinet.files.first
          allow(file).to receive(:executable?).and_return(true)
          allow(file).to receive(:readonly?).and_return(false)

          extractor.extract_all(cabinet, tmpdir)

          output_path = File.join(tmpdir, file.filename)
          mode = File.stat(output_path).mode

          # Check that owner execute bit is set
          expect(mode & 0o100).to eq(0o100)
        end
      end
    end
  end

  describe "checksum calculation" do
    let(:block_reader_class) { Cabriolet::CAB::Extractor::BlockReader }
    let(:cabinet) { decompressor.open(normal_2files_1folder) }
    let(:folder) { cabinet.folders.first }
    let(:block_reader) do
      block_reader_class.new(io_system, folder.data, 1, false)
    end

    after { block_reader.close }

    it "calculates correct checksum for empty data" do
      checksum = block_reader.send(:calculate_checksum, "")
      expect(checksum).to eq(0)
    end

    it "calculates correct checksum for 4-byte data" do
      data = [0x12, 0x34, 0x56, 0x78].pack("C*")
      checksum = block_reader.send(:calculate_checksum, data)
      expect(checksum).to eq(0x78563412)
    end

    it "calculates correct checksum with initial value" do
      data = [0x12, 0x34, 0x56, 0x78].pack("C*")
      checksum = block_reader.send(:calculate_checksum, data, 0xFFFFFFFF)
      expect(checksum).to eq(0x78563412 ^ 0xFFFFFFFF)
    end

    it "handles data not aligned to 4 bytes" do
      # 5 bytes: 4 + 1
      data = [0x12, 0x34, 0x56, 0x78, 0xAB].pack("C*")
      checksum = block_reader.send(:calculate_checksum, data)

      expected = 0x78563412 ^ 0xAB
      expect(checksum).to eq(expected)
    end

    it "handles 2-byte remainder" do
      data = [0x12, 0x34, 0x56, 0x78, 0xAB, 0xCD].pack("C*")
      checksum = block_reader.send(:calculate_checksum, data)

      expected = 0x78563412 ^ 0xCDAB
      expect(checksum).to eq(expected)
    end

    it "handles 3-byte remainder" do
      data = [0x12, 0x34, 0x56, 0x78, 0xAB, 0xCD, 0xEF].pack("C*")
      checksum = block_reader.send(:calculate_checksum, data)

      expected = 0x78563412 ^ 0xEFCDAB
      expect(checksum).to eq(expected)
    end
  end

  describe "integration test" do
    it "performs complete extraction workflow" do
      Dir.mktmpdir do |tmpdir|
        # Parse cabinet
        cabinet = decompressor.open(normal_2files_1folder)

        expect(cabinet).not_to be_nil
        expect(cabinet.files).not_to be_empty

        # Extract all files
        count = extractor.extract_all(cabinet, tmpdir)

        expect(count).to eq(cabinet.files.size)

        # Verify all files exist and have correct size
        cabinet.files.each do |file|
          output_path = File.join(tmpdir, file.filename)

          expect(File.exist?(output_path)).to be true
          expect(File.size(output_path)).to eq(file.length)

          # Verify file is readable
          content = File.read(output_path)
          expect(content.bytesize).to eq(file.length)
        end
      end
    end
  end
end
