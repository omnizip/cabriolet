# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Cabriolet::FileManager do
  let(:manager) { described_class.new }

  describe "#initialize" do
    it "creates empty file manager" do
      expect(manager).to be_empty
      expect(manager.size).to eq(0)
    end
  end

  describe "#add_file" do
    it "adds file from disk" do
      Dir.mktmpdir do |dir|
        source = File.join(dir, "test.txt")
        File.write(source, "test content")

        entry = manager.add_file(source, "docs/test.txt")

        expect(entry).to be_a(Cabriolet::FileEntry)
        expect(entry.archive_path).to eq("docs/test.txt")
        expect(manager.size).to eq(1)
      end
    end

    it "uses basename when archive_path is nil" do
      Dir.mktmpdir do |dir|
        source = File.join(dir, "myfile.txt")
        File.write(source, "content")

        entry = manager.add_file(source)

        expect(entry.archive_path).to eq("myfile.txt")
      end
    end

    it "passes options to FileEntry" do
      Dir.mktmpdir do |dir|
        source = File.join(dir, "test.txt")
        File.write(source, "test")

        entry = manager.add_file(source, "test.txt", compress: false)

        expect(entry.options[:compress]).to be false
      end
    end

    it "raises error for nonexistent file" do
      expect do
        manager.add_file("/nonexistent/file.txt", "test.txt")
      end.to raise_error(ArgumentError, /File not found/)
    end
  end

  describe "#add_data" do
    it "adds data from memory" do
      entry = manager.add_data("Hello, World!", "greeting.txt")

      expect(entry).to be_a(Cabriolet::FileEntry)
      expect(entry.archive_path).to eq("greeting.txt")
      expect(entry.data).to eq("Hello, World!")
      expect(manager.size).to eq(1)
    end

    it "passes options to FileEntry" do
      entry = manager.add_data("data", "file.txt", compress: false)

      expect(entry.options[:compress]).to be false
    end
  end

  describe "#each" do
    it "enumerates all entries" do
      manager.add_data("data1", "file1.txt")
      manager.add_data("data2", "file2.txt")

      paths = []
      manager.each { |entry| paths << entry.archive_path }

      expect(paths).to eq(["file1.txt", "file2.txt"])
    end

    it "supports Enumerable methods" do
      manager.add_data("data1", "file1.txt")
      manager.add_data("data2", "file2.txt")

      expect(manager.map(&:archive_path)).to eq(["file1.txt", "file2.txt"])
      expect(manager.select { |e| e.archive_path.start_with?("file") }.size).to eq(2)
    end
  end

  describe "#empty?" do
    it "returns true when no files added" do
      expect(manager).to be_empty
    end

    it "returns false when files added" do
      manager.add_data("test", " test.txt")

      expect(manager).not_to be_empty
    end
  end

  describe "#size" do
    it "returns number of entries" do
      expect(manager.size).to eq(0)

      manager.add_data("data1", "file1.txt")
      expect(manager.size).to eq(1)

      manager.add_data("data2", "file2.txt")
      expect(manager.size).to eq(2)
    end
  end

  describe "#count" do
    it "is an alias for size" do
      manager.add_data("data", "file.txt")

      expect(manager.count).to eq(manager.size)
      expect(manager.count).to eq(1)
    end
  end

  describe "#[]" do
    it "returns entry by index" do
      entry1 = manager.add_data("data1", "file1.txt")
      entry2 = manager.add_data("data2", "file2.txt")

      expect(manager[0]).to eq(entry1)
      expect(manager[1]).to eq(entry2)
    end

    it "returns nil for out of bounds" do
      expect(manager[0]).to be_nil
      expect(manager[99]).to be_nil
    end
  end

  describe "#all" do
    it "returns copy of entries array" do
      entry1 = manager.add_data("data1", "file1.txt")
      entry2 = manager.add_data("data2", "file2.txt")

      entries = manager.all

      expect(entries).to eq([entry1, entry2])
      expect(entries).not_to be(manager.instance_variable_get(:@entries))
    end
  end

  describe "#clear" do
    it "removes all entries" do
      manager.add_data("data1", "file1.txt")
      manager.add_data("data2", "file2.txt")

      result = manager.clear

      expect(manager).to be_empty
      expect(result).to eq(manager)
    end
  end

  describe "#total_size" do
    it "returns sum of all file sizes" do
      manager.add_data("123", "file1.txt")      # 3 bytes
      manager.add_data("12345", "file2.txt")    # 5 bytes

      expect(manager.total_size).to eq(8)
    end

    it "returns 0 for empty manager" do
      expect(manager.total_size).to eq(0)
    end
  end

  describe "#disk_files" do
    it "returns only disk-based entries" do
      Dir.mktmpdir do |dir|
        source = File.join(dir, "test.txt")
        File.write(source, "disk")

        disk_entry = manager.add_file(source, "disk.txt")
        manager.add_data("memory", "memory.txt")

        disk_files = manager.disk_files

        expect(disk_files.size).to eq(1)
        expect(disk_files.first).to eq(disk_entry)
      end
    end
  end

  describe "#memory_files" do
    it "returns only memory-based entries" do
      Dir.mktmpdir do |dir|
        source = File.join(dir, "test.txt")
        File.write(source, "disk")

        manager.add_file(source, "disk.txt")
        memory_entry = manager.add_data("memory", "memory.txt")

        memory_files = manager.memory_files

        expect(memory_files.size).to eq(1)
        expect(memory_files.first).to eq(memory_entry)
      end
    end
  end

  describe "#find_by_path" do
    it "finds entry by archive path" do
      entry = manager.add_data("data", "target/file.txt")
      manager.add_data("other", "other.txt")

      found = manager.find_by_path("target/file.txt")

      expect(found).to eq(entry)
    end

    it "returns nil if not found" do
      manager.add_data("data", "file.txt")

      expect(manager.find_by_path("nonexistent.txt")).to be_nil
    end
  end

  describe "#path_exists?" do
    it "returns true if path exists" do
      manager.add_data("data", "file.txt")

      expect(manager.path_exists?("file.txt")).to be true
    end

    it "returns false if path doesn't exist" do
      expect(manager.path_exists?("nonexistent.txt")).to be false
    end
  end
end