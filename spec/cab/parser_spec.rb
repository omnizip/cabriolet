# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::CAB::Parser do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:parser) { described_class.new(io_system) }

  describe "#parse" do
    context "with a valid CAB file" do
      let(:cab_file) do
        File.join(__dir__,
                  "../fixtures/libmspack/cabd/normal_2files_1folder.cab")
      end

      it "parses the cabinet successfully" do
        cabinet = parser.parse(cab_file)

        expect(cabinet).to be_a(Cabriolet::Models::Cabinet)
        expect(cabinet.filename).to eq(cab_file)
      end

      it "reads cabinet metadata correctly" do
        cabinet = parser.parse(cab_file)

        expect(cabinet.length).to be > 0
        expect(cabinet.set_id).not_to be_nil
        expect(cabinet.set_index).not_to be_nil
      end

      it "reads folders correctly" do
        cabinet = parser.parse(cab_file)

        expect(cabinet.folders).not_to be_empty
        expect(cabinet.folder_count).to eq(1)

        folder = cabinet.folders.first
        expect(folder).to be_a(Cabriolet::Models::Folder)
        expect(folder.comp_type).not_to be_nil
        expect(folder.num_blocks).to be > 0
        expect(folder.data_offset).to be >= 0
      end

      it "reads files correctly" do
        cabinet = parser.parse(cab_file)

        expect(cabinet.files).not_to be_empty
        expect(cabinet.file_count).to eq(2)

        cabinet.files.each do |file|
          expect(file).to be_a(Cabriolet::Models::File)
          expect(file.filename).not_to be_nil
          expect(file.length).to be >= 0
          expect(file.folder).not_to be_nil
        end
      end

      it "links files to folders correctly" do
        cabinet = parser.parse(cab_file)

        cabinet.files.each do |file|
          expect(file.folder).to be_a(Cabriolet::Models::Folder)
          expect(cabinet.folders).to include(file.folder)
        end
      end

      it "parses file datetime correctly" do
        cabinet = parser.parse(cab_file)

        cabinet.files.each do |file|
          expect(file.date_y).to be >= 1980
          expect(file.date_m).to be_between(1, 12)
          expect(file.date_d).to be_between(1, 31)
          expect(file.time_h).to be_between(0, 23)
          expect(file.time_m).to be_between(0, 59)
          expect(file.time_s).to be_between(0, 59)
        end
      end
    end

    context "with an invalid signature" do
      let(:bad_sig_file) do
        File.join(__dir__, "../fixtures/libmspack/cabd/bad_signature.cab")
      end

      it "raises ParseError for invalid signature" do
        expect do
          parser.parse(bad_sig_file)
        end.to raise_error(Cabriolet::ParseError,
                           /Invalid CAB signature/)
      end
    end

    context "with no folders" do
      let(:no_folders_file) do
        File.join(__dir__, "../fixtures/libmspack/cabd/bad_nofolders.cab")
      end

      it "raises ParseError" do
        expect do
          parser.parse(no_folders_file)
        end.to raise_error(Cabriolet::ParseError,
                           /No folders/)
      end
    end

    context "with no files" do
      let(:no_files_file) do
        File.join(__dir__, "../fixtures/libmspack/cabd/bad_nofiles.cab")
      end

      it "raises ParseError" do
        expect do
          parser.parse(no_files_file)
        end.to raise_error(Cabriolet::ParseError, /No files/)
      end
    end

    context "with multiple folders" do
      let(:multi_folder_file) do
        File.join(__dir__,
                  "../fixtures/libmspack/cabd/normal_2files_2folders.cab")
      end

      it "parses multiple folders correctly" do
        cabinet = parser.parse(multi_folder_file)

        expect(cabinet.folder_count).to eq(2)
        expect(cabinet.folders.size).to eq(2)

        cabinet.folders.each do |folder|
          expect(folder).to be_a(Cabriolet::Models::Folder)
        end
      end
    end

    context "with multi-part cabinet (prev)" do
      let(:multi_pt2_file) do
        File.join(__dir__, "../fixtures/libmspack/cabd/multi_basic_pt2.cab")
      end

      it "reads previous cabinet metadata" do
        cabinet = parser.parse(multi_pt2_file)

        expect(cabinet.has_prev?).to be true
        expect(cabinet.prevname).not_to be_nil
      end
    end

    context "with multi-part cabinet (next)" do
      let(:multi_pt1_file) do
        File.join(__dir__, "../fixtures/libmspack/cabd/multi_basic_pt1.cab")
      end

      it "reads next cabinet metadata" do
        cabinet = parser.parse(multi_pt1_file)

        expect(cabinet.has_next?).to be true
        expect(cabinet.nextname).not_to be_nil
      end
    end

    context "with compression types" do
      let(:compression_file) do
        File.join(__dir__, "../fixtures/libmspack/cabd/mszip_lzx_qtm.cab")
      end

      it "identifies compression methods correctly" do
        cabinet = parser.parse(compression_file)

        cabinet.folders.each do |folder|
          expect(folder.compression_method).to be_a(Integer)
          expect(folder.compression_name).to be_a(String)
        end
      end
    end
  end

  describe "#parse_handle" do
    let(:cab_file) do
      File.join(__dir__, "../fixtures/libmspack/cabd/normal_2files_1folder.cab")
    end

    it "parses from an open handle" do
      handle = io_system.open(cab_file, Cabriolet::Constants::MODE_READ)

      cabinet = parser.parse_handle(handle, cab_file)

      expect(cabinet).to be_a(Cabriolet::Models::Cabinet)
      expect(cabinet.filename).to eq(cab_file)

      io_system.close(handle)
    end

    it "parses from a specific offset" do
      handle = io_system.open(cab_file, Cabriolet::Constants::MODE_READ)

      cabinet = parser.parse_handle(handle, cab_file, 0)

      expect(cabinet).to be_a(Cabriolet::Models::Cabinet)
      expect(cabinet.base_offset).to eq(0)

      io_system.close(handle)
    end
  end

  describe "file attributes" do
    let(:cab_file) do
      File.join(__dir__, "../fixtures/libmspack/cabd/normal_2files_1folder.cab")
    end

    it "parses file attributes" do
      cabinet = parser.parse(cab_file)

      cabinet.files.each do |file|
        expect(file.attribs).not_to be_nil
      end
    end
  end

  describe "folder index handling" do
    let(:cab_file) do
      File.join(__dir__, "../fixtures/libmspack/cabd/normal_2files_1folder.cab")
    end

    it "handles normal folder indices" do
      cabinet = parser.parse(cab_file)

      cabinet.files.each do |file|
        expect(file.folder_index).not_to be_nil
        expect(file.folder).not_to be_nil
      end
    end
  end

  describe "error handling" do
    it "raises IOError when file cannot be opened" do
      expect { parser.parse("/nonexistent/file.cab") }.to raise_error(Cabriolet::IOError)
    end

    context "with truncated files" do
      let(:partial_header_file) do
        File.join(__dir__, "../fixtures/libmspack/cabd/partial_shortheader.cab")
      end

      it "raises ParseError for truncated header" do
        expect { parser.parse(partial_header_file) }.to raise_error(Cabriolet::ParseError)
      end
    end
  end
end
