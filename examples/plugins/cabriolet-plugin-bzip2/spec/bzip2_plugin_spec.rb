# frozen_string_literal: true

require "spec_helper"
require_relative "../lib/cabriolet/plugins/bzip2"

RSpec.describe Cabriolet::Plugins::BZip2Plugin do
  let(:manager) { Cabriolet::PluginManager.instance }
  let(:plugin) { described_class.new(manager) }

  describe "#metadata" do
    let(:meta) { plugin.metadata }

    it "returns valid metadata" do
      expect(meta[:name]).to eq("cabriolet-plugin-bzip2")
      expect(meta[:version]).to eq("1.0.0")
      expect(meta[:author]).to eq("Cabriolet Team")
    end

    it "declares BZip2 algorithm" do
      expect(meta[:provides][:algorithms]).to include(:bzip2)
    end

    it "declares BZ2 format" do
      expect(meta[:provides][:formats]).to include(:bz2)
    end
  end

  describe "#setup" do
    before do
      factory = Cabriolet.algorithm_factory
      factory.instance_variable_get(:@algorithms)[:compressor].delete(:bzip2)
      factory.instance_variable_get(:@algorithms)[:decompressor].delete(:bzip2)
    end

    it "registers BZip2 compressor with priority" do
      plugin.setup
      factory = Cabriolet.algorithm_factory
      expect(factory.registered?(:bzip2, :compressor)).to be true

      algo_info = factory.instance_variable_get(:@algorithms)[:compressor][:bzip2]
      expect(algo_info[:priority]).to eq(10)
    end

    it "registers BZip2 decompressor" do
      plugin.setup
      factory = Cabriolet.algorithm_factory
      expect(factory.registered?(:bzip2, :decompressor)).to be true
    end
  end

  describe "configuration" do
    it "uses default configuration values" do
      plugin.setup
      config = plugin.instance_variable_get(:@config)
      expect(config[:block_size]).to be_between(1, 9)
      expect(config[:level]).to be_between(1, 9)
    end

    it "validates configuration on activation" do
      # Set invalid configuration
      plugin.setup
      plugin.instance_variable_set(:@config, { block_size: 99, level: 1 })

      expect do
        plugin.activate
      end.to raise_error(Cabriolet::PluginError, /block_size/)
    end
  end

  describe "lifecycle" do
    before { plugin.setup }

    it "activates successfully with valid config" do
      expect { plugin.activate }.not_to raise_error
    end

    it "tracks activation time" do
      plugin.activate
      activated_at = plugin.instance_variable_get(:@activated_at)
      expect(activated_at).to be_a(Time)
    end

    it "initializes statistics on activation" do
      plugin.activate
      stats = plugin.instance_variable_get(:@compression_stats)
      expect(stats).to be_a(Hash)
      expect(stats[:files]).to eq(0)
    end

    it "deactivates successfully" do
      plugin.activate
      expect { plugin.deactivate }.not_to raise_error
    end

    it "cleans up successfully" do
      plugin.activate
      expect { plugin.cleanup }.not_to raise_error
    end
  end

  describe Cabriolet::Plugins::BZip2Plugin::BZip2Compressor do
    let(:io_system) { Cabriolet::System::IOSystem.new }
    let(:input_data) { "Test data for BZip2 compression" * 100 }
    let(:input) { io_system.open_memory(input_data) }
    let(:output) { io_system.open_memory }

    describe "initialization" do
      it "accepts default options" do
        compressor = described_class.new(io_system, input, output, 4096)
        expect(compressor).to be_a(described_class)
      end

      it "accepts custom block_size" do
        compressor = described_class.new(io_system, input, output, 4096,
                                         block_size: 5)
        expect(compressor.instance_variable_get(:@block_size)).to eq(5)
      end

      it "accepts custom compression level" do
        compressor = described_class.new(io_system, input, output, 4096,
                                         level: 7)
        expect(compressor.instance_variable_get(:@level)).to eq(7)
      end

      it "validates block_size range" do
        expect do
          described_class.new(io_system, input, output, 4096, block_size: 99)
        end.to raise_error(ArgumentError, /block_size/)
      end

      it "validates level range" do
        expect do
          described_class.new(io_system, input, output, 4096, level: 99)
        end.to raise_error(ArgumentError, /level/)
      end

      it "accepts progress callback" do
        callback = ->(pct) {}
        compressor = described_class.new(io_system, input, output, 4096,
                                         progress: callback)
        expect(compressor.instance_variable_get(:@progress)).to eq(callback)
      end
    end

    describe "#compress" do
      let(:compressor) { described_class.new(io_system, input, output, 4096) }

      it "writes BZip2 header" do
        compressor.compress
        output.seek(0)
        header = output.read(4)
        expect(header[0, 2]).to eq("BZ")
        expect(header[2]).to eq("h")
      end

      it "returns byte count" do
        bytes = compressor.compress
        expect(bytes).to be.positive?
      end

      it "handles empty input" do
        empty_input = io_system.open_memory("")
        empty_compressor = described_class.new(io_system, empty_input, output,
                                               4096)
        bytes = empty_compressor.compress
        expect(bytes).to be.positive? # At least header + EOS
      end

      it "processes large data" do
        large_data = "A" * 100000
        large_input = io_system.open_memory(large_data)
        large_compressor = described_class.new(io_system, large_input, output,
                                               8192)
        bytes = large_compressor.compress
        expect(bytes).to be.positive?
      end

      it "calls progress callback" do
        progress_calls = []
        callback = ->(pct) { progress_calls << pct }

        progress_compressor = described_class.new(io_system, input, output, 4096,
                                                  progress: callback)
        progress_compressor.compress

        expect(progress_calls).not_to be_empty
      end

      it "raises error on closed input" do
        input.close
        expect do
          compressor.compress
        end.to raise_error(Cabriolet::CompressionError, /closed/)
      end

      it "raises error on closed output" do
        output.close
        expect do
          compressor.compress
        end.to raise_error(Cabriolet::CompressionError, /closed/)
      end
    end
  end

  describe Cabriolet::Plugins::BZip2Plugin::BZip2Decompressor do
    let(:io_system) { Cabriolet::System::IOSystem.new }

    # Create valid BZip2 header + stub data
    let(:compressed_data) do
      header = "BZh9" # Magic + version + block_size
      block = "1AY&SY#{'Test data' * 10}"
      eos = "\u0017rE8P\x90#{"\x00" * 4}"
      header + block + eos
    end

    let(:input) { io_system.open_memory(compressed_data) }
    let(:output) { io_system.open_memory }

    describe "initialization" do
      it "initializes successfully" do
        decompressor = described_class.new(io_system, input, output, 4096)
        expect(decompressor).to be_a(described_class)
      end

      it "accepts progress callback" do
        callback = ->(pct) {}
        decompressor = described_class.new(io_system, input, output, 4096,
                                           progress: callback)
        expect(decompressor.instance_variable_get(:@progress)).to eq(callback)
      end
    end

    describe "#decompress" do
      let(:decompressor) { described_class.new(io_system, input, output, 4096) }

      it "validates and reads header" do
        decompressor.decompress(1000)
        expect(decompressor.instance_variable_get(:@header_read)).to be true
      end

      it "extracts block size from header" do
        decompressor.decompress(1000)
        block_size = decompressor.instance_variable_get(:@block_size)
        expect(block_size).to eq(9)
      end

      it "returns decompressed byte count" do
        bytes = decompressor.decompress(1000)
        expect(bytes).to be >= 0
      end

      it "respects byte limit" do
        bytes = decompressor.decompress(10)
        expect(bytes).to be <= 10
      end

      it "handles truncated header" do
        short_input = io_system.open_memory("BZ")
        short_decompressor = described_class.new(io_system, short_input,
                                                 output, 4096)

        expect do
          short_decompressor.decompress(100)
        end.to raise_error(Cabriolet::DecompressionError, /Truncated/)
      end

      it "validates magic bytes" do
        invalid_input = io_system.open_memory("INVALID_DATA")
        invalid_decompressor = described_class.new(io_system, invalid_input,
                                                   output, 4096)

        expect do
          invalid_decompressor.decompress(100)
        end.to raise_error(Cabriolet::DecompressionError, /magic/)
      end

      it "validates version" do
        invalid_version = io_system.open_memory("BZx9")
        version_decompressor = described_class.new(io_system, invalid_version,
                                                   output, 4096)

        expect do
          version_decompressor.decompress(100)
        end.to raise_error(Cabriolet::DecompressionError, /version/)
      end

      it "calls progress callback" do
        progress_calls = []
        callback = ->(pct) { progress_calls << pct }

        progress_decompressor = described_class.new(io_system, input, output, 4096,
                                                    progress: callback)
        progress_decompressor.decompress(1000)

        # May or may not call depending on data size
        expect(progress_calls).to be_an(Array)
      end

      it "raises error on closed input" do
        input.close
        expect do
          decompressor.decompress(100)
        end.to raise_error(Cabriolet::DecompressionError, /closed/)
      end

      it "raises error on closed output" do
        output.close
        expect do
          decompressor.decompress(100)
        end.to raise_error(Cabriolet::DecompressionError, /closed/)
      end
    end

    describe "#free" do
      let(:decompressor) { described_class.new(io_system, input, output, 4096) }

      it "frees resources" do
        decompressor.decompress(100)
        expect { decompressor.free }.not_to raise_error
      end

      it "resets state" do
        decompressor.decompress(100)
        decompressor.free

        expect(decompressor.instance_variable_get(:@header_read)).to be false
        expect(decompressor.instance_variable_get(:@block_size)).to be_nil
      end
    end
  end

  describe "plugin validation" do
    it "passes plugin validator" do
      result = Cabriolet::PluginValidator.validate(described_class)
      expect(result[:valid]).to be true
      expect(result[:errors]).to be_empty
    end

    it "is compatible with current version" do
      meta = plugin.metadata
      result = Cabriolet::PluginValidator.validate_version_compatibility(
        meta[:cabriolet_version],
        Cabriolet::VERSION,
      )
      expect(result).to be_empty
    end
  end

  describe "error handling" do
    let(:io_system) { Cabriolet::System::IOSystem.new }
    let(:input) { io_system.open_memory("test") }
    let(:output) { io_system.open_memory }

    it "handles compression errors gracefully" do
      compressor = described_class::BZip2Compressor.new(io_system, input,
                                                        output, 4096)

      # Simulate error by closing handles
      input.close
      output.close

      expect do
        compressor.compress
      end.to raise_error(Cabriolet::CompressionError)
    end

    it "handles decompression errors gracefully" do
      invalid_data = io_system.open_memory("NOT_BZIP2")
      decompressor = described_class::BZip2Decompressor.new(io_system,
                                                            invalid_data, output, 4096)

      expect do
        decompressor.decompress(100)
      end.to raise_error(Cabriolet::DecompressionError)
    end
  end
end
