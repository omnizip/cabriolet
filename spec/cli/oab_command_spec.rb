# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require_relative "../support/fixtures"

RSpec.describe Cabriolet::CLI, "OAB commands" do
  let(:cli) { described_class.new }

  # Helper method to invoke Thor commands with options
  def invoke_command(command, *args, options: {})
    # Use Thor's invoke method which properly handles options
    # The options hash is passed as a parameter, not by modifying the frozen options
    cli.invoke(command, args, options)
  end

  describe "#oab_info" do
    context "with generated OAB file" do
      it "displays OAB file information" do
        Dir.mktmpdir do |tmp_dir|
          input_file = File.join(tmp_dir, "test.dat")
          output_oab = File.join(tmp_dir, "test.oab")
          File.write(input_file, "Test content for OAB info")

          # Create OAB file first
          invoke_command(:oab_create, input_file, output_oab)

          # Now show info - verify it doesn't raise error
          expect { cli.oab_info(output_oab) }.not_to raise_error
        end
      end
    end

    context "with non-existent file" do
      it "raises ArgumentError" do
        expect do
          cli.oab_info("/nonexistent/file.oab")
        end.to raise_error(ArgumentError)
      end
    end
  end

  describe "#oab_extract" do
    context "with non-existent file" do
      it "raises ArgumentError" do
        expect { cli.oab_extract("/nonexistent/file.oab", "output.dat") }
          .to raise_error(ArgumentError)
      end
    end

    context "with generated OAB file" do
      it "extracts generated OAB file" do
        Dir.mktmpdir do |tmp_dir|
          input_file = File.join(tmp_dir, "test.dat")
          output_oab = File.join(tmp_dir, "test.oab")
          extracted = File.join(tmp_dir, "extracted.dat")

          original_data = "OAB CLI extraction test data!"
          File.write(input_file, original_data)

          # Create OAB
          invoke_command(:oab_create, input_file, output_oab)

          # Extract
          expect { cli.oab_extract(output_oab, extracted) }.not_to raise_error
          expect(File.exist?(extracted)).to be(true)

          # Verify data matches
          extracted_data = File.read(extracted)
          expect(extracted_data).to eq(original_data)
        end
      end
    end
  end

  describe "#oab_create" do
    it "creates OAB file from source file" do
      Dir.mktmpdir do |tmp_dir|
        output_oab = File.join(tmp_dir, "test.oab")
        test_file = File.join(tmp_dir, "test.dat")
        File.write(test_file, "Test content for OAB")

        invoke_command(:oab_create, test_file, output_oab)

        expect(File.exist?(output_oab)).to be(true)
        expect(File.size(output_oab)).to be > 0
      end
    end

    it "creates OAB that can be read back" do
      Dir.mktmpdir do |tmp_dir|
        output_oab = File.join(tmp_dir, "test.oab")
        test_file = File.join(tmp_dir, "test.dat")
        File.write(test_file, "Test content")

        invoke_command(:oab_create, test_file, output_oab)

        # Verify created OAB can be read by info command
        expect { cli.oab_info(output_oab) }.not_to raise_error
      end
    end

    it "supports custom block size" do
      Dir.mktmpdir do |tmp_dir|
        output_oab = File.join(tmp_dir, "test.oab")
        test_file = File.join(tmp_dir, "test.dat")
        File.write(test_file, "Test content")

        invoke_command(:oab_create, test_file, output_oab,
                       options: { block_size: 16384 })

        expect(File.exist?(output_oab)).to be(true)
        expect(File.size(output_oab)).to be > 0
      end
    end

    context "with no input file" do
      it "raises error for non-existent input" do
        Dir.mktmpdir do |tmp_dir|
          output_oab = File.join(tmp_dir, "test.oab")

          expect do
            invoke_command(:oab_create, "/nonexistent/file.dat", output_oab)
          end
            .to raise_error(ArgumentError)
        end
      end
    end
  end

  describe "round-trip compatibility" do
    it "creates OAB that can be extracted" do
      Dir.mktmpdir do |tmp_dir|
        input_file = File.join(tmp_dir, "original.dat")
        compressed = File.join(tmp_dir, "test.oab")
        extracted = File.join(tmp_dir, "extracted.dat")

        original_data = "OAB CLI round-trip test data!"
        File.write(input_file, original_data)

        # Create OAB
        invoke_command(:oab_create, input_file, compressed)

        # Extract
        cli.oab_extract(compressed, extracted)

        # Verify data matches
        extracted_data = File.read(extracted)
        expect(extracted_data).to eq(original_data)
      end
    end
  end

  describe "incremental patch support" do
    it "creates incremental patch" do
      Dir.mktmpdir do |tmp_dir|
        base_file = File.join(tmp_dir, "base.dat")
        new_file = File.join(tmp_dir, "new.dat")
        output_oab = File.join(tmp_dir, "patch.oab")

        File.write(base_file, "Original data")
        File.write(new_file, "New data - different from base")

        invoke_command(:oab_create, new_file, output_oab,
                       options: { base: base_file })

        expect(File.exist?(output_oab)).to be(true)
        expect(File.size(output_oab)).to be > 0
      end
    end

    it "applies incremental patch" do
      Dir.mktmpdir do |tmp_dir|
        base_file = File.join(tmp_dir, "base.dat")
        new_file = File.join(tmp_dir, "new.dat")
        patch_oab = File.join(tmp_dir, "patch.oab")
        extracted = File.join(tmp_dir, "result.dat")

        original_data = "Base file content"
        new_data = "Modified content"
        File.write(base_file, original_data)
        File.write(new_file, new_data)

        # Create patch
        invoke_command(:oab_create, new_file, patch_oab,
                       options: { base: base_file })

        # Apply patch
        invoke_command(:oab_extract, patch_oab, extracted,
                       options: { base: base_file })

        expect(File.exist?(extracted)).to be(true)
        expect(File.read(extracted)).to eq(new_data)
      end
    end
  end

  describe "command edge cases" do
    context "with large files" do
      it "handles larger content files" do
        Dir.mktmpdir do |tmp_dir|
          output_oab = File.join(tmp_dir, "test.oab")
          test_file = File.join(tmp_dir, "large.dat")
          File.write(test_file, "Large test data " * 1000)

          invoke_command(:oab_create, test_file, output_oab)

          expect(File.exist?(output_oab)).to be(true)
          expect(File.size(output_oab)).to be > 0
        end
      end
    end

    context "with small files" do
      it "handles small content files" do
        Dir.mktmpdir do |tmp_dir|
          output_oab = File.join(tmp_dir, "test.oab")
          test_file = File.join(tmp_dir, "small.dat")
          File.write(test_file, "Small")

          invoke_command(:oab_create, test_file, output_oab)

          expect(File.exist?(output_oab)).to be(true)
          expect(File.size(output_oab)).to be > 0
        end
      end
    end

    context "with empty files" do
      it "handles empty content files" do
        Dir.mktmpdir do |tmp_dir|
          output_oab = File.join(tmp_dir, "test.oab")
          test_file = File.join(tmp_dir, "empty.dat")
          File.write(test_file, "")

          invoke_command(:oab_create, test_file, output_oab)

          expect(File.exist?(output_oab)).to be(true)
          # Header should still be written
          expect(File.size(output_oab)).to be > 0
        end
      end
    end
  end
end
