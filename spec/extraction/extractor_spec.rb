# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Cabriolet::Extraction::Extractor do
  TestFile = Struct.new(:name, :size, :data, :datetime, keyword_init: true)
  TestArchive = Struct.new(:files, keyword_init: true)

  let(:test_files) do
    [
      TestFile.new(name: "file1.txt", size: 5, data: "hello", datetime: nil),
      TestFile.new(name: "file2.txt", size: 5, data: "world", datetime: nil),
    ]
  end
  let(:archive) { TestArchive.new(files: test_files) }

  describe "#initialize" do
    it "accepts archive, output_dir, and options" do
      Dir.mktmpdir do |dir|
        extractor = described_class.new(archive, dir, workers: 1)
        expect(extractor).to be_a(described_class)
      end
    end

    it "defaults workers to DEFAULT_WORKERS" do
      Dir.mktmpdir do |dir|
        extractor = described_class.new(archive, dir)
        expect(extractor.workers).to eq(described_class::DEFAULT_WORKERS)
      end
    end
  end

  describe "#extract_all" do
    it "extracts all files from the archive" do
      Dir.mktmpdir do |dir|
        extractor = described_class.new(archive, dir, workers: 1)
        stats = extractor.extract_all

        expect(stats[:extracted]).to eq(2)
      end
    end

    it "creates output files with correct content" do
      Dir.mktmpdir do |dir|
        extractor = described_class.new(archive, dir, workers: 1)
        extractor.extract_all

        expect(File.read(File.join(dir, "file1.txt"))).to eq("hello")
        expect(File.read(File.join(dir, "file2.txt"))).to eq("world")
      end
    end
  end

  describe "#extract_with_progress" do
    it "yields progress during extraction" do
      Dir.mktmpdir do |dir|
        extractor = described_class.new(archive, dir, workers: 1)
        progress_calls = 0

        extractor.extract_with_progress { |_result| progress_calls += 1 }

        expect(progress_calls).to be > 0
      end
    end
  end

  describe "#stats" do
    it "tracks extraction statistics" do
      Dir.mktmpdir do |dir|
        extractor = described_class.new(archive, dir, workers: 1)
        extractor.extract_all

        expect(extractor.stats).to include(:extracted, :failed)
      end
    end
  end

  describe "readers" do
    it "exposes archive, output_dir, workers" do
      Dir.mktmpdir do |dir|
        extractor = described_class.new(archive, dir, workers: 2)
        expect(extractor.archive).to eq(archive)
        expect(extractor.output_dir).to eq(dir)
        expect(extractor.workers).to eq(2)
      end
    end
  end
end
