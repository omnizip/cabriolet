# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Cabriolet::Repairer do
  let(:valid_cab) { fixture_path("libmspack", "cabd", "normal_2files_1folder.cab") }

  describe "#initialize" do
    it "accepts a file path" do
      repairer = described_class.new(valid_cab)
      expect(repairer).to be_a(described_class)
    end

    it "accepts options" do
      repairer = described_class.new(valid_cab, skip_corrupted: true)
      expect(repairer).to be_a(described_class)
    end
  end

  describe "#repair" do
    it "repairs a valid archive" do
      Dir.mktmpdir do |dir|
        output = File.join(dir, "repaired.cab")
        repairer = described_class.new(valid_cab)
        report = repairer.repair(output: output)

        expect(report).to be_a(Cabriolet::RepairReport)
      end
    end
  end

  describe "#salvage" do
    it "salvages files from a valid archive" do
      Dir.mktmpdir do |dir|
        repairer = described_class.new(valid_cab)
        report = repairer.salvage(output_dir: dir)

        expect(report).to be_a(Cabriolet::SalvageReport)
        expect(report.salvaged_files).to be_an(Array)
      end
    end
  end

  describe Cabriolet::RepairReport do
    it "tracks success status" do
      report = described_class.new(
        success: true,
        original_file: "input.cab",
        repaired_file: "output.cab",
        stats: { recovered: 2, failed: 0 },
      )
      expect(report.success?).to be(true)
    end

    it "provides a summary" do
      report = described_class.new(
        success: true,
        original_file: "input.cab",
        repaired_file: "output.cab",
        stats: { recovered: 5, failed: 0 },
      )
      expect(report.summary).to be_a(String)
      expect(report.summary).to include("5")
    end
  end

  describe Cabriolet::SalvageReport do
    it "tracks salvaged files" do
      report = described_class.new(
        output_dir: "/tmp/salvaged",
        stats: { recovered: 3, failed: 1 },
        salvaged_files: %w[a.txt b.txt c.txt],
      )
      expect(report.salvaged_files.length).to eq(3)
      expect(report.stats[:recovered]).to eq(3)
    end

    it "provides a summary" do
      report = described_class.new(
        output_dir: "/tmp/salvaged",
        stats: { recovered: 3, failed: 1 },
        salvaged_files: [],
      )
      expect(report.summary).to be_a(String)
    end
  end

  describe Cabriolet::Repairer::RecoveredFile do
    it "tracks complete status" do
      file = Cabriolet::Models::File.new
      recovered = described_class.new(file, "data", :complete)
      expect(recovered.complete?).to be(true)
      expect(recovered.partial?).to be(false)
    end

    it "tracks partial status" do
      file = Cabriolet::Models::File.new
      recovered = described_class.new(file, "partial data", :partial)
      expect(recovered.partial?).to be(true)
      expect(recovered.complete?).to be(false)
    end
  end
end
