# frozen_string_literal: true

require "spec_helper"
require_relative "../lib/cabriolet/plugins/example"

RSpec.describe Cabriolet::Plugins::ExamplePlugin do
  let(:manager) { Cabriolet::PluginManager.instance }
  let(:plugin) { described_class.new(manager) }

  describe "#metadata" do
    let(:meta) { plugin.metadata }

    it "returns valid metadata hash" do
      expect(meta).to be_a(Hash)
      expect(meta[:name]).to eq("cabriolet-plugin-example")
      expect(meta[:version]).to eq("1.0.0")
      expect(meta[:author]).to eq("Cabriolet Team")
      expect(meta[:cabriolet_version]).to eq("~> 0.1")
    end

    it "includes all required fields" do
      required = %i[name version author description cabriolet_version]
      required.each do |field|
        expect(meta).to have_key(field)
        expect(meta[field]).not_to be_nil
      end
    end

    it "includes optional fields" do
      expect(meta).to have_key(:homepage)
      expect(meta).to have_key(:license)
      expect(meta).to have_key(:dependencies)
      expect(meta).to have_key(:tags)
      expect(meta).to have_key(:provides)
    end

    it "declares provided algorithms" do
      expect(meta[:provides][:algorithms]).to include(:rot13)
    end
  end

  describe "#setup" do
    before do
      # Clear existing registrations
      factory = Cabriolet.algorithm_factory
      factory.instance_variable_get(:@algorithms)[:compressor].delete(:rot13)
      factory.instance_variable_get(:@algorithms)[:decompressor].delete(:rot13)
    end

    it "registers ROT13 compressor" do
      plugin.setup
      factory = Cabriolet.algorithm_factory
      expect(factory.registered?(:rot13, :compressor)).to be true
    end

    it "registers ROT13 decompressor" do
      plugin.setup
      factory = Cabriolet.algorithm_factory
      expect(factory.registered?(:rot13, :decompressor)).to be true
    end
  end

  describe "lifecycle hooks" do
    it "activates successfully" do
      expect { plugin.activate }.not_to raise_error
    end

    it "deactivates successfully" do
      plugin.activate
      expect { plugin.deactivate }.not_to raise_error
    end

    it "cleans up successfully" do
      expect { plugin.cleanup }.not_to raise_error
    end
  end

  describe Cabriolet::Plugins::ExamplePlugin::ROT13Compressor do
    let(:io_system) { Cabriolet::System::IOSystem.new }
    let(:input_data) { "Hello, World!" }
    let(:input) { io_system.open_memory(input_data) }
    let(:output) { io_system.open_memory }
    let(:compressor) { described_class.new(io_system, input, output, 4096) }

    describe "#compress" do
      it "transforms text using ROT13" do
        bytes = compressor.compress
        expect(bytes).to eq(input_data.bytesize)

        output.seek(0)
        result = output.read(bytes)
        expect(result).to eq("Uryyb, Jbeyq!")
      end

      it "handles empty input" do
        empty_input = io_system.open_memory("")
        empty_compressor = described_class.new(io_system, empty_input, output, 4096)
        bytes = empty_compressor.compress
        expect(bytes).to eq(0)
      end

      it "preserves non-letter characters" do
        special_input = io_system.open_memory("123!@#$%")
        special_compressor = described_class.new(io_system, special_input, output, 4096)
        bytes = special_compressor.compress

        output.seek(0)
        result = output.read(bytes)
        expect(result).to eq("123!@#$%")
      end

      it "handles large data in chunks" do
        large_data = "A" * 10000
        large_input = io_system.open_memory(large_data)
        large_compressor = described_class.new(io_system, large_input, output, 1024)
        bytes = large_compressor.compress

        expect(bytes).to eq(10000)
        output.seek(0)
        result = output.read(bytes)
        expect(result).to eq("N" * 10000)
      end
    end
  end

  describe Cabriolet::Plugins::ExamplePlugin::ROT13Decompressor do
    let(:io_system) { Cabriolet::System::IOSystem.new }
    let(:input_data) { "Uryyb, Jbeyq!" } # ROT13 of "Hello, World!"
    let(:input) { io_system.open_memory(input_data) }
    let(:output) { io_system.open_memory }
    let(:decompressor) { described_class.new(io_system, input, output, 4096) }

    describe "#decompress" do
      it "transforms text back using ROT13" do
        bytes = decompressor.decompress(input_data.bytesize)
        expect(bytes).to eq(input_data.bytesize)

        output.seek(0)
        result = output.read(bytes)
        expect(result).to eq("Hello, World!")
      end

      it "handles partial decompression" do
        bytes = decompressor.decompress(5)
        expect(bytes).to eq(5)

        output.seek(0)
        result = output.read(bytes)
        expect(result).to eq("Hello")
      end

      it "respects byte limit" do
        bytes = decompressor.decompress(3)
        expect(bytes).to eq(3)
      end

      it "handles empty input" do
        empty_input = io_system.open_memory("")
        empty_decompressor = described_class.new(io_system, empty_input, output, 4096)
        bytes = empty_decompressor.decompress(100)
        expect(bytes).to eq(0)
      end

      it "handles large data" do
        large_data = "N" * 10000 # ROT13 of "A" * 10000
        large_input = io_system.open_memory(large_data)
        large_decompressor = described_class.new(io_system, large_input, output, 1024)
        bytes = large_decompressor.decompress(10000)

        expect(bytes).to eq(10000)
        output.seek(0)
        result = output.read(bytes)
        expect(result).to eq("A" * 10000)
      end
    end

    describe "#free" do
      it "frees resources without error" do
        expect { decompressor.free }.not_to raise_error
      end
    end
  end

  describe "ROT13 symmetry" do
    let(:io_system) { Cabriolet::System::IOSystem.new }
    let(:original) { "The Quick Brown Fox Jumps Over The Lazy Dog!" }

    it "compressing twice returns original" do
      # First compression
      input1 = io_system.open_memory(original)
      output1 = io_system.open_memory
      compressor1 = described_class::ROT13Compressor.new(io_system, input1, output1, 4096)
      compressor1.compress

      # Second compression
      output1.seek(0)
      output2 = io_system.open_memory
      compressor2 = described_class::ROT13Compressor.new(io_system, output1, output2, 4096)
      compressor2.compress

      # Should match original
      output2.seek(0)
      result = output2.read
      expect(result).to eq(original)
    end

    it "compressor and decompressor are symmetric" do
      # Compress
      input = io_system.open_memory(original)
      compressed = io_system.open_memory
      compressor = described_class::ROT13Compressor.new(io_system, input, compressed, 4096)
      compressor.compress

      # Decompress
      compressed.seek(0)
      decompressed = io_system.open_memory
      decompressor = described_class::ROT13Decompressor.new(io_system, compressed, decompressed, 4096)
      decompressor.decompress(original.bytesize)

      # Should match original
      decompressed.seek(0)
      result = decompressed.read
      expect(result).to eq(original)
    end
  end

  describe "plugin validation" do
    it "passes plugin validator" do
      result = Cabriolet::PluginValidator.validate(described_class)
      expect(result[:valid]).to be true
      expect(result[:errors]).to be_empty
    end

    it "is compatible with current Cabriolet version" do
      meta = plugin.metadata
      result = Cabriolet::PluginValidator.validate_version_compatibility(
        meta[:cabriolet_version],
        Cabriolet::VERSION
      )
      expect(result).to be_empty
    end
  end
end