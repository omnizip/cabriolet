# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require_relative "../support/fixtures"

RSpec.describe Cabriolet::HLP::QuickHelp::Parser do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:parser) { described_class.new(io_system) }

  describe "#initialize" do
    subject(:parser) { described_class.new }

    it { is_expected.to be_a(described_class) }
    its(:io_system) { is_expected.to be_a(Cabriolet::System::IOSystem) }
  end

  describe "#parse" do
    context "with WinHelp files (QuickHelp fixtures unavailable)" do
      let(:fixture) { Fixtures.for(:hlp).path(:masmlib) }

      # WinHelp has different format, so this tests basic file handling
      it "attempts to parse HLP file" do
        # WinHelp format will fail in QuickHelp parser, but tests file handling
        expect { parser.parse(fixture) }.to raise_error(Cabriolet::ParseError)
      end
    end

    context "with non-existent file" do
      it "raises IOError" do
        expect { parser.parse("/nonexistent/file.hlp") }.to raise_error(Cabriolet::IOError)
      end
    end
  end

  describe "error handling" do
    context "with invalid file" do
      it "raises ParseError for non-HLP files" do
        file = Tempfile.new(["test", ".hlp"])
        file.write("NOT AN HLP FILE")
        file.close

        expect { parser.parse(file.path) }.to raise_error(Cabriolet::ParseError)

        file.unlink
      end
    end
  end
end
