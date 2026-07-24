# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Cabriolet::Streaming do
  let(:cab_fixture) { fixture_path("libmspack", "cabd", "normal_2files_1folder.cab") }
  let(:chunk_size) { 1024 }

  describe Cabriolet::Streaming::StreamParser do
    describe "#initialize" do
      it "accepts a path and chunk size" do
        parser = described_class.new(cab_fixture, chunk_size: chunk_size)
        expect(parser).to be_a(described_class)
      end

      it "uses default chunk size when not specified" do
        parser = described_class.new(cab_fixture)
        expect(parser).to be_a(described_class)
      end

      it "raises for unsupported format" do
        expect do
          described_class.new("/tmp/nonexistent_file_xyz.cab")
        end.to raise_error(Cabriolet::UnsupportedFormatError)
      end
    end

    describe "#each_file" do
      it "yields files from a CAB archive" do
        parser = described_class.new(cab_fixture)
        files = parser.each_file.to_a

        expect(files).not_to be_empty
        expect(files.first).to be_a(Cabriolet::Streaming::LazyFile)
      end

      it "returns an enumerator when no block given" do
        parser = described_class.new(cab_fixture)
        expect(parser.each_file).to be_an(Enumerator)
      end
    end
  end

  describe Cabriolet::Streaming::LazyFile do
    TestStreamFile = Struct.new(:name, :size, :attributes, :date, :time, :data, keyword_init: true)

    let(:test_data) { "A" * 200 }
    let(:inner_file) { TestStreamFile.new(name: "test.txt", size: 200, attributes: 0x20, date: nil, time: nil, data: test_data) }
    let(:lazy) { described_class.new(inner_file, 64) }

    it "delegates name" do
      expect(lazy.name).to eq("test.txt")
    end

    it "delegates size" do
      expect(lazy.size).to eq(200)
    end

    it "delegates attributes" do
      expect(lazy.attributes).to eq(0x20)
    end

    it "loads data lazily" do
      expect(lazy.data).to eq(test_data)
    end

    it "streams data in chunks" do
      chunks = []
      lazy.stream_data(chunk_size: 64) { |chunk| chunks << chunk }

      expect(chunks.length).to eq(4)
      expect(chunks.map(&:bytesize).sum).to eq(200)
    end

    it "does not use method_missing for unknown methods" do
      expect { lazy.nonexistent_method }.to raise_error(NoMethodError)
    end
  end

  describe Cabriolet::Streaming::BatchProcessor do
    let(:processor) { described_class.new(chunk_size: chunk_size) }

    describe "#process_archive" do
      it "yields files from an archive" do
        files = []
        processor.process_archive(cab_fixture) { |file, path| files << [file, path] }

        expect(files).not_to be_empty
        expect(files.first.last).to eq(cab_fixture)
      end
    end

    describe "#stats" do
      it "tracks processing statistics" do
        expect(processor.stats).to include(:processed, :failed, :bytes)
      end
    end
  end
end
