# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::System::MemoryHandle do
  describe "#initialize" do
    context "with no data" do
      it "creates an empty handle" do
        handle = described_class.new
        expect(handle.data).to eq("")
        expect(handle.mode).to eq(Cabriolet::Constants::MODE_READ)
        expect(handle.tell).to eq(0)
      end
    end

    context "with initial data" do
      it "creates a handle with data" do
        handle = described_class.new("test data")
        expect(handle.data).to eq("test data")
        expect(handle.tell).to eq(0)
      end
    end

    context "with MODE_READ" do
      it "sets position to start" do
        handle = described_class.new("test", Cabriolet::Constants::MODE_READ)
        expect(handle.tell).to eq(0)
      end
    end

    context "with MODE_APPEND" do
      it "sets position to end" do
        handle = described_class.new("test", Cabriolet::Constants::MODE_APPEND)
        expect(handle.tell).to eq(4)
      end
    end

    context "with MODE_WRITE" do
      it "sets position to start" do
        handle = described_class.new("test", Cabriolet::Constants::MODE_WRITE)
        expect(handle.tell).to eq(0)
      end
    end
  end

  describe "#read" do
    let(:handle) { described_class.new("Hello, World!") }

    it "reads specified number of bytes" do
      data = handle.read(5)
      expect(data).to eq("Hello")
      expect(handle.tell).to eq(5)
    end

    it "advances position after reading" do
      handle.read(5)
      data = handle.read(2)
      expect(data).to eq(", ")
      expect(handle.tell).to eq(7)
    end

    it "returns empty string at EOF" do
      handle.seek(0, Cabriolet::Constants::SEEK_END)
      data = handle.read(10)
      expect(data).to eq("")
    end

    it "returns partial data when less than requested is available" do
      handle.seek(-3, Cabriolet::Constants::SEEK_END)
      data = handle.read(10)
      expect(data).to eq("ld!")
      expect(data.bytesize).to eq(3)
    end

    it "returns empty string when position exceeds data size" do
      handle.seek(100, Cabriolet::Constants::SEEK_START)
      data = handle.read(10)
      expect(data).to eq("")
    end
  end

  describe "#write" do
    context "in MODE_WRITE" do
      let(:handle) { described_class.new("", Cabriolet::Constants::MODE_WRITE) }

      it "writes data to memory" do
        bytes_written = handle.write("test data")
        expect(bytes_written).to eq(9)
        expect(handle.data).to eq("test data")
        expect(handle.tell).to eq(9)
      end

      it "overwrites existing data" do
        handle.write("initial")
        handle.seek(0, Cabriolet::Constants::SEEK_START)
        handle.write("new")
        expect(handle.data).to eq("newtial")
      end

      it "appends when at end" do
        handle.write("first")
        handle.write(" second")
        expect(handle.data).to eq("first second")
      end
    end

    context "in MODE_APPEND" do
      it "appends data at end" do
        handle = described_class.new("initial", Cabriolet::Constants::MODE_APPEND)
        handle.write(" appended")
        expect(handle.data).to eq("initial appended")
      end
    end

    context "in MODE_UPDATE" do
      it "can write in the middle of data" do
        handle = described_class.new("Hello World", Cabriolet::Constants::MODE_UPDATE)
        handle.seek(6, Cabriolet::Constants::SEEK_START)
        handle.write("Ruby")
        expect(handle.data).to eq("Hello Rubyd")
      end
    end

    context "in MODE_READ" do
      it "raises IOError" do
        handle = described_class.new("test", Cabriolet::Constants::MODE_READ)
        expect do
          handle.write("data")
        end.to raise_error(Cabriolet::IOError, /not opened for writing/)
      end
    end

    context "when closed" do
      it "raises IOError" do
        handle = described_class.new("", Cabriolet::Constants::MODE_WRITE)
        handle.close
        expect do
          handle.write("data")
        end.to raise_error(Cabriolet::IOError, /Handle is closed/)
      end
    end
  end

  describe "#seek" do
    let(:handle) { described_class.new("0123456789") }

    context "with SEEK_START" do
      it "seeks from start of data" do
        position = handle.seek(5, Cabriolet::Constants::SEEK_START)
        expect(position).to eq(5)
        expect(handle.tell).to eq(5)
      end

      it "clamps negative offset to 0" do
        position = handle.seek(-10, Cabriolet::Constants::SEEK_START)
        expect(position).to eq(0)
        expect(handle.tell).to eq(0)
      end

      it "clamps position beyond end to data size" do
        position = handle.seek(100, Cabriolet::Constants::SEEK_START)
        expect(position).to eq(10)
        expect(handle.tell).to eq(10)
      end
    end

    context "with SEEK_CUR" do
      it "seeks from current position" do
        handle.seek(3, Cabriolet::Constants::SEEK_START)
        position = handle.seek(2, Cabriolet::Constants::SEEK_CUR)
        expect(position).to eq(5)
        expect(handle.tell).to eq(5)
      end

      it "can seek backwards" do
        handle.seek(5, Cabriolet::Constants::SEEK_START)
        position = handle.seek(-2, Cabriolet::Constants::SEEK_CUR)
        expect(position).to eq(3)
        expect(handle.tell).to eq(3)
      end

      it "clamps to valid range" do
        handle.seek(5, Cabriolet::Constants::SEEK_START)
        handle.seek(-100, Cabriolet::Constants::SEEK_CUR)
        expect(handle.tell).to eq(0)
      end
    end

    context "with SEEK_END" do
      it "seeks from end of data" do
        position = handle.seek(-3, Cabriolet::Constants::SEEK_END)
        expect(position).to eq(7)
        expect(handle.tell).to eq(7)
      end

      it "seeks to end with 0 offset" do
        position = handle.seek(0, Cabriolet::Constants::SEEK_END)
        expect(position).to eq(10)
        expect(handle.tell).to eq(10)
      end

      it "clamps to valid range" do
        handle.seek(-100, Cabriolet::Constants::SEEK_END)
        expect(handle.tell).to eq(0)
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
      handle = described_class.new("test data")
      expect(handle.tell).to eq(0)
      handle.read(4)
      expect(handle.tell).to eq(4)
    end
  end

  describe "#close" do
    it "marks handle as closed" do
      handle = described_class.new("test")
      expect(handle.closed?).to be(false)
      handle.close
      expect(handle.closed?).to be(true)
    end
  end

  describe "#closed?" do
    it "returns false when open" do
      handle = described_class.new("test")
      expect(handle.closed?).to be(false)
    end

    it "returns true when closed" do
      handle = described_class.new("test")
      handle.close
      expect(handle.closed?).to be(true)
    end
  end

  describe "#to_s" do
    it "returns complete data buffer" do
      handle = described_class.new("test data")
      handle.read(4)
      expect(handle.to_s).to eq("test data")
    end

    it "returns modified data after writes" do
      handle = described_class.new("initial", Cabriolet::Constants::MODE_WRITE)
      handle.seek(0, Cabriolet::Constants::SEEK_END)
      handle.write(" added")
      expect(handle.to_s).to eq("initial added")
    end
  end

  describe "boundary conditions" do
    it "handles empty data" do
      handle = described_class.new("")
      expect(handle.read(10)).to eq("")
      expect(handle.tell).to eq(0)
    end

    it "handles binary data correctly" do
      binary_data = "\x00\x01\x02\xFF".b
      handle = described_class.new(binary_data)
      expect(handle.read(4)).to eq(binary_data)
      expect(handle.data.encoding).to eq(Encoding::BINARY)
    end

    it "preserves binary encoding on write" do
      handle = described_class.new("", Cabriolet::Constants::MODE_WRITE)
      handle.write("\x00\xFF".b)
      expect(handle.data.encoding).to eq(Encoding::BINARY)
    end
  end
end
