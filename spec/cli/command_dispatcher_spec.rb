# frozen_string_literal: true

require "spec_helper"
require "cabriolet/cli/command_dispatcher"
require "cabriolet/cli/command_registry"

RSpec.describe Cabriolet::Commands::CommandDispatcher do
  let(:cab_fixture) do
    File.join(__dir__, "fixtures/libmspack/cabd/normal_2files_1folder.cab")
  end

  # Mock handler for testing
  class MockCommandHandler < Cabriolet::Commands::BaseCommandHandler
    attr_reader :last_command, :last_file, :last_args, :last_options

    def initialize(verbose: false)
      super
      @calls = []
    end

    def list(file, options = {})
      @calls << [:list, file, options]
      "Listed #{file}"
    end

    def extract(file, output_dir = nil, options = {})
      @calls << [:extract, file, output_dir, options]
      "Extracted #{file}"
    end

    def create(output, files = [], options = {})
      @calls << [:create, output, files, options]
      "Created #{output}"
    end

    def info(file, options = {})
      @calls << [:info, file, options]
      "Info for #{file}"
    end

    def test(file, options = {})
      @calls << [:test, file, options]
      "Tested #{file}"
    end

    def calls
      @calls
    end
  end

  before do
    # Register mock handler for testing
    Cabriolet::Commands::CommandRegistry.register_format(:test,
                                                         MockCommandHandler)
  end

  after do
    # Clean up
    Cabriolet::Commands::CommandRegistry.instance_variable_set(:@handlers, {})
    # Re-register real handlers
    require_relative "../../lib/cabriolet/cli"
  end

  describe "#initialize" do
    it "accepts format override option" do
      dispatcher = described_class.new(format: :cab)
      expect(dispatcher.instance_variable_get(:@format_override)).to eq(:cab)
    end

    it "accepts verbose option" do
      dispatcher = described_class.new(verbose: true)
      expect(dispatcher.instance_variable_get(:@verbose)).to be(true)
    end

    it "defaults verbose to false" do
      dispatcher = described_class.new
      expect(dispatcher.instance_variable_get(:@verbose)).to be(false)
    end

    it "converts format string to symbol" do
      dispatcher = described_class.new(format: "cab")
      expect(dispatcher.instance_variable_get(:@format_override)).to eq(:cab)
    end
  end

  describe "#dispatch" do
    let(:dispatcher) { described_class.new }

    context "with format override" do
      it "uses specified format instead of auto-detection" do
        dispatcher = described_class.new(format: :test)
        allow_any_instance_of(Cabriolet::FormatDetector).to receive(:detect).and_return(:cab)

        result = dispatcher.dispatch(:list, cab_fixture)
        expect(result).to eq("Listed #{cab_fixture}")
      end
    end

    context "with list command" do
      it "delegates to handler's list method" do
        dispatcher = described_class.new(format: :test)
        dispatcher.dispatch(:list, cab_fixture)
        MockCommandHandler.new.calls
        # Verify through the registry
        handler = Cabriolet::Commands::CommandRegistry.handler_for(:test)
        expect(handler).to eq(MockCommandHandler)
      end
    end

    context "with extract command" do
      it "passes output_dir as second argument" do
        dispatcher = described_class.new(format: :test)
        dispatcher.dispatch(:extract, cab_fixture, "output/")
        # Command should complete without error
      end

      it "passes options[:output] as output_dir when no output_dir given" do
        dispatcher = described_class.new(format: :test)
        dispatcher.dispatch(:extract, cab_fixture, nil,
                            output: "custom_output/")
        # Command should complete without error
      end
    end

    context "with create command" do
      it "passes files array to handler" do
        dispatcher = described_class.new(format: :test)
        dispatcher.dispatch(:create, "output.cab", ["file1.txt", "file2.txt"])
        # Command should complete without error
      end
    end

    context "with info command" do
      it "delegates to handler's info method" do
        dispatcher = described_class.new(format: :test)
        result = dispatcher.dispatch(:info, cab_fixture)
        expect(result).to eq("Info for #{cab_fixture}")
      end
    end

    context "with test command" do
      it "delegates to handler's test method" do
        dispatcher = described_class.new(format: :test)
        result = dispatcher.dispatch(:test, cab_fixture)
        expect(result).to eq("Tested #{cab_fixture}")
      end
    end

    context "when format detection fails" do
      it "raises error with supported formats in message" do
        allow_any_instance_of(Cabriolet::FormatDetector).to receive(:detect).and_return(nil)

        expect do
          dispatcher.dispatch(:list, "unknown.bin")
        end.to raise_error(Cabriolet::Error, /Cannot detect format/)
      end
    end

    context "when handler is not registered for detected format" do
      before do
        # Register a format that FormatDetector can return but without a handler
        allow(Cabriolet::FormatDetector).to receive(:detect).and_return(:unregistered)
      end

      it "raises error about missing handler" do
        expect do
          dispatcher.dispatch(:list, "test.bin")
        end.to raise_error(Cabriolet::Error, /No command handler registered/)
      end
    end
  end

  describe ".format_supported?" do
    before do
      Cabriolet::Commands::CommandRegistry.register_format(:test,
                                                           MockCommandHandler)
    end

    it "returns true for registered format" do
      expect(described_class.format_supported?(:test)).to be(true)
    end

    it "returns false for unregistered format" do
      expect(described_class.format_supported?(:nonexistent)).to be(false)
    end
  end

  describe ".supported_formats" do
    before do
      Cabriolet::Commands::CommandRegistry.register_format(:test,
                                                           MockCommandHandler)
    end

    it "returns list of registered formats" do
      formats = described_class.supported_formats
      expect(formats).to include(:test)
    end
  end
end
