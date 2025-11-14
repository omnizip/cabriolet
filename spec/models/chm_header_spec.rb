# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::Models::CHMHeader do
  let(:header) { described_class.new }

  describe "#initialize" do
    it "initializes with default values" do
      expect(header.version).to eq(0)
      expect(header.timestamp).to eq(0)
      expect(header.language).to eq(0)
      expect(header.length).to eq(0)
      expect(header.files).to be_nil
      expect(header.sysfiles).to be_nil
    end

    it "initializes sections" do
      expect(header.sec0).to be_a(Cabriolet::Models::CHMSecUncompressed)
      expect(header.sec0.chm).to eq(header)
      expect(header.sec1).to be_a(Cabriolet::Models::CHMSecMSCompressed)
      expect(header.sec1.chm).to eq(header)
    end
  end

  describe "#all_files" do
    it "returns empty array when no files" do
      expect(header.all_files).to eq([])
    end

    it "returns array of files" do
      file1 = Cabriolet::Models::CHMFile.new
      file1.filename = "test1.html"
      file2 = Cabriolet::Models::CHMFile.new
      file2.filename = "test2.html"

      file1.next_file = file2
      header.files = file1

      expect(header.all_files.length).to eq(2)
      expect(header.all_files[0].filename).to eq("test1.html")
      expect(header.all_files[1].filename).to eq("test2.html")
    end
  end

  describe "#find_file" do
    it "finds a file by name" do
      file = Cabriolet::Models::CHMFile.new
      file.filename = "test.html"
      header.files = file

      found = header.find_file("test.html")
      expect(found).to eq(file)
    end

    it "returns nil for non-existent file" do
      expect(header.find_file("nonexistent.html")).to be_nil
    end
  end
end
