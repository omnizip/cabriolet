# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Cabriolet::FileEntry do
  describe "#initialize" do
    context "with disk file" do
      it "creates entry from disk file" do
        Dir.mktmpdir do |dir|
          source = File.join(dir, "test.txt")
          File.write(source, "test content")

          entry = described_class.new(
            source: source,
            archive_path: "docs/test.txt",
          )

          expect(entry.source_path).to eq(source)
          expect(entry.archive_path).to eq("docs/test.txt")
          expect(entry.from_disk?).to be true
          expect(entry.from_memory?).to be false
        end
      end

      it "raises error if file doesn't exist" do
        expect do
          described_class.new(
            source: "/nonexistent/file.txt",
            archive_path: "test.txt",
          )
        end.to raise_error(ArgumentError, /File not found/)
      end

      it "raises error if source is a directory" do
        Dir.mktmpdir do |dir|
          expect do
            described_class.new(
              source: dir,
              archive_path: "test.txt",
            )
          end.to raise_error(ArgumentError, /Not a file/)
        end
      end
    end

    context "with memory data" do
      it "creates entry from memory data" do
        entry = described_class.new(
          data: "Hello, World!",
          archive_path: "greeting.txt",
        )

        expect(entry.data).to eq("Hello, World!")
        expect(entry.archive_path).to eq("greeting.txt")
        expect(entry.from_disk?).to be false
        expect(entry.from_memory?).to be true
      end
    end

    context "validation" do
      it "requires either source or data" do
        expect do
          described_class.new(archive_path: "test.txt")
        end.to raise_error(ArgumentError, /Must provide either source or data/)
      end

      it "rejects both source and data" do
        expect do
          described_class.new(
            source: "file.txt",
            data: "content",
            archive_path: "test.txt",
          )
        end.to raise_error(ArgumentError, /Cannot provide both/)
      end

      it "requires archive_path" do
        expect do
          described_class.new(data: "content")
        end.to raise_error(ArgumentError) # Will be keyword argument error from Ruby
      end
    end

    context "with options" do
      it "stores custom options" do
        entry = described_class.new(
          data: "test",
          archive_path: "test.txt",
          compress: false,
          custom: "value",
        )

        expect(entry.options[:compress]).to be false
        expect(entry.options[:custom]).to eq("value")
      end
    end
  end

  describe "#read_data" do
    it "returns memory data for memory files" do
      entry = described_class.new(
        data: "Hello, World!",
        archive_path: "test.txt",
      )

      expect(entry.read_data).to eq("Hello, World!")
    end

    it "reads data from disk for disk files" do
      Dir.mktmpdir do |dir|
        source = File.join(dir, "test.txt")
        File.write(source, "disk content")

        entry = described_class.new(
          source: source,
          archive_path: "test.txt",
        )

        expect(entry.read_data).to eq("disk content")
      end
    end
  end

  describe "#size" do
    it "returns data size for memory files" do
      entry = described_class.new(
        data: "Hello",
        archive_path: "test.txt",
      )

      expect(entry.size).to eq(5)
    end

    it "returns file size for disk files" do
      Dir.mktmpdir do |dir|
        source = File.join(dir, "test.txt")
        File.write(source, "Hello, World!")

        entry = described_class.new(
          source: source,
          archive_path: "test.txt",
        )

        expect(entry.size).to eq(13)
      end
    end
  end

  describe "#stat" do
    it "returns nil for memory files" do
      entry = described_class.new(
        data: "test",
        archive_path: "test.txt",
      )

      expect(entry.stat).to be_nil
    end

    it "returns File::Stat for disk files" do
      Dir.mktmpdir do |dir|
        source = File.join(dir, "test.txt")
        File.write(source, "test")

        entry = described_class.new(
          source: source,
          archive_path: "test.txt",
        )

        expect(entry.stat).to be_a(File::Stat)
      end
    end
  end

  describe "#mtime" do
    it "returns current time for memory files" do
      entry = described_class.new(
        data: "test",
        archive_path: "test.txt",
      )

      expect(entry.mtime).to be_a(Time)
      expect(entry.mtime).to be_within(1).of(Time.now)
    end

    it "returns file mtime for disk files" do
      Dir.mktmpdir do |dir|
        source = File.join(dir, "test.txt")
        File.write(source, "test")

        entry = described_class.new(
          source: source,
          archive_path: "test.txt",
        )

        expect(entry.mtime).to be_a(Time)
        expect(entry.mtime).to be_within(2).of(File.mtime(source))
      end
    end
  end

  describe "#attributes" do
    it "returns ATTRIB_ARCH for memory files by default" do
      entry = described_class.new(
        data: "test",
        archive_path: "test.txt",
      )

      expect(entry.attributes).to eq(Cabriolet::Constants::ATTRIB_ARCH)
    end

    it "returns custom attributes if provided" do
      entry = described_class.new(
        data: "test",
        archive_path: "test.txt",
        attributes: 0x25,
      )

      expect(entry.attributes).to eq(0x25)
    end

    it "calculates attributes for disk files" do
      Dir.mktmpdir do |dir|
        source = File.join(dir, "test.txt")
        File.write(source, "test")

        entry = described_class.new(
          source: source,
          archive_path: "test.txt",
        )

        expect(entry.attributes).to be_a(Integer)
        expect(entry.attributes & Cabriolet::Constants::ATTRIB_ARCH).to be > 0
      end
    end
  end

  describe "#compress?" do
    it "defaults to true" do
      entry = described_class.new(
        data: "test",
        archive_path: "test.txt",
      )

      expect(entry.compress?).to be true
    end

    it "respects compress option" do
      entry = described_class.new(
        data: "test",
        archive_path: "test.txt",
        compress: false,
      )

      expect(entry.compress?).to be false
    end
  end
end
