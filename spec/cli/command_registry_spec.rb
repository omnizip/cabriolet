# frozen_string_literal: true

require "spec_helper"
require "cabriolet/cli/command_registry"

RSpec.describe Cabriolet::Commands::CommandRegistry do
  describe ".handler_for" do
    context "when format is registered" do
      before do
        # Clear registry first to start clean (before(:each) hook may have registered handlers)
        described_class.clear
        described_class.register_format(:test, TestHandler)
      end

      it "returns the registered handler class" do
        expect(described_class.handler_for(:test)).to eq(TestHandler)
      end
    end

    context "when format is not registered" do
      it "returns nil" do
        expect(described_class.handler_for(:nonexistent)).to be_nil
      end
    end
  end

  describe ".register_format" do
    before do
      # Clear registry first to start clean
      described_class.clear
    end

    context "with valid handler class" do
      it "registers the handler" do
        described_class.register_format(:test, TestHandler)
        expect(described_class.handler_for(:test)).to eq(TestHandler)
      end

      it "allows re-registration" do
        described_class.register_format(:test, TestHandler)
        described_class.register_format(:test, AnotherTestHandler)
        expect(described_class.handler_for(:test)).to eq(AnotherTestHandler)
      end
    end

    context "with invalid handler class" do
      it "raises error for class without required methods" do
        expect do
          described_class.register_format(:test, InvalidHandler)
        end.to raise_error(ArgumentError, /must implement/)
      end
    end
  end

  describe ".format_registered?" do
    before do
      # Clear registry first to start clean
      described_class.clear
    end

    context "when format is registered" do
      before do
        described_class.register_format(:test, TestHandler)
      end

      it "returns true" do
        expect(described_class.format_registered?(:test)).to be(true)
      end
    end

    context "when format is not registered" do
      it "returns false" do
        expect(described_class.format_registered?(:nonexistent)).to be(false)
      end
    end
  end

  describe ".registered_formats" do
    before do
      # Clear registry first to start clean
      described_class.clear
    end

    context "when no formats are registered" do
      it "returns empty array" do
        expect(described_class.registered_formats).to eq([])
      end
    end

    context "when formats are registered" do
      before do
        described_class.register_format(:cab, TestHandler)
        described_class.register_format(:chm, TestHandler)
        described_class.register_format(:szdd, TestHandler)
      end

      it "returns all registered format symbols" do
        formats = described_class.registered_formats
        expect(formats).to include(:cab, :chm, :szdd)
        expect(formats.size).to eq(3)
      end

      it "returns formats in registration order" do
        formats = described_class.registered_formats
        expect(formats).to eq(%i[cab chm szdd])
      end
    end
  end

  describe ".clear" do
    before do
      described_class.register_format(:test, TestHandler)
    end

    it "removes all registered handlers" do
      described_class.clear
      expect(described_class.registered_formats).to eq([])
    end

    it "allows re-registration after clearing" do
      described_class.clear
      described_class.register_format(:test, AnotherTestHandler)
      expect(described_class.handler_for(:test)).to eq(AnotherTestHandler)
    end
  end

  # Test handler classes
  class TestHandler
    def list(file, options = {}); end
    def extract(file, output_dir, options = {}); end
    def create(output, files, options = {}); end
    def info(file, options = {}); end
    def test(file, options = {}); end
  end

  class AnotherTestHandler
    def list(file, options = {}); end
    def extract(file, output_dir, options = {}); end
    def create(output, files, options = {}); end
    def info(file, options = {}); end
    def test(file, options = {}); end
  end

  class InvalidHandler
    # Missing required methods
  end
end
