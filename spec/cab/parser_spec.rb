# frozen_string_literal: true

require "spec_helper"
require_relative "../support/fixtures"

RSpec.describe Cabriolet::CAB::Parser do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:parser) { described_class.new(io_system) }

  describe "#parse" do
    subject(:parsed) { parser.parse(fixture) }

    context "with basic cabinet" do
      let(:fixture) { Fixtures.for(:cab).path(:basic) }

      it { expect { parsed }.not_to raise_error }
      its(:file_count) { is_expected.to eq(2) }
      its(:folder_count) { is_expected.to eq(1) }

      describe "cabinet structure" do
        it { is_expected.to be_a(Cabriolet::Models::Cabinet) }
        its(:length) { is_expected.to be > 0 }
        its(:set_id) { is_expected.not_to be_nil }
        its(:set_index) { is_expected.not_to be_nil }
      end

      describe "folders" do
        subject(:folders) { parsed.folders }

        it { is_expected.not_to be_empty }
        it { is_expected.to all(be_a(Cabriolet::Models::Folder)) }

        describe "first folder" do
          subject(:first_folder) { folders.first }

          its(:comp_type) { is_expected.not_to be_nil }
          its(:num_blocks) { is_expected.to be > 0 }
          its(:data_offset) { is_expected.to be >= 0 }
        end
      end

      describe "files" do
        subject(:files) { parsed.files }

        it { is_expected.to all(be_a(Cabriolet::Models::File)) }

        it "has valid filenames" do
          expect(files.map(&:filename)).to all(be_a(String).and(match(/\S/)))
        end

        it "has valid sizes" do
          expect(files.map(&:length)).to all(be >= 0)
        end

        it "links to folders" do
          files.each do |file|
            expect(file.folder).to be_a(Cabriolet::Models::Folder)
            expect(parsed.folders).to include(file.folder)
          end
        end
      end

      describe "file timestamps" do
        it "has valid date/time values" do
          parsed.files.each do |file|
            expect(file.date_y).to be >= 1980
            expect(file.date_m).to be_between(1, 12)
            expect(file.date_d).to be_between(1, 31)
            expect(file.time_h).to be_between(0, 23)
            expect(file.time_m).to be_between(0, 59)
            expect(file.time_s).to be_between(0, 59)
          end
        end
      end
    end

    context "with simple cabinet" do
      let(:fixture) { Fixtures.for(:cab).path(:simple) }

      it { expect { parsed }.not_to raise_error }
      its(:file_count) { is_expected.to be >= 0 }
    end

    context "with invalid signature" do
      let(:fixture) { Fixtures.for(:cab).path(:bad_signature) }

      it "raises ParseError" do
        expect { parsed }
          .to raise_error(Cabriolet::ParseError, /Invalid CAB signature/)
      end
    end

    context "with no folders" do
      let(:fixture) { Fixtures.for(:cab).path(:bad_no_folders) }

      it "raises ParseError" do
        expect { parsed }.to raise_error(Cabriolet::ParseError, /No folders/)
      end
    end

    context "with multi-part cabinets" do
      context "middle cabinet (has previous)" do
        let(:fixture) { Fixtures.for(:cab).path(:multi_pt2) }

        it { expect { parsed }.not_to raise_error }
        its(:has_prev?) { is_expected.to be true }
        its(:prevname) { is_expected.not_to be_nil }
      end

      context "first cabinet (has next)" do
        let(:fixture) { Fixtures.for(:cab).path(:multi_pt1) }

        it { expect { parsed }.not_to raise_error }
        its(:has_next?) { is_expected.to be true }
        its(:nextname) { is_expected.not_to be_nil }
      end
    end

    context "with compression" do
      let(:fixture) { Fixtures.for(:cab).path(:mszip) }

      it { expect { parsed }.not_to raise_error }

      describe "compression methods" do
        subject(:folders) { parsed.folders }

        it {
          expect(subject).to all(have_attributes(compression_method: be_a(Integer)))
        }

        it {
          expect(subject).to all(have_attributes(compression_name: be_a(String)))
        }
      end
    end

    context "with split cabinets" do
      Fixtures.for(:cab).scenario(:split).each_with_index do |fixture, i|
        context "split cabinet #{i + 1}" do
          let(:split_fixture) { fixture }

          it "parses successfully" do
            cabinet = parser.parse(split_fixture)
            expect(cabinet.file_count).to be >= 0
          end
        end
      end
    end
  end

  describe "#parse_handle" do
    let(:fixture) { Fixtures.for(:cab).path(:basic) }
    let(:cab_file) { fixture }

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
    subject(:parsed) { parser.parse(fixture) }

    let(:fixture) { Fixtures.for(:cab).path(:basic) }

    it "parses file attributes" do
      parsed.files.each do |file|
        expect(file.attribs).not_to be_nil
      end
    end
  end

  describe "folder index handling" do
    subject(:parsed) { parser.parse(fixture) }

    let(:fixture) { Fixtures.for(:cab).path(:basic) }

    it "has valid folder indices" do
      parsed.files.each do |file|
        expect(file.folder_index).not_to be_nil
        expect(file.folder).not_to be_nil
      end
    end
  end

  describe "error handling" do
    context "with non-existent file" do
      it "raises IOError" do
        expect { parser.parse("/nonexistent/file.cab") }
          .to raise_error(Cabriolet::IOError)
      end
    end

    context "with truncated files" do
      let(:fixture) { Fixtures.for(:cab).edge_case(:partial_shortheader) }

      it "raises ParseError for truncated header" do
        expect { parser.parse(fixture) }.to raise_error(Cabriolet::ParseError)
      end
    end
  end
end
