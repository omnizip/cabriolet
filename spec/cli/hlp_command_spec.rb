# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require_relative "../support/fixtures"

RSpec.describe Cabriolet::CLI, "HLP commands" do
  let(:cli) { described_class.new }
  let(:basic_fixture) { Fixtures.for(:hlp).path(:se) }

  # Helper method to invoke Thor commands with options
  def invoke_command(command, *args, options: {})
    cli.options = Thor::CoreExt::HashWithIndifferentAccess.new(options)
    # For legacy commands and create command, call Thor methods directly
    # because they have special pre-processing logic
    # For unified commands, use run_dispatcher with options
    legacy_commands = [:hlp_create]
    if legacy_commands.include?(command) || command.to_s.start_with?("hlp_")
      # Call legacy Thor methods directly
      method_name = command.to_s.sub(/^hlp_/, "")
      cli.send("hlp_#{method_name}", *args)
    else
      first_arg = args.first
      remaining_args = args[1..] || []
      cli.send(:run_dispatcher, command, first_arg, *remaining_args, **options)
    end
  end

  describe "#hlp_extract" do
    it "extracts HLP file successfully" do
      Dir.mktmpdir do |output_dir|
        expect { invoke_command(:hlp_extract, basic_fixture, output_dir) }
          .not_to raise_error
      end
    end

    context "with non-existent file" do
      it "raises ArgumentError" do
        expect { invoke_command(:hlp_extract, "/nonexistent/file.hlp") }
          .to raise_error(ArgumentError)
      end
    end
  end

  describe "#hlp_info" do
    it "displays HLP file information" do
      expect { invoke_command(:hlp_info, basic_fixture) }.not_to raise_error
    end

    context "with non-existent file" do
      it "raises ArgumentError" do
        expect { invoke_command(:hlp_info, "/nonexistent/file.hlp") }
          .to raise_error(ArgumentError)
      end
    end

    context "with multiple WinHelp fixture files" do
      it "displays info for all WinHelp fixtures" do
        winhelp_fixtures = Fixtures.for(:hlp).scenario(:winhelp)

        winhelp_fixtures.each do |fixture|
          expect { invoke_command(:hlp_info, fixture) }.not_to raise_error
        end
      end
    end
  end

  describe "#hlp_create" do
    it "creates HLP file from source files" do
      Dir.mktmpdir do |tmp_dir|
        output_hlp = File.join(tmp_dir, "test.hlp")
        test_file = File.join(tmp_dir, "test.txt")
        File.write(test_file, "Test content")

        invoke_command(:hlp_create, output_hlp, test_file)

        expect(File.exist?(output_hlp)).to be(true)
        expect(File.size(output_hlp)).to be > 0
      end
    end

    it "creates HLP that can be parsed back" do
      Dir.mktmpdir do |tmp_dir|
        output_hlp = File.join(tmp_dir, "test.hlp")
        test_file = File.join(tmp_dir, "test.txt")
        File.write(test_file, "Round-trip content")

        invoke_command(:hlp_create, output_hlp, test_file)

        # Verify created HLP can be parsed
        decompressor = Cabriolet::HLP::Decompressor.new
        header = decompressor.open(output_hlp)
        expect(header).to be_a(Cabriolet::Models::HLPHeader)
        expect(header.topics).not_to be_empty
        decompressor.close(header)
      end
    end

    it "creates HLP with multiple files" do
      Dir.mktmpdir do |tmp_dir|
        output_hlp = File.join(tmp_dir, "multi.hlp")
        test_file1 = File.join(tmp_dir, "file1.txt")
        test_file2 = File.join(tmp_dir, "file2.txt")
        File.write(test_file1, "Content 1")
        File.write(test_file2, "Content 2")

        invoke_command(:hlp_create, output_hlp, test_file1, test_file2)

        expect(File.exist?(output_hlp)).to be(true)

        # Verify both files are in the archive
        decompressor = Cabriolet::HLP::Decompressor.new
        header = decompressor.open(output_hlp)
        expect(header.topics.size).to eq(2)
        decompressor.close(header)
      end
    end

    context "with no input files" do
      it "raises ArgumentError" do
        Dir.mktmpdir do |tmp_dir|
          output_hlp = File.join(tmp_dir, "test.hlp")

          expect { invoke_command(:hlp_create, output_hlp) }
            .to raise_error(ArgumentError)
        end
      end
    end

    context "with non-existent input file" do
      it "raises ArgumentError" do
        Dir.mktmpdir do |tmp_dir|
          output_hlp = File.join(tmp_dir, "test.hlp")

          expect do
            invoke_command(:hlp_create, output_hlp, "/nonexistent/file.txt")
          end
            .to raise_error(ArgumentError)
        end
      end
    end
  end

  describe "command edge cases" do
    context "when extracting to current directory" do
      it "uses default output directory" do
        Dir.mktmpdir do |tmp_dir|
          Dir.chdir(tmp_dir) do
            expect { invoke_command(:hlp_extract, basic_fixture) }
              .not_to raise_error
          end
        end
      end
    end

    context "with verbose option" do
      it "runs commands with verbose output" do
        expect do
          invoke_command(:hlp_info, basic_fixture, options: { verbose: true })
        end
          .not_to raise_error
      end
    end
  end
end
