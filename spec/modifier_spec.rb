# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Cabriolet::Modifier do
  let(:cab_fixture) { fixture_path("libmspack", "cabd", "normal_2files_1folder.cab") }

  describe "#initialize" do
    it "detects format from file path" do
      modifier = described_class.new(cab_fixture)
      expect(modifier).to be_a(described_class)
    end
  end

  describe "file operations" do
    let(:modifier) { described_class.new(cab_fixture) }

    describe "#add_file" do
      it "adds a file modification entry" do
        modifier.add_file("new_file.txt", data: "hello world")
        preview = modifier.preview

        expect(preview).to be_an(Array)
        expect(preview.any? { |m| m[:action] == "ADD" }).to be(true)
      end

      it "requires source or data" do
        expect { modifier.add_file("test.txt") }.to raise_error(ArgumentError)
      end
    end

    describe "#remove_file" do
      it "adds a removal modification entry" do
        modifier.remove_file("hello.c")
        preview = modifier.preview

        expect(preview.any? { |m| m[:action] == "REMOVE" }).to be(true)
      end
    end

    describe "#rename_file" do
      it "adds a rename modification entry" do
        modifier.rename_file("hello.c", "renamed.c")
        preview = modifier.preview

        expect(preview.any? { |m| m[:action] == "RENAME" }).to be(true)
      end
    end

    describe "#update_file" do
      it "adds an update modification entry" do
        modifier.update_file("hello.c", data: "updated content")
        preview = modifier.preview

        expect(preview.any? { |m| m[:action] == "UPDATE" }).to be(true)
      end
    end
  end

  describe "#preview" do
    it "returns an array of modification hashes" do
      modifier = described_class.new(cab_fixture)
      modifier.add_file("new.txt", data: "data")

      expect(modifier.preview).to be_an(Array)
      expect(modifier.preview.length).to eq(1)
    end

    it "returns empty array when no modifications" do
      modifier = described_class.new(cab_fixture)
      expect(modifier.preview).to eq([])
    end
  end

  describe "#save" do
    it "saves modified archive to output path" do
      Dir.mktmpdir do |dir|
        output = File.join(dir, "modified.cab")
        modifier = described_class.new(cab_fixture)
        modifier.add_file("added.txt", data: "new content")

        report = modifier.save(output: output)
        expect(report).to be_a(Cabriolet::ModificationReport)
      end
    end
  end

  describe Cabriolet::ModificationReport do
    it "tracks success status" do
      report = described_class.new(
        success: true,
        original: "input.cab",
        output: "output.cab",
      )
      expect(report.success?).to be(true)
    end
  end
end
