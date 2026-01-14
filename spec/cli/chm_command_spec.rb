# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require_relative "../support/fixtures"

RSpec.describe Cabriolet::CLI, "CHM commands" do
  let(:cli) { described_class.new }
  let(:basic_fixture) { Fixtures.for(:chm).path(:encints_64bit_both) }

  # Helper method to invoke Thor commands with options
  def invoke_command(command, *args, options: {})
    cli.options = Thor::CoreExt::HashWithIndifferentAccess.new(options)
    # Use send to call run_dispatcher directly, bypassing Thor's invoke mechanism
    # which doesn't properly pass options through to command methods
    # Special handling for create command which has pre-processing logic
    if command == :chm_create
      output = args.first
      files = args[1..]
      # For create command, we need to call the Thor method directly
      # because it has special pre-processing logic (normalize_create_options, detect_format_from_output)
      cli.send(:chm_create, output, *files)
    else
      first_arg = args.first
      remaining_args = args[1..] || []
      cli.send(:run_dispatcher, command, first_arg, *remaining_args, **options)
    end
  end

  describe "#chm_list" do
    it "lists contents of CHM file" do
      expect { cli.chm_list(basic_fixture) }.not_to raise_error
    end

    context "with non-existent file" do
      it "raises ArgumentError" do
        expect do
          cli.chm_list("/nonexistent/file.chm")
        end.to raise_error(ArgumentError)
      end
    end
  end

  describe "#chm_extract" do
    it "opens CHM file successfully" do
      Dir.mktmpdir do |_output_dir|
        # Just verify it can open the file without errors
        decompressor = Cabriolet::CHM::Decompressor.new
        chm = decompressor.open(basic_fixture)
        expect(chm.all_files.length).to be > 0
        decompressor.close
      end
    end

    context "with non-existent file" do
      it "raises ArgumentError" do
        expect do
          cli.chm_extract("/nonexistent/file.chm")
        end.to raise_error(ArgumentError)
      end
    end
  end

  describe "#chm_info" do
    it "displays CHM file information" do
      expect { cli.chm_info(basic_fixture) }.not_to raise_error
    end

    context "with non-existent file" do
      it "raises ArgumentError" do
        expect do
          cli.chm_info("/nonexistent/file.chm")
        end.to raise_error(ArgumentError)
      end
    end

    context "with multiple fixture files" do
      it "displays info for all basic fixtures" do
        basic_fixtures = Fixtures.for(:chm).scenario(:basic)

        basic_fixtures.each do |fixture|
          expect { cli.chm_info(fixture) }.not_to raise_error
        end
      end
    end
  end

  describe "#chm_create" do
    it "creates CHM file from source files" do
      Dir.mktmpdir do |tmp_dir|
        output_chm = File.join(tmp_dir, "test.chm")
        test_file = File.join(tmp_dir, "test.html")
        File.write(test_file, "<html><body>Test</body></html>")

        invoke_command(:chm_create, output_chm, test_file)

        expect(File.exist?(output_chm)).to be(true)
        expect(File.size(output_chm)).to be > 0
      end
    end

    it "creates CHM that can be parsed back" do
      Dir.mktmpdir do |tmp_dir|
        output_chm = File.join(tmp_dir, "test.chm")
        test_file = File.join(tmp_dir, "test.html")
        File.write(test_file, "<html><body>Test</body></html>")

        invoke_command(:chm_create, output_chm, test_file)

        # Verify created CHM can be parsed
        decompressor = Cabriolet::CHM::Decompressor.new
        chm = decompressor.open(output_chm)
        expect(chm).to be_a(Cabriolet::Models::CHMHeader)
        decompressor.close
      end
    end

    context "with no input files" do
      it "raises ArgumentError" do
        Dir.mktmpdir do |tmp_dir|
          output_chm = File.join(tmp_dir, "test.chm")

          expect { invoke_command(:chm_create, output_chm) }
            .to raise_error(ArgumentError)
        end
      end
    end

    context "with non-existent input file" do
      it "raises ArgumentError" do
        Dir.mktmpdir do |tmp_dir|
          output_chm = File.join(tmp_dir, "test.chm")

          expect do
            invoke_command(:chm_create, output_chm, "/nonexistent/file.html")
          end
            .to raise_error(ArgumentError)
        end
      end
    end
  end

  describe "command edge cases" do
    context "when using CVE fixtures" do
      it "handles CVE test files" do
        cve_fixture = Fixtures.for(:chm).edge_case(:cve_2015_4468)

        expect { cli.chm_info(cve_fixture) }.not_to raise_error
        expect { cli.chm_list(cve_fixture) }.not_to raise_error
      end
    end
  end
end
