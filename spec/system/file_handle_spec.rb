# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Cabriolet::System::FileHandle do
  let(:fixture_file) do
    File.join(__dir__, "../fixtures/libmspack/cabd/normal_2files_1folder.cab")
  end

  describe "#initialize" do
    context "with MODE_READ" do
      it "opens an existing file for reading" do
        handle = described_class.new(fixture_file, Cabriolet::Constants::MODE_READ)
        expect(handle.filename).to eq(fixture_file)
        expect(handle.mode).to eq(Cabriolet::Constants::MODE_READ)
        expect(handle.closed?).to be(false)
        handle.close
      end
    end

    context "with MODE_WRITE" do
      it "creates a new file for writing" do
        Dir.mktmpdir do |dir|
          file_path = File.join(dir, "test.cab")
          handle = described_class.new(file_path, Cabriolet::Constants::MODE_WRITE)
          expect(handle.filename).to eq(file_path)
          expect(handle.mode).to eq(Cabriolet::Constants::MODE_WRITE)
          handle.close
          expect(File.exist?(file_path)).to be(true)
        end
      end
    end

    context "with MODE_UPDATE" do
      it "opens an existing file for reading and writing" do
        Dir.mktmpdir do |dir|
          file_path = File.join(dir, "test.cab")
          File.write(file_path, "test data")
          handle = described_class.new(file_path, Cabriolet::Constants::MODE_UPDATE)
          expect(handle.mode).to eq(Cabriolet::Constants::MODE_UPDATE)
          handle.close
        end
      end
    end

    context "with MODE_APPEND" do
      it "opens an existing file for appending" do
        Dir.mktmpdir do |dir|
          file_path = File.join(dir, "test.cab")
          File.write(file_path, "test data")
          handle = described_class.new(file_path, Cabriolet::Constants::MODE_APPEND)
          expect(handle.mode).to eq(Cabriolet::Constants::MODE_APPEND)
          handle.close
        end
      end
    end

    context "with non-existent file" do
      it "raises IOError for MODE_READ" do
        expect do
          described_class.new("/nonexistent/file.cab", Cabriolet::Constants::MODE_READ)
        end.to raise_error(Cabriolet::IOError, /Cannot open file/)
      end
    end

    context "with invalid mode" do
      it "raises ArgumentError" do
        expect do
          described_class.new(fixture_file, 999)
        end.to raise_error(ArgumentError, /Invalid mode/)
      end
    end
  end

  describe "#read" do
    it "reads specified number of bytes" do
      handle = described_class.new(fixture_file, Cabriolet::Constants::MODE_READ)
      data = handle.read(4)
      expect(data.bytesize).to eq(4)
      expect(data).to eq("MSCF")
      handle.close
    end

    it "returns empty string at EOF" do
      handle = described_class.new(fixture_file, Cabriolet::Constants::MODE_READ)
      file_size = File.size(fixture_file)
      handle.seek(file_size, Cabriolet::Constants::SEEK_START)
      data = handle.read(100)
      expect(data).to eq("")
      handle.close
    end

    it "reads partial data when less than requested is available" do
      handle = described_class.new(fixture_file, Cabriolet::Constants::MODE_READ)
      file_size = File.size(fixture_file)
      handle.seek(file_size - 2, Cabriolet::Constants::SEEK_START)
      data = handle.read(100)
      expect(data.bytesize).to eq(2)
      handle.close
    end
  end

  describe "#write" do
    it "writes data to file" do
      Dir.mktmpdir do |dir|
        file_path = File.join(dir, "test.cab")
        handle = described_class.new(file_path, Cabriolet::Constants::MODE_WRITE)
        bytes_written = handle.write("test data")
        expect(bytes_written).to eq(9)
        handle.close
        expect(File.read(file_path)).to eq("test data")
      end
    end

    it "appends data in MODE_APPEND" do
      Dir.mktmpdir do |dir|
        file_path = File.join(dir, "test.cab")
        File.write(file_path, "initial ")
        handle = described_class.new(file_path, Cabriolet::Constants::MODE_APPEND)
        handle.write("appended")
        handle.close
        expect(File.read(file_path)).to eq("initial appended")
      end
    end
  end

  describe "#seek" do
    let(:handle) { described_class.new(fixture_file, Cabriolet::Constants::MODE_READ) }

    after { handle.close }

    context "with SEEK_START" do
      it "seeks from start of file" do
        position = handle.seek(10, Cabriolet::Constants::SEEK_START)
        expect(position).to eq(10)
        expect(handle.tell).to eq(10)
      end
    end

    context "with SEEK_CUR" do
      it "seeks from current position" do
        handle.seek(10, Cabriolet::Constants::SEEK_START)
        position = handle.seek(5, Cabriolet::Constants::SEEK_CUR)
        expect(position).to eq(15)
        expect(handle.tell).to eq(15)
      end
    end

    context "with SEEK_END" do
      it "seeks from end of file" do
        file_size = File.size(fixture_file)
        position = handle.seek(-10, Cabriolet::Constants::SEEK_END)
        expect(position).to eq(file_size - 10)
        expect(handle.tell).to eq(file_size - 10)
      end
    end

    context "with invalid whence" do
      it "raises ArgumentError" do
        expect do
          handle.seek(0, 999)
        end.to raise_error(ArgumentError, /Invalid whence value/)
      end
    end
  end

  describe "#tell" do
    it "returns current position" do
      handle = described_class.new(fixture_file, Cabriolet::Constants::MODE_READ)
      expect(handle.tell).to eq(0)
      handle.read(10)
      expect(handle.tell).to eq(10)
      handle.close
    end
  end

  describe "#close" do
    it "closes the file" do
      handle = described_class.new(fixture_file, Cabriolet::Constants::MODE_READ)
      expect(handle.closed?).to be(false)
      handle.close
      expect(handle.closed?).to be(true)
    end

    it "does not raise error when called multiple times" do
      handle = described_class.new(fixture_file, Cabriolet::Constants::MODE_READ)
      handle.close
      expect { handle.close }.not_to raise_error
    end
  end

  describe "#closed?" do
    it "returns false when file is open" do
      handle = described_class.new(fixture_file, Cabriolet::Constants::MODE_READ)
      expect(handle.closed?).to be(false)
      handle.close
    end

    it "returns true when file is closed" do
      handle = described_class.new(fixture_file, Cabriolet::Constants::MODE_READ)
      handle.close
      expect(handle.closed?).to be(true)
    end
  end
end
