# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require_relative "../support/fixtures"

RSpec.describe Cabriolet::CLI, "KWAJ commands" do
  let(:cli) { described_class.new }
  let(:basic_fixture) { Fixtures.for(:kwaj).path(:f00) }

  # Helper method to invoke Thor commands with options
  def invoke_command(command, *args, options: {})
    # For Thor commands with options, set options before calling the command
    original_options = cli.options.dup
    cli.options = Thor::CoreExt::HashWithIndifferentAccess.new(options)

    # Call the command directly with args
    cli.public_send(command, *args)

    cli.options = original_options
  end

  describe "#kwaj_info" do
    it "displays KWAJ file information" do
      expect { cli.kwaj_info(basic_fixture) }.not_to raise_error
    end

    context "with non-existent file" do
      it "exits with error" do
        expect { cli.kwaj_info("/nonexistent/file.kwj") }.to raise_error(SystemExit)
      end
    end

    context "with multiple fixture files" do
      it "displays info for all basic fixtures" do
        basic_fixtures = Fixtures.for(:kwaj).scenario(:basic)

        basic_fixtures.each do |fixture|
          expect { cli.kwaj_info(fixture) }.not_to raise_error
        end
      end
    end
  end

  describe "#kwaj_extract" do
    it "extracts KWAJ file successfully" do
      Dir.mktmpdir do |output_dir|
        output_file = File.join(output_dir, "output.bin")
        expect { cli.kwaj_extract(basic_fixture, output_file) }.not_to raise_error
        expect(File.exist?(output_file)).to be(true)
      end
    end

    context "with auto output filename" do
      it "extracts with default output name" do
        Dir.mktmpdir do |output_dir|
          # Copy fixture to temp directory for auto-naming test
          temp_fixture = File.join(output_dir, "test.kwj")
          FileUtils.cp(basic_fixture, temp_fixture)

          # Change to temp directory to test default naming
          original_dir = Dir.pwd
          begin
            Dir.chdir(output_dir)
            expect { cli.kwaj_extract(temp_fixture) }.not_to raise_error
            # Should create output file based on input filename
            expect(Dir["*"].length).to be > 0
          ensure
            Dir.chdir(original_dir)
          end
        end
      end
    end

    context "with non-existent file" do
      it "exits with error" do
        expect { cli.kwaj_extract("/nonexistent/file.kwj") }.to raise_error(SystemExit)
      end
    end

    context "with multiple KWAJ fixtures" do
      it "extracts all basic fixtures successfully" do
        basic_fixtures = Fixtures.for(:kwaj).scenario(:basic)

        Dir.mktmpdir do |output_dir|
          basic_fixtures.each_with_index do |fixture, i|
            output_file = File.join(output_dir, "output_#{i}.bin")
            expect { cli.kwaj_extract(fixture, output_file) }.not_to raise_error
            expect(File.exist?(output_file)).to be(true)
          end
        end
      end
    end
  end

  describe "#kwaj_compress" do
    it "compresses file to KWAJ format" do
      Dir.mktmpdir do |tmp_dir|
        test_file = File.join(tmp_dir, "test.txt")
        output_kwj = File.join(tmp_dir, "test.kwj")
        File.write(test_file, "Test data for KWAJ compression")

        invoke_command(:kwaj_compress, test_file, output_kwj)

        expect(File.exist?(output_kwj)).to be(true)
        expect(File.size(output_kwj)).to be > 0
      end
    end

    it "creates KWAJ that can be decompressed back" do
      Dir.mktmpdir do |tmp_dir|
        test_file = File.join(tmp_dir, "test.txt")
        output_kwj = File.join(tmp_dir, "test.kwj")
        decompressed = File.join(tmp_dir, "test.out")
        original_data = "Round-trip KWAJ test data!"
        File.write(test_file, original_data)

        invoke_command(:kwaj_compress, test_file, output_kwj)

        # Verify created KWAJ can be decompressed
        cli.kwaj_extract(output_kwj, decompressed)
        expect(File.read(decompressed)).to eq(original_data)
      end
    end

    it "compresses with SZDD compression option" do
      Dir.mktmpdir do |tmp_dir|
        test_file = File.join(tmp_dir, "test.txt")
        output_kwj = File.join(tmp_dir, "test.kwj")
        File.write(test_file, "Test data " * 20)

        invoke_command(:kwaj_compress, test_file, output_kwj, options: { compression: "szdd" })

        expect(File.exist?(output_kwj)).to be(true)
      end
    end

    context "with non-existent input file" do
      it "raises ArgumentError" do
        Dir.mktmpdir do |tmp_dir|
          output_kwj = File.join(tmp_dir, "test.kwj")

          expect { invoke_command(:kwaj_compress, "/nonexistent/file.txt", output_kwj) }
            .to raise_error(SystemExit)
        end
      end
    end
  end

  describe "round-trip compatibility" do
    it "compresses and decompresses correctly" do
      Dir.mktmpdir do |tmp_dir|
        input_file = File.join(tmp_dir, "original.txt")
        compressed = File.join(tmp_dir, "compressed.kwj")
        decompressed = File.join(tmp_dir, "decompressed.txt")

        original_data = "KWAJ round-trip test with various data: #{'A' * 100}"
        File.write(input_file, original_data)

        # Compress
        invoke_command(:kwaj_compress, input_file, compressed)

        # Decompress
        cli.kwaj_extract(compressed, decompressed)

        # Verify
        result = File.read(decompressed)
        expect(result).to eq(original_data)
      end
    end

    it "handles binary data correctly" do
      Dir.mktmpdir do |tmp_dir|
        input_file = File.join(tmp_dir, "binary.dat")
        compressed = File.join(tmp_dir, "compressed.kwj")
        decompressed = File.join(tmp_dir, "decompressed.dat")

        binary_data = (0..255).to_a.pack("C*") * 5
        File.binwrite(input_file, binary_data)

        # Compress with XOR
        invoke_command(:kwaj_compress, input_file, compressed, options: { compression: "xor" })

        # Decompress
        cli.kwaj_extract(compressed, decompressed)

        # Verify
        result = File.binread(decompressed)
        expect(result).to eq(binary_data)
      end
    end
  end

  describe "command edge cases" do
    context "when using CVE fixtures" do
      it "handles CVE test file gracefully" do
        cve_fixture = Fixtures.for(:kwaj).edge_case(:cve_2018_14681)

        # CVE file has malformed headers, CLI should exit with error
        expect { cli.kwaj_info(cve_fixture) }.to raise_error(SystemExit)
      end
    end
  end
end
