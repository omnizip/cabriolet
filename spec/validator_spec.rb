# frozen_string_literal: true

require "tempfile"
require "spec_helper"
require "json"

RSpec.describe Cabriolet::Validator do
  let(:cab_fixture) { fixture_path("libmspack", "cabd", "normal_2files_1folder.cab") }
  let(:chm_fixture) { fixture_path("chm", "imlib2_doc_v1x1x1_r1x0_20171019.chm") }

  describe "constants" do
    it "defines validation levels" do
      expect(described_class::LEVEL_QUICK).to eq(:quick)
      expect(described_class::LEVEL_STANDARD).to eq(:standard)
      expect(described_class::LEVEL_THOROUGH).to eq(:thorough)
    end
  end

  describe "#initialize" do
    it "accepts path and level" do
      validator = described_class.new(cab_fixture, level: described_class::LEVEL_QUICK)
      expect(validator).to be_a(described_class)
    end

    it "defaults to LEVEL_STANDARD" do
      validator = described_class.new(cab_fixture)
      report = validator.validate
      expect(report.level).to eq(:standard)
    end
  end

  describe "#validate" do
    context "with LEVEL_QUICK" do
      it "validates a CAB file" do
        validator = described_class.new(cab_fixture, level: described_class::LEVEL_QUICK)
        report = validator.validate

        expect(report).to be_a(Cabriolet::ValidationReport)
        expect(report.format).to eq(:cab)
      end

      it "reports error for non-existent file" do
        validator = described_class.new("/tmp/nonexistent.cab", level: described_class::LEVEL_QUICK)
        report = validator.validate

        expect(report.valid?).to be(false)
        expect(report.has_errors?).to be(true)
      end
    end

    context "with LEVEL_STANDARD" do
      it "validates a CAB file with structure checks" do
        validator = described_class.new(cab_fixture, level: described_class::LEVEL_STANDARD)
        report = validator.validate

        expect(report.format).to eq(:cab)
      end

      it "validates a CHM file" do
        validator = described_class.new(chm_fixture, level: described_class::LEVEL_STANDARD)
        report = validator.validate

        expect(report.format).to eq(:chm)
      end
    end

    it "returns a report with format detected" do
      validator = described_class.new(cab_fixture, level: described_class::LEVEL_QUICK)
      report = validator.validate
      expect(report.format).to eq(:cab)
    end

    it "handles unreadable files" do
      Tempfile.create(["unreadable", ".cab"]) do |f|
        f.write("MSCF#{"\x00" * 32}")
        f.close
        File.chmod(0o000, f.path)

        validator = described_class.new(f.path, level: described_class::LEVEL_QUICK)
        report = validator.validate
        expect(report.has_errors?).to be(true)
      ensure
        File.chmod(0o644, f.path)
      end
    end
  end

  describe Cabriolet::ValidationReport do
    let(:valid_report) do
      described_class.new(
        valid: true, format: :cab, level: :quick,
        errors: [], warnings: ["test warning"],
        path: "/tmp/test.cab"
      )
    end

    let(:invalid_report) do
      described_class.new(
        valid: false, format: :cab, level: :standard,
        errors: ["File corrupted"], warnings: [],
        path: "/tmp/bad.cab"
      )
    end

    describe "#valid?" do
      it "returns true for valid report" do
        expect(valid_report.valid?).to be(true)
      end

      it "returns false for invalid report" do
        expect(invalid_report.valid?).to be(false)
      end
    end

    describe "#has_errors?" do
      it "returns false when no errors" do
        expect(valid_report.has_errors?).to be(false)
      end

      it "returns true when errors present" do
        expect(invalid_report.has_errors?).to be(true)
      end
    end

    describe "#has_warnings?" do
      it "returns true when warnings present" do
        expect(valid_report.has_warnings?).to be(true)
      end

      it "returns false when no warnings" do
        expect(invalid_report.has_warnings?).to be(false)
      end
    end

    describe "#summary" do
      it "includes VALID status" do
        expect(valid_report.summary).to include("VALID")
      end

      it "includes INVALID status" do
        expect(invalid_report.summary).to include("INVALID")
      end

      it "includes format and level" do
        expect(valid_report.summary).to include("cab")
        expect(valid_report.summary).to include("quick")
      end
    end

    describe "#detailed_report" do
      it "generates a text report" do
        report = valid_report.detailed_report
        expect(report).to be_a(String)
        expect(report).to include("Validation Report")
        expect(report).to include("/tmp/test.cab")
      end

      it "includes errors when present" do
        report = invalid_report.detailed_report
        expect(report).to include("File corrupted")
      end
    end

    describe "#to_h" do
      it "returns a hash representation" do
        hash = valid_report.to_h
        expect(hash[:valid]).to be(true)
        expect(hash[:format]).to eq(:cab)
        expect(hash[:level]).to eq(:quick)
        expect(hash[:errors]).to eq([])
        expect(hash[:warnings]).to eq(["test warning"])
      end
    end

    describe "#to_json" do
      it "returns a JSON string" do
        json = valid_report.to_json
        parsed = JSON.parse(json)
        expect(parsed["valid"]).to be(true)
        expect(parsed["format"]).to eq("cab")
      end
    end

    describe "readers" do
      it "exposes all attributes" do
        expect(valid_report.valid).to be(true)
        expect(valid_report.format).to eq(:cab)
        expect(valid_report.level).to eq(:quick)
        expect(valid_report.errors).to eq([])
        expect(valid_report.warnings).to eq(["test warning"])
        expect(valid_report.path).to eq("/tmp/test.cab")
      end
    end
  end
end
