# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "cabriolet/cli"

RSpec.describe Cabriolet::CLI do
  let(:fixture_file) do
    File.join(__dir__, "fixtures/libmspack/cabd/normal_2files_1folder.cab")
  end

  describe ".exit_on_failure?" do
    it "returns true" do
      expect(described_class.exit_on_failure?).to be(true)
    end
  end

  describe "#list" do
    let(:cli) { described_class.new }

    it "lists cabinet contents" do
      expect do
        cli.list(fixture_file)
      end.to output(/Cabinet:/).to_stdout
    end

    it "displays set ID and index" do
      expect do
        cli.list(fixture_file)
      end.to output(/Set ID:/).to_stdout
    end

    it "displays folder and file counts" do
      expect do
        cli.list(fixture_file)
      end.to output(/Folders:.*Files:/).to_stdout
    end

    it "lists individual files" do
      expect do
        cli.list(fixture_file)
      end.to output(/bytes/).to_stdout
    end

    context "with verbose flag" do
      it "enables verbose output" do
        expect(Cabriolet).to receive(:verbose=).with(true)
        cli.invoke(:list, [fixture_file], verbose: true)
      end
    end

    context "with invalid file" do
      it "aborts with error message" do
        expect do
          cli.list("/nonexistent.cab")
        end.to raise_error(Cabriolet::Error)
      end
    end
  end

  describe "#extract" do
    let(:cli) { described_class.new }

    it "extracts files to current directory by default" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          expect do
            cli.extract(fixture_file)
          end.to output(/Extracted/).to_stdout
        end
      end
    end

    it "extracts files to specified directory" do
      Dir.mktmpdir do |output_dir|
        expect do
          cli.extract(fixture_file, output_dir)
        end.to output(/file\(s\)/).to_stdout
      end
    end

    context "with output option" do
      it "uses output directory from option" do
        Dir.mktmpdir do |output_dir|
          expect do
            cli.invoke(:extract, [fixture_file], output: output_dir)
          end.to output(/file\(s\)/).to_stdout
        end
      end
    end

    context "with verbose flag" do
      it "enables verbose output" do
        Dir.mktmpdir do |output_dir|
          expect(Cabriolet).to receive(:verbose=).with(true)
          cli.invoke(:extract, [fixture_file, output_dir], verbose: true)
        end
      end
    end

    context "with salvage flag" do
      it "enables salvage mode" do
        Dir.mktmpdir do |output_dir|
          cli.invoke(:extract, [fixture_file, output_dir], salvage: true)
          # Test passes if no error is raised
        end
      end
    end

    context "with invalid file" do
      it "aborts with error message" do
        expect do
          cli.extract("/nonexistent.cab")
        end.to raise_error(Cabriolet::Error)
      end
    end
  end

  describe "#info" do
    let(:cli) { described_class.new }

    it "displays cabinet information" do
      expect do
        cli.info(fixture_file)
      end.to output(/Cabinet Information/).to_stdout
    end

    it "displays filename" do
      expect do
        cli.info(fixture_file)
      end.to output(/Filename:/).to_stdout
    end

    it "displays set ID and index" do
      expect do
        cli.info(fixture_file)
      end.to output(/Set ID:.*Set Index:/m).to_stdout
    end

    it "displays size" do
      expect do
        cli.info(fixture_file)
      end.to output(/Size:.*bytes/).to_stdout
    end

    it "displays folder information" do
      expect do
        cli.info(fixture_file)
      end.to output(/Folders:/).to_stdout
    end

    it "displays compression type for folders" do
      expect do
        cli.info(fixture_file)
      end.to output(/blocks/).to_stdout
    end

    it "displays file information" do
      expect do
        cli.info(fixture_file)
      end.to output(/Files:/).to_stdout
    end

    it "displays file attributes" do
      expect do
        cli.info(fixture_file)
      end.to output(/Attributes:/).to_stdout
    end

    context "with verbose flag" do
      it "enables verbose output" do
        expect(Cabriolet).to receive(:verbose=).with(true)
        cli.invoke(:info, [fixture_file], verbose: true)
      end
    end

    context "with invalid file" do
      it "aborts with error message" do
        expect do
          cli.info("/nonexistent.cab")
        end.to raise_error(Cabriolet::Error)
      end
    end
  end

  describe "#test" do
    let(:cli) { described_class.new }

    it "tests cabinet integrity" do
      expect do
        cli.test(fixture_file)
      end.to output(/Testing/).to_stdout
    end

    it "reports success for valid cabinet" do
      expect do
        cli.test(fixture_file)
      end.to output(/OK:/).to_stdout
    end

    it "displays file count" do
      expect do
        cli.test(fixture_file)
      end.to output(/files passed/).to_stdout
    end

    context "with verbose flag" do
      it "enables verbose output" do
        expect(Cabriolet).to receive(:verbose=).with(true)
        cli.invoke(:test, [fixture_file], verbose: true)
      end
    end

    context "with invalid file" do
      it "aborts with error message" do
        expect do
          cli.test("/nonexistent.cab")
        end.to raise_error(Cabriolet::Error)
      end
    end
  end

  describe "#version" do
    let(:cli) { described_class.new }

    it "displays version information" do
      expect do
        cli.version
      end.to output(/Cabriolet version/).to_stdout
    end

    it "displays the actual version number" do
      expect do
        cli.version
      end.to output(/#{Cabriolet::VERSION}/o).to_stdout
    end
  end

  describe "private methods" do
    let(:cli) { described_class.new }

    describe "#setup_verbose" do
      it "sets Cabriolet.verbose to true when verbose is true" do
        expect(Cabriolet).to receive(:verbose=).with(true)
        cli.send(:setup_verbose, true)
      end

      it "sets Cabriolet.verbose to false when verbose is false" do
        expect(Cabriolet).to receive(:verbose=).with(false)
        cli.send(:setup_verbose, false)
      end

      it "sets Cabriolet.verbose to nil when verbose is nil" do
        expect(Cabriolet).to receive(:verbose=).with(nil)
        cli.send(:setup_verbose, nil)
      end
    end
  end

  describe "error handling" do
    let(:cli) { described_class.new }

    it "handles ParseError gracefully" do
      bad_file = File.join(__dir__, "fixtures/libmspack/cabd/bad_signature.cab")
      expect do
        cli.list(bad_file)
      end.to raise_error(Cabriolet::ParseError)
    end

    it "handles IOError gracefully" do
      expect do
        cli.list("/nonexistent/path/file.cab")
      end.to raise_error(Cabriolet::Error, /Cannot detect format/)
    end
  end

  # Tests for legacy command compatibility
  describe "#chm_list" do
    let(:cli) { described_class.new }
    let(:chm_fixture) do
      File.join(__dir__, "fixtures/chm/imlib2_doc_v1x1x1_r1x0_20171019.chm")
    end

    it "lists CHM contents" do
      skip "CHM fixture not available" unless File.exist?(chm_fixture)
      expect { cli.chm_list(chm_fixture) }.to output(/File|Directory/).to_stdout
    end

    it "uses format override" do
      skip "CHM fixture not available" unless File.exist?(chm_fixture)
      expect { cli.chm_list(chm_fixture) }.not_to raise_error
    end
  end

  describe "#expand" do
    let(:cli) { described_class.new }
    let(:szdd_fixture) { File.join(__dir__, "fixtures/MUANGL20/MAUNINST.EX_") }

    it "expands SZDD file" do
      skip "SZDD fixture not available" unless File.exist?(szdd_fixture)
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          expect do
            cli.expand(szdd_fixture)
          end.to output(/Expanded|Decompressed/).to_stdout
        end
      end
    end
  end

  # Tests for global --format option
  describe "format override" do
    let(:cli) { described_class.new }

    it "respects global format option" do
      # Test that the global --format option works by listing a CAB file
      expect do
        cli.invoke(:list, [fixture_file], { format: "cab" })
      end.not_to raise_error
    end
  end
end
