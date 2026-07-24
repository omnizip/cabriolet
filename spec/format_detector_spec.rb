# frozen_string_literal: true

require "tempfile"
require "spec_helper"

RSpec.describe Cabriolet::FormatDetector do
  let(:cab_fixture) { fixture_path("libmspack", "cabd", "normal_2files_1folder.cab") }
  let(:chm_fixture) { fixture_path("chm", "imlib2_doc_v1x1x1_r1x0_20171019.chm") }
  let(:lit_fixture) { fixture_path("atudl_lit", "bill.lit") }
  let(:oab_fixture) { fixture_path("oab", "test_simple.oab") }

  describe ".detect" do
    it "detects CAB format from magic bytes" do
      expect(described_class.detect(cab_fixture)).to eq(:cab)
    end

    it "detects CHM format from magic bytes" do
      expect(described_class.detect(chm_fixture)).to eq(:chm)
    end

    it "detects LIT format from magic bytes" do
      expect(described_class.detect(lit_fixture)).to eq(:lit)
    end

    it "returns nil for non-existent file" do
      expect(described_class.detect("/tmp/nonexistent_file")).to be_nil
    end

    it "returns nil for unknown format" do
      Tempfile.create(["unknown", ".txt"]) do |f|
        f.write("not an archive")
        f.close
        expect(described_class.detect(f.path)).to be_nil
      end
    end
  end

  describe ".detect_from_io" do
    it "detects format from an IO stream" do
      File.open(cab_fixture, "rb") do |io|
        expect(described_class.detect_from_io(io)).to eq(:cab)
      end
    end

    it "returns nil for insufficient data" do
      io = StringIO.new("AB")
      expect(described_class.detect_from_io(io)).to be_nil
    end
  end

  describe ".parser_for" do
    it "returns parser class for CAB" do
      expect(described_class.parser_for(cab_fixture)).to eq(Cabriolet::CAB::Parser)
    end

    it "returns parser class for CHM" do
      expect(described_class.parser_for(chm_fixture)).to eq(Cabriolet::CHM::Parser)
    end

    it "returns nil for unknown format" do
      Tempfile.create(["unknown", ".txt"]) do |f|
        f.write("not an archive")
        f.close
        expect(described_class.parser_for(f.path)).to be_nil
      end
    end
  end

  describe ".format_to_parser" do
    it "returns CAB parser for :cab" do
      expect(described_class.format_to_parser(:cab)).to eq(Cabriolet::CAB::Parser)
    end

    it "returns CHM parser for :chm" do
      expect(described_class.format_to_parser(:chm)).to eq(Cabriolet::CHM::Parser)
    end

    it "returns nil for unknown format" do
      expect(described_class.format_to_parser(:unknown)).to be_nil
    end
  end

  describe ".register_parser" do
    after do
      described_class.clear_registered_parsers
    end

    it "allows runtime parser registration" do
      custom_parser = Class.new
      described_class.register_parser(:custom, custom_parser)

      expect(described_class.format_to_parser(:custom)).to eq(custom_parser)
    end

    it "overrides built-in parser when registered" do
      custom_parser = Class.new
      described_class.register_parser(:cab, custom_parser)

      expect(described_class.format_to_parser(:cab)).to eq(custom_parser)
    end
  end

  describe "constants" do
    it "defines magic signatures" do
      expect(described_class::MAGIC_SIGNATURES).to include("MSCF" => :cab)
      expect(described_class::MAGIC_SIGNATURES).to include("ITSF" => :chm)
    end

    it "defines extension map" do
      expect(described_class::EXTENSION_MAP).to include(".cab" => :cab)
      expect(described_class::EXTENSION_MAP).to include(".chm" => :chm)
    end
  end
end
