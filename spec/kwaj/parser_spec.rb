# frozen_string_literal: true

require "spec_helper"
require_relative "../support/fixtures"

RSpec.describe Cabriolet::KWAJ::Parser do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:parser) { described_class.new(io_system) }

  describe "#initialize" do
    it "creates a new parser" do
      expect(parser).to be_a(described_class)
    end

    it "uses provided IO system" do
      expect(parser.io_system).to eq(io_system)
    end
  end

  describe "#parse" do
    context "with basic KWAJ fixtures" do
      let(:fixture) { Fixtures.for(:kwaj).path(:f00) }

      it "parses KWAJ file with no compression" do
        header = parser.parse(fixture)
        expect(header).to be_a(Cabriolet::Models::KWAJHeader)
        expect(header.comp_type).to eq(Cabriolet::Constants::KWAJ_COMP_NONE)
      end
    end

    context "with KWAJ file with filename header" do
      let(:fixture) { Fixtures.for(:kwaj).path(:f10) }

      it "parses KWAJ file with filename" do
        header = parser.parse(fixture)
        expect(header).to be_a(Cabriolet::Models::KWAJHeader)
        expect(header.comp_type).to eq(Cabriolet::Constants::KWAJ_COMP_NONE)
        expect(header.has_filename?).to be true
      end
    end

    context "with multiple KWAJ fixtures" do
      Fixtures.for(:kwaj).scenario(:basic).each_with_index do |fixture, i|
        context "KWAJ fixture #{i + 1}" do
          let(:kwaj_fixture) { fixture }

          it "parses successfully" do
            header = parser.parse(kwaj_fixture)
            expect(header).to be_a(Cabriolet::Models::KWAJHeader)
          end
        end
      end
    end

    context "with CVE security test file" do
      let(:cve_fixture) { Fixtures.for(:kwaj).edge_case(:cve_2018_14681) }

      # CVE-2018-14681 file has malformed headers that cause ParseError
      # This is expected behavior - the parser correctly rejects invalid input
      it "correctly rejects malformed CVE test file" do
        expect do
          parser.parse(cve_fixture)
        end.to raise_error(Cabriolet::ParseError)
      end
    end

    context "with invalid files" do
      it "raises ParseError for non-KWAJ file" do
        cab_fixture = Fixtures.for(:cab).path(:basic)

        expect do
          parser.parse(cab_fixture)
        end.to raise_error(Cabriolet::ParseError, /Invalid KWAJ signature/)
      end

      it "raises IOError for non-existent file" do
        expect do
          parser.parse("/nonexistent/file.kwj")
        end.to raise_error(Cabriolet::IOError)
      end
    end
  end

  describe "#parse_handle" do
    let(:fixture) { Fixtures.for(:kwaj).path(:f00) }

    it "parses from an open file handle" do
      handle = io_system.open(fixture, Cabriolet::Constants::MODE_READ)

      header = parser.parse_handle(handle)

      expect(header).to be_a(Cabriolet::Models::KWAJHeader)
      expect(header.comp_type).to eq(Cabriolet::Constants::KWAJ_COMP_NONE)

      io_system.close(handle)
    end
  end
end
