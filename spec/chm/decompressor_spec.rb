# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require_relative "../support/fixtures"

RSpec.describe Cabriolet::CHM::Decompressor do
  let(:fixture_file) { Fixtures.for(:chm).path(:encints_64bit_both) }

  describe "#initialize" do
    context "with default options" do
      subject(:decompressor) { described_class.new }

      it { is_expected.to be_a(described_class) }
    end
  end

  describe "#open" do
    let(:decompressor) { described_class.new }

    context "with valid CHM file" do
      subject(:chm) do
        result = decompressor.open(fixture_file)
        result
      end

      after { decompressor.close }

      it { is_expected.to be_a(Cabriolet::Models::CHMHeader) }
      its(:filename) { is_expected.to eq(fixture_file) }
      its(:num_chunks) { is_expected.to be > 0 }

      it "parses all file entries by default" do
        expect(subject.all_files.length).to be > 0
      end
    end

    context "with multiple fixtures" do
      let(:decompressor) { described_class.new }

      Fixtures.for(:chm).scenario(:basic).each_with_index do |fixture, i|
        context "basic fixture #{i + 1}" do
          let(:basic_fixture) { fixture }

          it "opens successfully" do
            chm = decompressor.open(basic_fixture)
            expect(chm).to be_a(Cabriolet::Models::CHMHeader)
            expect(chm.chunk_size).to be > 0
            decompressor.close
          end
        end
      end
    end
  end

  describe "#fast_open" do
    let(:decompressor) { described_class.new }

    context "with valid CHM file" do
      subject(:chm) do
        result = decompressor.fast_open(fixture_file)
        result
      end

      after { decompressor.close }

      it { is_expected.to be_a(Cabriolet::Models::CHMHeader) }
      its(:files) { is_expected.to be_nil }
    end
  end

  describe "#close" do
    let(:decompressor) { described_class.new }

    context "after opening file" do
      before { decompressor.open(fixture_file) }

      it "closes without error" do
        expect { decompressor.close }.not_to raise_error
      end
    end
  end

  describe "#extract" do
    let(:decompressor) { described_class.new }
    let(:temp_dir) { Dir.mktmpdir }

    after { FileUtils.rm_rf(temp_dir) }

    context "extracting files from CHM" do
      before { decompressor.open(fixture_file) }

      it "can list all files for extraction" do
        chm = decompressor.instance_variable_get(:@chm)
        expect(chm.all_files.length).to be > 0
      end

      after { decompressor.close }
    end
  end

  describe "error handling" do
    let(:decompressor) { described_class.new }

    context "with non-existent file" do
      it "raises error" do
        expect { decompressor.open("/nonexistent/file.chm") }.to raise_error
      end
    end

    context "with invalid CHM file" do
      let(:invalid_file) do
        file = Tempfile.new(["test", ".chm"])
        file.write("NOT A CHM FILE")
        file.close
        file.path
      end

      it "raises error for invalid data" do
        expect { decompressor.open(invalid_file) }.to raise_error(StandardError)
      end
    end
  end

  describe "fixture compatibility" do
    let(:decompressor) { described_class.new }

    context "with edge case fixtures" do
      it "opens CVE test files" do
        cve_fixture = Fixtures.for(:chm).edge_case(:cve_2015_4468)
        chm = decompressor.open(cve_fixture)
        expect(chm).to be_a(Cabriolet::Models::CHMHeader)
        decompressor.close
      end
    end
  end
end
