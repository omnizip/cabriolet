# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require_relative "../support/fixtures"

RSpec.describe Cabriolet::CLI, "SZDD commands" do
  let(:cli) { described_class.new }
  let(:basic_fixture) { Fixtures.for(:szdd).path(:muan_inst) }

  # Helper method to invoke Thor commands with options
  def invoke_command(command, *args, options: {})
    cli.options = Thor::CoreExt::HashWithIndifferentAccess.new(options)
    # For legacy commands and create command, call Thor methods directly
    # because they have special pre-processing logic
    # For unified commands, use run_dispatcher with options
    if command.to_s.start_with?("szdd_") || command == :compress
      # Call legacy Thor methods directly
      cli.send(command, *args)
    else
      first_arg = args.first
      remaining_args = args[1..] || []
      cli.send(:run_dispatcher, command, first_arg, *remaining_args, **options)
    end
  end

  describe "#szdd_info" do
    context "with non-existent file" do
      it "raises ArgumentError" do
        expect do
          cli.szdd_info("/nonexistent/file.ex_")
        end.to raise_error(ArgumentError)
      end
    end

    context "with real SZDD fixtures" do
      it "displays info for all SZDD fixtures" do
        basic_fixtures = Fixtures.for(:szdd).scenario(:all)

        basic_fixtures.each do |fixture|
          skip "Fixture not found: #{fixture}" unless File.exist?(fixture)
          expect { cli.szdd_info(fixture) }.not_to raise_error
        end
      end
    end
  end

  describe "#expand" do
    context "with non-existent file" do
      it "raises ArgumentError" do
        expect do
          cli.expand("/nonexistent/file.ex_")
        end.to raise_error(ArgumentError)
      end
    end

    context "with generated SZDD file" do
      it "expands generated SZDD file" do
        Dir.mktmpdir do |tmp_dir|
          # Create a simple test file
          input_file = File.join(tmp_dir, "test.txt")
          compressed = File.join(tmp_dir, "test.tx_")
          expanded = File.join(tmp_dir, "expanded.txt")

          original_data = "SZDD expansion test data! " * 10
          File.write(input_file, original_data)

          # Compress first
          cli.compress(input_file, compressed)

          # Now expand with explicit output
          cli.expand(compressed, expanded)

          # Verify data matches
          expanded_data = File.read(expanded)
          expect(expanded_data).to eq(original_data)
        end
      end
    end
  end

  describe "#compress" do
    it "compresses file to SZDD format" do
      Dir.mktmpdir do |tmp_dir|
        input_file = File.join(tmp_dir, "test.txt")
        output_szdd = File.join(tmp_dir, "test.tx_")
        File.write(input_file, "Test content for SZDD")

        cli.compress(input_file, output_szdd)

        expect(File.exist?(output_szdd)).to be(true)
        expect(File.size(output_szdd)).to be > 0
      end
    end

    it "creates SZDD that can be read back by info command" do
      Dir.mktmpdir do |tmp_dir|
        input_file = File.join(tmp_dir, "test.txt")
        output_szdd = File.join(tmp_dir, "test.tx_")
        File.write(input_file, "Test content")

        cli.compress(input_file, output_szdd)

        # Verify created SZDD can be read by info command
        expect { cli.szdd_info(output_szdd) }.not_to raise_error
      end
    end

    it "generates correct output filename when not specified" do
      Dir.mktmpdir do |tmp_dir|
        # Test with .txt extension (should become .tx_)
        input_file = File.join(tmp_dir, "test.txt")
        File.write(input_file, "Test content")

        # Change to temp directory
        original_dir = Dir.pwd
        begin
          Dir.chdir(tmp_dir)
          cli.compress(input_file)

          # Should create test.tx_
          expect(File.exist?("test.tx_")).to be(true)
        ensure
          Dir.chdir(original_dir)
        end
      end
    end

    it "supports custom missing character" do
      Dir.mktmpdir do |tmp_dir|
        input_file = File.join(tmp_dir, "test.txt")
        output_szdd = File.join(tmp_dir, "test.tx_")
        File.write(input_file, "Test content with special char: X")

        # Use invoke_command to pass missing_char option
        invoke_command(:compress, input_file, output_szdd,
                       options: { missing_char: "X" })

        expect(File.exist?(output_szdd)).to be(true)
        expect(File.size(output_szdd)).to be > 0

        # Verify the file can be read back
        expect { cli.szdd_info(output_szdd) }.not_to raise_error
      end
    end

    it "supports QBASIC format" do
      Dir.mktmpdir do |tmp_dir|
        input_file = File.join(tmp_dir, "test.bas")
        output_szdd = File.join(tmp_dir, "test.ba_")
        File.write(input_file, "10 PRINT \"QBASIC test\"")

        # Use invoke_command to pass format option
        invoke_command(:compress, input_file, output_szdd,
                       options: { format: "qbasic" })

        expect(File.exist?(output_szdd)).to be(true)
        expect(File.size(output_szdd)).to be > 0

        # Verify the file can be read back
        expect { cli.szdd_info(output_szdd) }.not_to raise_error
      end
    end
  end

  describe "round-trip compatibility" do
    it "creates SZDD that can be expanded" do
      Dir.mktmpdir do |tmp_dir|
        input_file = File.join(tmp_dir, "original.txt")
        compressed = File.join(tmp_dir, "original.tx_")
        expanded = File.join(tmp_dir, "expanded.txt")

        original_data = "SZDD round-trip test data!"
        File.write(input_file, original_data)

        # Compress
        cli.compress(input_file, compressed)

        # Expand
        cli.expand(compressed, expanded)

        # Verify data matches
        expanded_data = File.read(expanded)
        expect(expanded_data).to eq(original_data)
      end
    end
  end

  describe "command edge cases" do
    context "with large files" do
      it "handles larger content files" do
        Dir.mktmpdir do |tmp_dir|
          input_file = File.join(tmp_dir, "large.txt")
          output_szdd = File.join(tmp_dir, "large.tx_")
          File.write(input_file, "Large test data " * 1000)

          cli.compress(input_file, output_szdd)

          expect(File.exist?(output_szdd)).to be(true)
          expect(File.size(output_szdd)).to be > 0
        end
      end
    end

    context "with small files" do
      it "handles small content files" do
        Dir.mktmpdir do |tmp_dir|
          input_file = File.join(tmp_dir, "small.txt")
          output_szdd = File.join(tmp_dir, "small.tx_")
          File.write(input_file, "X" * 10)

          cli.compress(input_file, output_szdd)

          expect(File.exist?(output_szdd)).to be(true)
          expect(File.size(output_szdd)).to be > 0
        end
      end
    end

    context "with empty files" do
      it "handles empty content files" do
        Dir.mktmpdir do |tmp_dir|
          input_file = File.join(tmp_dir, "empty.txt")
          output_szdd = File.join(tmp_dir, "empty.tx_")
          File.write(input_file, "")

          cli.compress(input_file, output_szdd)

          expect(File.exist?(output_szdd)).to be(true)
          # Header should still be written
          expect(File.size(output_szdd)).to be > 0
        end
      end
    end
  end
end
