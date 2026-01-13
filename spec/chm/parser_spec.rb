# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require_relative "../support/fixtures"

RSpec.describe Cabriolet::CHM::Parser do
  describe "#parse" do
    context "with basic CHM file" do
      let(:fixture) { Fixtures.for(:chm).path(:encints_64bit_both) }

      it "parses CHM file successfully" do
        File.open(fixture, "rb") do |io|
          parser = described_class.new(io)
          chm = parser.parse

          expect(chm).to be_a(Cabriolet::Models::CHMHeader)
          expect(chm.version.to_i).to be_a(Integer)
          expect(chm.chunk_size).to be > 0
          expect(chm.num_chunks).to be > 0
        end
      end

      it "parses file entries" do
        File.open(fixture, "rb") do |io|
          parser = described_class.new(io)
          chm = parser.parse(entire: true)

          expect(chm.all_files.length).to be > 0
        end
      end

      describe "CHM structure" do
        subject(:chm) do
          File.open(fixture, "rb") do |io|
            parser = described_class.new(io)
            parser.parse
          end
        end

        it { is_expected.to be_a(Cabriolet::Models::CHMHeader) }
        its(:length) { is_expected.to be > 0 }
        its(:version) { is_expected.to be > 0 }
        its(:chunk_size) { is_expected.to be > 0 }
        its(:num_chunks) { is_expected.to be > 0 }
      end

      describe "sections" do
        subject(:chm) do
          File.open(fixture, "rb") do |io|
            parser = described_class.new(io)
            parser.parse
          end
        end

        it "identifies sections correctly" do
          expect(chm.sec0).to be_a(Cabriolet::Models::CHMSecUncompressed)
          expect(chm.sec0.id).to eq(0)
          expect(chm.sec1).to be_a(Cabriolet::Models::CHMSecMSCompressed)
          expect(chm.sec1.id).to eq(1)
        end
      end
    end

    context "with multiple CHM fixtures" do
      Fixtures.for(:chm).scenario(:basic).each_with_index do |fixture, i|
        context "basic fixture #{i + 1}" do
          let(:basic_fixture) { fixture }

          it "parses successfully" do
            File.open(basic_fixture, "rb") do |io|
              parser = described_class.new(io)
              chm = parser.parse

              expect(chm).to be_a(Cabriolet::Models::CHMHeader)
              expect(chm.chunk_size).to be > 0
            end
          end
        end
      end
    end

    context "with CVE security test files" do
      it "parses CVE file without crashes" do
        fixture = Fixtures.for(:chm).edge_case(:cve_2015_4468)

        expect do
          File.open(fixture, "rb") do |io|
            parser = described_class.new(io)
            parser.parse
          end
        end.not_to raise_error
      end
    end

    context "with encoding test files" do
      it "parses 64-bit encoding file" do
        fixture = Fixtures.for(:chm).edge_case(:encints_64bit_both)

        File.open(fixture, "rb") do |io|
          parser = described_class.new(io)
          chm = parser.parse

          expect(chm).to be_a(Cabriolet::Models::CHMHeader)
          expect(chm.version.to_i).to be_a(Integer)
        end
      end
    end

    context "with fast parsing" do
      let(:fixture) { Fixtures.for(:chm).path(:encints_64bit_both) }

      it "parses headers without file entries" do
        File.open(fixture, "rb") do |io|
          parser = described_class.new(io)
          chm = parser.parse(entire: false)

          expect(chm).to be_a(Cabriolet::Models::CHMHeader)
          expect(chm.version.to_i).to be_a(Integer)
          expect(chm.files).to be_nil
        end
      end
    end

    context "with invalid files" do
      it "raises error for non-CHM files" do
        file = Tempfile.new(["test", ".bin"])
        file.write("NOT A CHM FILE")
        file.rewind

        expect do
          parser = described_class.new(file)
          parser.parse
        end.to raise_error(StandardError) # BinData raises IOError for truncated/invalid data

        file.close
        file.unlink
      end
    end
  end
end
