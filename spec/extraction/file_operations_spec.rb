# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Cabriolet::Extraction::FileOperations do
  let(:test_class) do
    Class.new do
      include Cabriolet::Extraction::FileOperations
    end
  end
  let(:ops) { test_class.new }

  describe "#build_output_path" do
    it "preserves directory structure when preserve_paths is true" do
      path = ops.build_output_path("dir/subdir/file.txt", "/output", true)
      expect(path).to eq("/output/dir/subdir/file.txt")
    end

    it "flattens to basename when preserve_paths is false" do
      path = ops.build_output_path("dir/subdir/file.txt", "/output", false)
      expect(path).to eq("/output/file.txt")
    end

    it "normalizes backslashes to forward slashes" do
      path = ops.build_output_path("dir\\file.txt", "/output", true)
      expect(path).to eq("/output/dir/file.txt")
    end
  end

  describe "#normalize_filename" do
    it "converts backslashes to forward slashes" do
      expect(ops.normalize_filename("a\\b\\c.txt")).to eq("a/b/c.txt")
    end

    it "leaves forward slashes unchanged" do
      expect(ops.normalize_filename("a/b/c.txt")).to eq("a/b/c.txt")
    end
  end

  describe "#ensure_parent_dir" do
    it "creates parent directory if it does not exist" do
      Dir.mktmpdir do |base|
        path = File.join(base, "subdir", "file.txt")
        ops.ensure_parent_dir(path)
        expect(File.directory?(File.join(base, "subdir"))).to be(true)
      end
    end

    it "does not fail if directory already exists" do
      Dir.mktmpdir do |base|
        path = File.join(base, "file.txt")
        ops.ensure_parent_dir(path)
        expect(File.directory?(base)).to be(true)
      end
    end
  end

  describe "#write_file" do
    it "writes binary data to a file" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "test.bin")
        ops.write_file(path, "\x00\x01\x02\x03")
        expect(File.binread(path)).to eq("\x00\x01\x02\x03")
      end
    end
  end

  describe "#preserve_file_attributes" do
    it "preserves timestamps when file has datetime" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "test.txt")
        File.write(path, "data")

        file = Struct.new(:datetime, keyword_init: true).new(datetime: Time.now - 3600)
        ops.preserve_file_attributes(path, file)

        mtime = File.mtime(path)
        expect(mtime.to_i).to be_within(2).of(file.datetime.to_i)
      end
    end

    it "does nothing when file has no datetime" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "test.txt")
        File.write(path, "data")
        original_mtime = File.mtime(path)

        file = Struct.new(:datetime, keyword_init: true).new(datetime: nil)
        ops.preserve_file_attributes(path, file)

        expect(File.mtime(path).to_i).to eq(original_mtime.to_i)
      end
    end
  end
end
