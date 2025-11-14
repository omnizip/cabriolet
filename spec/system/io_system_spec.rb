# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::System::IOSystem do
  subject(:io_system) { described_class.new }

  describe "#open" do
    it "returns a FileHandle for file operations" do
      handle = io_system.open(__FILE__, Cabriolet::Constants::MODE_READ)
      expect(handle).to be_a(Cabriolet::System::FileHandle)
      io_system.close(handle)
    end

    it "raises IOError for non-existent files" do
      expect do
        io_system.open("/nonexistent/file.cab", Cabriolet::Constants::MODE_READ)
      end.to raise_error(Cabriolet::IOError)
    end
  end

  describe "#read" do
    it "reads bytes from a handle" do
      handle = io_system.open(__FILE__, Cabriolet::Constants::MODE_READ)
      data = io_system.read(handle, 10)
      expect(data).to be_a(String)
      expect(data.bytesize).to be <= 10
      io_system.close(handle)
    end
  end

  describe "#seek and #tell" do
    it "seeks to a position and reports current position" do
      handle = io_system.open(__FILE__, Cabriolet::Constants::MODE_READ)

      io_system.seek(handle, 10, Cabriolet::Constants::SEEK_START)
      expect(io_system.tell(handle)).to eq(10)

      io_system.seek(handle, 5, Cabriolet::Constants::SEEK_CUR)
      expect(io_system.tell(handle)).to eq(15)

      io_system.close(handle)
    end
  end
end
