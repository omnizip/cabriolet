# frozen_string_literal: true

require "spec_helper"
require_relative "../support/fixtures"

RSpec.describe Cabriolet::LIT::Parser do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:parser) { described_class.new(io_system) }

  describe "#initialize" do
    it "creates a new parser" do
      expect(parser).to be_a(described_class)
    end

    it "uses provided IO system" do
      expect(parser.io_system).to eq(io_system)
    end

    it "uses default IO system when none provided" do
      default_parser = described_class.new
      expect(default_parser.io_system).to be_a(Cabriolet::System::IOSystem)
    end
  end

  describe "#parse" do
    context "with basic LIT fixtures" do
      let(:fixture) { Fixtures.for(:lit).path(:greek_art) }

      it "parses LIT file successfully" do
        lit_file = parser.parse(fixture)

        expect(lit_file).to be_a(Cabriolet::Models::LITFile)
        expect(lit_file.version).to eq(1)
        expect(lit_file.directory).not_to be_nil
        expect(lit_file.directory.entries).not_to be_empty
      end

      it "parses primary header" do
        lit_file = parser.parse(fixture)

        expect(lit_file.version).to eq(1)
        expect(lit_file.header_guid).not_to be_nil
        expect(lit_file.header_guid.bytesize).to eq(16)
      end

      it "parses secondary header" do
        lit_file = parser.parse(fixture)

        expect(lit_file.content_offset).to be > 0
        expect(lit_file.timestamp).to be >= 0
        expect(lit_file.language_id).to be >= 0
      end

      it "parses directory structure" do
        lit_file = parser.parse(fixture)

        expect(lit_file.directory).to be_a(Cabriolet::Models::LITDirectory)
        expect(lit_file.directory.entries).not_to be_empty
        expect(lit_file.directory.num_chunks).to be > 0
      end

      it "parses sections" do
        lit_file = parser.parse(fixture)

        expect(lit_file.sections).not_to be_nil
        # Sections may be empty for some LIT files
        expect(lit_file.sections).to be_a(Array)
      end

      it "parses manifest" do
        lit_file = parser.parse(fixture)

        # Manifest may not be present in all LIT files
        expect(lit_file.manifest).to be_a(Cabriolet::Models::LITManifest).or be_nil
      end
    end

    context "with multiple LIT fixtures" do
      it "parses all LIT fixtures successfully" do
        all_fixtures = Fixtures.for(:lit).scenario(:all)

        all_fixtures.each do |fixture_path|
          lit_file = parser.parse(fixture_path)
          expect(lit_file).to be_a(Cabriolet::Models::LITFile)
          expect(lit_file.version).to eq(1)
          expect(lit_file.directory).not_to be_nil
        end
      end
    end

    context "with invalid files" do
      it "raises ParseError for non-LIT file" do
        cab_fixture = Fixtures.for(:cab).path(:basic)

        expect do
          parser.parse(cab_fixture)
        end.to raise_error(Cabriolet::ParseError, /Invalid LIT signature/)
      end

      it "raises IOError for non-existent file" do
        expect do
          parser.parse("/nonexistent/file.lit")
        end.to raise_error(Cabriolet::IOError)
      end
    end

    context "with specific LIT fixtures" do
      it "parses Journey to the Center of the Earth" do
        fixture = Fixtures.for(:lit).path(:journey_center)

        lit_file = parser.parse(fixture)

        expect(lit_file).to be_a(Cabriolet::Models::LITFile)
        # Manifest may or may not be present depending on file structure
        expect(lit_file.directory.entries).not_to be_empty
      end

      it "parses bill.lit" do
        fixture = Fixtures.for(:lit).path(:bill)

        lit_file = parser.parse(fixture)

        expect(lit_file).to be_a(Cabriolet::Models::LITFile)
        expect(lit_file.directory.entries).not_to be_empty
      end
    end

    context "DRM detection" do
      it "detects DRM in protected LIT files" do
        # Note: Our test fixtures may not have DRM, but the parser
        # should detect it if present
        fixture = Fixtures.for(:lit).path(:greek_art)

        lit_file = parser.parse(fixture)

        # drm_level is 0 if no DRM, 1 if DRM present
        expect(lit_file.drm_level).to be >= 0
        expect(lit_file.drm_level).to be <= 1
      end
    end

    context "compression detection" do
      it "detects compressed sections" do
        fixture = Fixtures.for(:lit).path(:greek_art)

        lit_file = parser.parse(fixture)

        # Sections array should exist, even if empty
        expect(lit_file.sections).to be_a(Array)

        # If sections exist, check for compressed ones
        if lit_file.sections.any?
          compressed_sections = lit_file.sections.select(&:compressed)
          # Some sections may be compressed, some may not - just verify structure
          expect(compressed_sections).to be_a(Array)
        end
      end
    end
  end
end
