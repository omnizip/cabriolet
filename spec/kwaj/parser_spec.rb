# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::KWAJ::Parser do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:parser) { described_class.new(io_system) }

  describe "#parse" do
    context "with valid KWAJ files" do
      it "parses KWAJ file with no compression (f00.kwj)" do
        file = fixture_path("libmspack/kwajd/f00.kwj")
        header = parser.parse(file)

        expect(header).to be_a(Cabriolet::Models::KWAJHeader)
        expect(header.comp_type).to eq(Cabriolet::Constants::KWAJ_COMP_NONE)
      end

      it "parses KWAJ file with filename header (f10.kwj)" do
        file = fixture_path("libmspack/kwajd/f10.kwj")
        header = parser.parse(file)

        expect(header).to be_a(Cabriolet::Models::KWAJHeader)
        expect(header.comp_type).to eq(Cabriolet::Constants::KWAJ_COMP_NONE)
        expect(header.has_filename?).to be true
      end

      it "parses KWAJ file with both filename and extension (f11.kwj)" do
        file = fixture_path("libmspack/kwajd/f11.kwj")
        header = parser.parse(file)

        expect(header).to be_a(Cabriolet::Models::KWAJHeader)
        expect(header.comp_type).to eq(Cabriolet::Constants::KWAJ_COMP_NONE)
        expect(header.has_filename?).to be true
        expect(header.has_file_extension?).to be true
      end
    end

    context "with optional headers" do
      it "parses with no optional headers (f00.kwj)" do
        file = fixture_path("libmspack/kwajd/f00.kwj")
        header = parser.parse(file)

        expect(header.has_length?).to be false
        expect(header.has_filename?).to be false
        expect(header.has_file_extension?).to be false
        expect(header.length).to be_nil
        expect(header.filename).to be_nil
      end
    end

    context "with invalid files" do
      it "raises ParseError for non-KWAJ file" do
        file = fixture_path("libmspack/cabd/normal_2files_1folder.cab")

        expect do
          parser.parse(file)
        end.to raise_error(Cabriolet::ParseError, /Invalid KWAJ signature/)
      end

      it "raises ParseError for truncated file" do
        # Create a truncated file
        truncated = temp_file("truncated.kwj")
        File.write(truncated, "KWAJ\x88\xF0")

        expect do
          parser.parse(truncated)
        end.to raise_error(Cabriolet::ParseError)
      ensure
        FileUtils.rm_f(truncated)
      end
    end
  end

  describe "#parse_handle" do
    it "parses from an open file handle" do
      file = fixture_path("libmspack/kwajd/f00.kwj")
      handle = io_system.open(file, Cabriolet::Constants::MODE_READ)

      header = parser.parse_handle(handle)

      expect(header).to be_a(Cabriolet::Models::KWAJHeader)
      expect(header.comp_type).to eq(Cabriolet::Constants::KWAJ_COMP_NONE)

      io_system.close(handle)
    end
  end

  def fixture_path(path)
    File.join(__dir__, "..", "fixtures", path)
  end

  def temp_file(name)
    File.join(Dir.tmpdir, name)
  end
end
