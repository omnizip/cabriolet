# frozen_string_literal: true

require "spec_helper"
require_relative "../support/fixtures"

RSpec.describe Cabriolet::CAB::Decompressor do
  let(:fixture_file) { Fixtures.for(:cab).path(:basic) }

  describe "#initialize" do
    context "with default io_system" do
      subject(:decompressor) { described_class.new }

      it { is_expected.to have_attributes(io_system: be_a(Cabriolet::System::IOSystem)) }
      it { is_expected.to have_attributes(buffer_size: eq(Cabriolet.default_buffer_size)) }
      it { is_expected.to have_attributes(fix_mszip: be(false)) }
      it { is_expected.to have_attributes(salvage: be(false)) }
    end

    context "with custom io_system" do
      let(:custom_io) { Cabriolet::System::IOSystem.new }
      subject(:decompressor) { described_class.new(custom_io) }

      it { is_expected.to have_attributes(io_system: eq(custom_io)) }
    end

    context "parser initialization" do
      subject(:decompressor) { described_class.new }

      it "initializes a parser" do
        expect(decompressor.parser).to be_a(Cabriolet::CAB::Parser)
      end

      it "parser uses the same io_system" do
        parser_io = decompressor.parser.instance_variable_get(:@io_system)
        expect(parser_io).to eq(decompressor.io_system)
      end
    end
  end

  describe "#open" do
    let(:decompressor) { described_class.new }

    context "with valid CAB file" do
      it "parses and returns a Cabinet" do
        cabinet = decompressor.open(fixture_file)
        expect(cabinet).to be_a(Cabriolet::Models::Cabinet)
      end

      it "sets cabinet filename" do
        cabinet = decompressor.open(fixture_file)
        expect(cabinet.filename).to eq(fixture_file)
      end

      it "parses folders" do
        cabinet = decompressor.open(fixture_file)
        expect(cabinet.folders).not_to be_empty
        expect(cabinet.folders.first).to be_a(Cabriolet::Models::Folder)
      end

      it "parses files" do
        cabinet = decompressor.open(fixture_file)
        expect(cabinet.files).not_to be_empty
        expect(cabinet.files.first).to be_a(Cabriolet::Models::File)
      end
    end

    context "with invalid signature" do
      let(:bad_file) { Fixtures.for(:cab).edge_case(:bad_signature) }

      it "raises ParseError" do
        expect do
          decompressor.open(bad_file)
        end.to raise_error(Cabriolet::ParseError, /Invalid CAB signature/)
      end
    end

    context "with non-existent file" do
      it "raises IOError" do
        expect do
          decompressor.open("/nonexistent/file.cab")
        end.to raise_error(Cabriolet::IOError)
      end
    end

    context "with partial/corrupted files" do
      let(:partial_file) { Fixtures.for(:cab).edge_case(:partial_shortheader) }

      it "raises ParseError for short header" do
        expect do
          decompressor.open(partial_file)
        end.to raise_error(Cabriolet::ParseError)
      end
    end
  end

  describe "accessor methods" do
    subject(:decompressor) { described_class.new }

    describe "#buffer_size" do
      it "can be read" do
        expect(decompressor.buffer_size).to eq(Cabriolet.default_buffer_size)
      end

      it "can be set" do
        expect { decompressor.buffer_size = 8192 }
          .to change { decompressor.buffer_size }
          .to(8192)
      end
    end

    describe "#fix_mszip" do
      it "can be read" do
        expect(decompressor.fix_mszip).to be(false)
      end

      it "can be toggled" do
        expect { decompressor.fix_mszip = true }
          .to change { decompressor.fix_mszip }
          .from(false)
          .to(true)

        expect { decompressor.fix_mszip = false }
          .to change { decompressor.fix_mszip }
          .from(true)
          .to(false)
      end
    end

    describe "#salvage" do
      it "can be read" do
        expect(decompressor.salvage).to be(false)
      end

      it "can be toggled" do
        expect { decompressor.salvage = true }
          .to change { decompressor.salvage }
          .from(false)
          .to(true)

        expect { decompressor.salvage = false }
          .to change { decompressor.salvage }
          .from(true)
          .to(false)
      end
    end
  end

  describe "#create_decompressor" do
    let(:decompressor) { described_class.new }
    let(:input_handle) { Cabriolet::System::MemoryHandle.new("test") }
    let(:output_handle) { Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE) }

    context "with COMP_TYPE_NONE" do
      it "creates a None decompressor" do
        folder = Cabriolet::Models::Folder.new
        folder.comp_type = Cabriolet::Constants::COMP_TYPE_NONE

        result = decompressor.create_decompressor(folder, input_handle,
                                                  output_handle)
        expect(result).to be_a(Cabriolet::Decompressors::None)
      end
    end

    context "with COMP_TYPE_MSZIP" do
      it "creates an MSZIP decompressor" do
        folder = Cabriolet::Models::Folder.new
        folder.comp_type = Cabriolet::Constants::COMP_TYPE_MSZIP

        result = decompressor.create_decompressor(folder, input_handle,
                                                  output_handle)
        expect(result).to be_a(Cabriolet::Decompressors::MSZIP)
      end

      it "passes fix_mszip option" do
        folder = Cabriolet::Models::Folder.new
        folder.comp_type = Cabriolet::Constants::COMP_TYPE_MSZIP
        decompressor.fix_mszip = true

        result = decompressor.create_decompressor(folder, input_handle,
                                                  output_handle)
        expect(result.instance_variable_get(:@fix_mszip)).to be(true)
      end
    end

    context "with COMP_TYPE_LZX" do
      it "creates an LZX decompressor" do
        folder = Cabriolet::Models::Folder.new
        folder.comp_type = Cabriolet::Constants::COMP_TYPE_LZX | (15 << 8)

        result = decompressor.create_decompressor(folder, input_handle,
                                                  output_handle)
        expect(result).to be_a(Cabriolet::Decompressors::LZX)
      end

      it "extracts window size from compression level" do
        folder = Cabriolet::Models::Folder.new
        folder.comp_type = Cabriolet::Constants::COMP_TYPE_LZX | (17 << 8)

        result = decompressor.create_decompressor(folder, input_handle,
                                                  output_handle)
        expect(result.instance_variable_get(:@window_bits)).to eq(17)
      end
    end

    context "with COMP_TYPE_QUANTUM" do
      it "creates a Quantum decompressor" do
        folder = Cabriolet::Models::Folder.new
        folder.comp_type = Cabriolet::Constants::COMP_TYPE_QUANTUM | (10 << 8)

        result = decompressor.create_decompressor(folder, input_handle,
                                                  output_handle)
        expect(result).to be_a(Cabriolet::Decompressors::Quantum)
      end

      it "extracts window size from compression level" do
        folder = Cabriolet::Models::Folder.new
        folder.comp_type = Cabriolet::Constants::COMP_TYPE_QUANTUM | (13 << 8)

        result = decompressor.create_decompressor(folder, input_handle,
                                                  output_handle)
        expect(result.instance_variable_get(:@window_bits)).to eq(13)
      end
    end

    context "with unsupported compression type" do
      it "raises UnsupportedFormatError" do
        folder = Cabriolet::Models::Folder.new
        folder.comp_type = 4 # Invalid compression type (4 & 0x000F = 4)

        expect do
          decompressor.create_decompressor(folder, input_handle, output_handle)
        end.to raise_error(Cabriolet::UnsupportedFormatError,
                           /Unsupported compression type/)
      end
    end

    it "passes io_system to created decompressor" do
      folder = Cabriolet::Models::Folder.new
      folder.comp_type = Cabriolet::Constants::COMP_TYPE_NONE

      result = decompressor.create_decompressor(folder, input_handle,
                                                output_handle)
      expect(result.io_system).to eq(decompressor.io_system)
    end

    it "passes buffer_size to created decompressor" do
      decompressor.buffer_size = 2048
      folder = Cabriolet::Models::Folder.new
      folder.comp_type = Cabriolet::Constants::COMP_TYPE_NONE

      result = decompressor.create_decompressor(folder, input_handle,
                                                output_handle)
      expect(result.buffer_size).to eq(2048)
    end

    it "passes input and output handles to created decompressor" do
      folder = Cabriolet::Models::Folder.new
      folder.comp_type = Cabriolet::Constants::COMP_TYPE_NONE

      result = decompressor.create_decompressor(folder, input_handle,
                                                output_handle)
      expect(result.input).to eq(input_handle)
      expect(result.output).to eq(output_handle)
    end
  end

  describe "integration tests" do
    let(:decompressor) { described_class.new }

    it "successfully opens and parses a normal CAB file" do
      cabinet = decompressor.open(fixture_file)

      expect(cabinet.filename).to eq(fixture_file)
      expect(cabinet.folder_count).to be > 0
      expect(cabinet.file_count).to be > 0
    end

    context "with multi-part CAB files" do
      let(:multi_file) { Fixtures.for(:cab).path(:multi_pt1) }

      it "handles multi-part cabinet structure" do
        cabinet = decompressor.open(multi_file)
        expect(cabinet).to be_a(Cabriolet::Models::Cabinet)
      end
    end

    context "with CAB files with reserve data" do
      let(:reserve_file) { File.join(__dir__, "../fixtures/libmspack/cabd/reserve_HFD.cab") }

      it "handles reserve data flag" do
        cabinet = decompressor.open(reserve_file)
        expect(cabinet).to be_a(Cabriolet::Models::Cabinet)
        expect(cabinet.has_reserve?).to be(true)
      end
    end

    context "with multiple compression types" do
      let(:mixed_file) { Fixtures.for(:cab).path(:mszip) }

      it "handles mixed compression in one cabinet" do
        cabinet = decompressor.open(mixed_file)
        expect(cabinet).to be_a(Cabriolet::Models::Cabinet)
        expect(cabinet.folder_count).to be > 1
      end
    end

    context "fixture compatibility" do
      it "can open all basic fixture cabinets" do
        basic_fixtures = [:basic, :simple]
        basic_fixtures.each do |fixture_name|
          cabinet = decompressor.open(Fixtures.for(:cab).path(fixture_name))
          expect(cabinet.file_count).to be >= 0
        end
      end

      it "can open compression type fixtures" do
        compression_fixtures = [:mszip]
        compression_fixtures.each do |fixture_name|
          cabinet = decompressor.open(Fixtures.for(:cab).path(fixture_name))
          expect(cabinet.folder_count).to be >= 1
        end
      end
    end
  end
end
