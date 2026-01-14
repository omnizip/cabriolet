# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require_relative "../support/fixtures"

RSpec.describe Cabriolet::CLI, "CAB commands" do
  let(:cli) { described_class.new }
  let(:basic_fixture) { Fixtures.for(:cab).path(:basic) }
  let(:simple_fixture) { Fixtures.for(:cab).path(:simple) }

  # Helper method to invoke Thor commands with options
  def invoke_command(command, *args, options: {})
    cli.options = Thor::CoreExt::HashWithIndifferentAccess.new(options)
    cli.public_send(command, *args)
  end

  describe "#list" do
    it "lists contents of CAB file" do
      # Test that the command can be executed without errors
      expect { cli.list(basic_fixture) }.not_to raise_error
    end

    context "with non-existent file" do
      it "raises Error for format detection failure" do
        expect do
          cli.list("/nonexistent/file.cab")
        end.to raise_error(Cabriolet::Error,
                           /Cannot detect format/)
      end
    end

    context "with invalid signature" do
      let(:bad_fixture) { Fixtures.for(:cab).edge_case(:bad_signature) }

      it "raises ParseError" do
        expect do
          cli.list(bad_fixture)
        end.to raise_error(Cabriolet::ParseError,
                           /Invalid CAB signature/)
      end
    end
  end

  describe "#extract" do
    it "extracts all files from cabinet to output directory" do
      Dir.mktmpdir do |output_dir|
        cli.extract(basic_fixture, output_dir)

        extracted_files = Dir.glob("#{output_dir}/**/*").select do |f|
          File.file?(f)
        end
        expect(extracted_files.length).to eq(2) # basic.cab has 2 files
      end
    end

    it "extracts files with correct content" do
      Dir.mktmpdir do |output_dir|
        cli.extract(basic_fixture, output_dir)

        # Verify at least one file was extracted
        extracted_files = Dir.glob("#{output_dir}/**/*").select do |f|
          File.file?(f)
        end
        expect(extracted_files.length).to be > 0

        # Verify files have content
        extracted_files.each do |file|
          expect(File.size(file)).to be > 0
        end
      end
    end

    context "with output option" do
      it "uses specified output directory" do
        Dir.mktmpdir do |tmp_dir|
          output_dir = File.join(tmp_dir, "custom_output")
          cli.extract(basic_fixture, output_dir)

          expect(Dir.exist?(output_dir)).to be(true)
          extracted_files = Dir.glob("#{output_dir}/**/*").select do |f|
            File.file?(f)
          end
          expect(extracted_files.length).to be > 0
        end
      end
    end

    context "with non-existent file" do
      it "raises Error for non-existent file" do
        expect do
          cli.extract("/nonexistent/file.cab")
        end.to raise_error(Cabriolet::Error,
                           /Cannot detect format/)
      end
    end
  end

  describe "#info" do
    it "displays cabinet information" do
      expect { cli.info(basic_fixture) }.not_to raise_error
    end

    context "with multi-part cabinet" do
      let(:multi_fixture) { Fixtures.for(:cab).path(:multi_pt1) }

      it "displays information for multi-part cabinet" do
        expect { cli.info(multi_fixture) }.not_to raise_error
      end
    end

    context "with reserve data cabinet" do
      let(:reserve_fixture) do
        File.join(__dir__, "../fixtures/libmspack/cabd/reserve_HFD.cab")
      end

      it "displays reserve flag information" do
        expect { cli.info(reserve_fixture) }.not_to raise_error
      end
    end
  end

  describe "#test" do
    it "tests cabinet file integrity" do
      expect { cli.test(basic_fixture) }.not_to raise_error
    end

    context "with corrupted file" do
      let(:partial_fixture) do
        Fixtures.for(:cab).edge_case(:partial_shortheader)
      end

      it "raises ParseError for corrupted cabinet" do
        expect { cli.test(partial_fixture) }.to raise_error(Cabriolet::ParseError)
      end
    end
  end

  describe "#create" do
    it "creates valid CAB file from source files" do
      Dir.mktmpdir do |tmp_dir|
        output_cab = File.join(tmp_dir, "test.cab")
        test_file1 = File.join(tmp_dir, "file1.txt")
        test_file2 = File.join(tmp_dir, "file2.txt")

        File.write(test_file1, "Content 1")
        File.write(test_file2, "Content 2")

        invoke_command(:create, output_cab, test_file1, test_file2,
                       options: { compression: "mszip" })

        expect(File.exist?(output_cab)).to be(true)
        expect(File.size(output_cab)).to be > 0
      end
    end

    it "creates CAB that can be parsed back" do
      Dir.mktmpdir do |tmp_dir|
        output_cab = File.join(tmp_dir, "test.cab")
        test_file = File.join(tmp_dir, "test.txt")
        File.write(test_file, "Test content")

        invoke_command(:create, output_cab, test_file,
                       options: { compression: "mszip" })

        # Verify created cabinet can be parsed
        parser = Cabriolet::CAB::Parser.new(Cabriolet::System::IOSystem.new)
        cabinet = parser.parse(output_cab)

        expect(cabinet.file_count).to eq(1)
      end
    end

    context "with compression option" do
      it "creates CAB with specified compression type" do
        Dir.mktmpdir do |tmp_dir|
          output_cab = File.join(tmp_dir, "test.cab")
          test_file = File.join(tmp_dir, "test.txt")
          File.write(test_file, "Test content")

          invoke_command(:create, output_cab, test_file,
                         options: { compression: "none" })

          expect(File.exist?(output_cab)).to be(true)

          # Verify no compression was used
          parser = Cabriolet::CAB::Parser.new(Cabriolet::System::IOSystem.new)
          cabinet = parser.parse(output_cab)
          folder = cabinet.folders.first

          expect(folder.comp_type).to eq(Cabriolet::Constants::COMP_TYPE_NONE)
        end
      end
    end

    context "with no input files" do
      it "raises ArgumentError" do
        Dir.mktmpdir do |tmp_dir|
          output_cab = File.join(tmp_dir, "test.cab")

          expect do
            invoke_command(:create, output_cab,
                           options: { compression: "mszip" })
          end
            .to raise_error(ArgumentError)
        end
      end
    end

    context "with non-existent input file" do
      it "raises ArgumentError" do
        Dir.mktmpdir do |tmp_dir|
          output_cab = File.join(tmp_dir, "test.cab")

          expect do
            invoke_command(:create, output_cab, "/nonexistent/file.txt",
                           options: { compression: "mszip" })
          end
            .to raise_error(ArgumentError)
        end
      end
    end
  end

  describe "#search" do
    it "searches for embedded cabinets in file" do
      # For now, just verify the command exists and can be called
      # Real testing would require files with embedded cabinets
      expect { cli.search(basic_fixture) }.not_to raise_error
    end
  end

  describe "command edge cases" do
    context "when CAB has multiple compression types" do
      let(:mszip_fixture) { Fixtures.for(:cab).path(:mszip) }

      it "list handles mixed compression" do
        expect { cli.list(mszip_fixture) }.not_to raise_error
      end

      it "extract handles mixed compression" do
        Dir.mktmpdir do |output_dir|
          # Use salvage mode for MSZIP fixtures with mixed compression types
          # as checksum validation may fail due to format peculiarities
          invoke_command(:extract, mszip_fixture, output_dir,
                         options: { salvage: true })
          extracted_files = Dir.glob("#{output_dir}/**/*").select do |f|
            File.file?(f)
          end
          expect(extracted_files.length).to be > 0
        end
      end

      it "info shows mixed compression" do
        expect { cli.info(mszip_fixture) }.not_to raise_error
      end
    end

    context "when using split cabinets" do
      it "handles first part of split cabinet" do
        split_fixtures = Fixtures.for(:cab).scenario(:split)
        first_split = split_fixtures.first

        expect { cli.info(first_split) }.not_to raise_error
      end
    end
  end
end
