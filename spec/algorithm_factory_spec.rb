# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::AlgorithmFactory do
  describe "#initialize" do
    context "with auto_register: true (default)" do
      let(:factory) { described_class.new }

      it "creates empty registry structure" do
        expect(factory.algorithms).to be_a(Hash)
        expect(factory.algorithms).to have_key(:compressor)
        expect(factory.algorithms).to have_key(:decompressor)
      end

      it "registers all 5 built-in decompressors" do
        decompressors = factory.algorithms[:decompressor]
        expect(decompressors).to have_key(:none)
        expect(decompressors).to have_key(:lzss)
        expect(decompressors).to have_key(:mszip)
        expect(decompressors).to have_key(:lzx)
        expect(decompressors).to have_key(:quantum)
      end

      it "registers all 4 built-in compressors" do
        compressors = factory.algorithms[:compressor]
        expect(compressors).to have_key(:lzss)
        expect(compressors).to have_key(:mszip)
        expect(compressors).to have_key(:lzx)
        expect(compressors).to have_key(:quantum)
      end

      it "does not register 'none' compressor" do
        compressors = factory.algorithms[:compressor]
        expect(compressors).not_to have_key(:none)
      end

      it "registers correct decompressor classes" do
        decompressors = factory.algorithms[:decompressor]
        expect(decompressors[:none][:class])
          .to eq(Cabriolet::Decompressors::None)
        expect(decompressors[:lzss][:class])
          .to eq(Cabriolet::Decompressors::LZSS)
        expect(decompressors[:mszip][:class])
          .to eq(Cabriolet::Decompressors::MSZIP)
        expect(decompressors[:lzx][:class])
          .to eq(Cabriolet::Decompressors::LZX)
        expect(decompressors[:quantum][:class])
          .to eq(Cabriolet::Decompressors::Quantum)
      end

      it "registers correct compressor classes" do
        compressors = factory.algorithms[:compressor]
        expect(compressors[:lzss][:class])
          .to eq(Cabriolet::Compressors::LZSS)
        expect(compressors[:mszip][:class])
          .to eq(Cabriolet::Compressors::MSZIP)
        expect(compressors[:lzx][:class])
          .to eq(Cabriolet::Compressors::LZX)
        expect(compressors[:quantum][:class])
          .to eq(Cabriolet::Compressors::Quantum)
      end
    end

    context "with auto_register: false" do
      let(:factory) { described_class.new(auto_register: false) }

      it "creates empty registry structure" do
        expect(factory.algorithms[:compressor]).to be_empty
        expect(factory.algorithms[:decompressor]).to be_empty
      end

      it "does not register any decompressors" do
        expect(factory.algorithms[:decompressor]).to eq({})
      end

      it "does not register any compressors" do
        expect(factory.algorithms[:compressor]).to eq({})
      end
    end
  end

  describe "#register" do
    let(:factory) { described_class.new(auto_register: false) }

    it "registers a decompressor algorithm" do
      factory.register(:test, Cabriolet::Decompressors::None,
                       category: :decompressor)
      expect(factory.algorithms[:decompressor]).to have_key(:test)
    end

    it "registers a compressor algorithm" do
      factory.register(:test, Cabriolet::Compressors::LZSS,
                       category: :compressor)
      expect(factory.algorithms[:compressor]).to have_key(:test)
    end

    it "stores algorithm class" do
      factory.register(:test, Cabriolet::Decompressors::MSZIP,
                       category: :decompressor)
      info = factory.algorithms[:decompressor][:test]
      expect(info[:class]).to eq(Cabriolet::Decompressors::MSZIP)
    end

    it "uses default priority of 0" do
      factory.register(:test, Cabriolet::Compressors::LZX,
                       category: :compressor)
      info = factory.algorithms[:compressor][:test]
      expect(info[:priority]).to eq(0)
    end

    it "accepts custom priority" do
      factory.register(:test, Cabriolet::Decompressors::Quantum,
                       category: :decompressor, priority: 10)
      info = factory.algorithms[:decompressor][:test]
      expect(info[:priority]).to eq(10)
    end

    it "accepts optional format restriction" do
      factory.register(:test, Cabriolet::Compressors::MSZIP,
                       category: :compressor, format: :cab)
      info = factory.algorithms[:compressor][:test]
      expect(info[:format]).to eq(:cab)
    end

    it "returns self for method chaining" do
      result = factory.register(:test, Cabriolet::Decompressors::None,
                                category: :decompressor)
      expect(result).to eq(factory)
    end

    it "allows chaining multiple registrations" do
      factory
        .register(:algo1, Cabriolet::Compressors::LZSS,
                  category: :compressor)
        .register(:algo2, Cabriolet::Decompressors::None,
                  category: :decompressor)

      expect(factory.algorithms[:compressor]).to have_key(:algo1)
      expect(factory.algorithms[:decompressor]).to have_key(:algo2)
    end

    it "raises ArgumentError for invalid category" do
      expect do
        factory.register(:test, Cabriolet::Compressors::LZSS,
                         category: :invalid)
      end.to raise_error(Cabriolet::ArgumentError,
                         /Invalid category: invalid/)
    end

    it "raises ArgumentError for non-Base compressor class" do
      fake_compressor = Class.new
      stub_const("FakeCompressor", fake_compressor)
      expect do
        factory.register(:fake, FakeCompressor, category: :compressor)
      end.to raise_error(Cabriolet::ArgumentError,
                         /must inherit from/)
    end

    it "raises ArgumentError for non-Base decompressor class" do
      fake_decompressor = Class.new
      stub_const("FakeDecompressor", fake_decompressor)
      expect do
        factory.register(:fake, FakeDecompressor,
                         category: :decompressor)
      end.to raise_error(Cabriolet::ArgumentError,
                         /must inherit from/)
    end
  end

  describe "#create" do
    let(:factory) { described_class.new }
    let(:io_system) { Cabriolet::System::IOSystem.new }
    let(:input) { instance_double(Cabriolet::System::MemoryHandle) }
    let(:output) { instance_double(Cabriolet::System::MemoryHandle) }

    context "with symbol type" do
      it "creates a decompressor from symbol" do
        decompressor = factory.create(:mszip, :decompressor,
                                      io_system, input, output, 4096)
        expect(decompressor)
          .to be_a(Cabriolet::Decompressors::MSZIP)
      end

      it "creates a compressor from symbol" do
        compressor = factory.create(:lzx, :compressor,
                                    io_system, input, output, 8192)
        expect(compressor).to be_a(Cabriolet::Compressors::LZX)
      end

      it "passes io_system to algorithm" do
        algorithm = factory.create(:mszip, :decompressor,
                                   io_system, input, output, 4096)
        expect(algorithm.io_system).to eq(io_system)
      end

      it "passes input handle to algorithm" do
        algorithm = factory.create(:lzss, :compressor,
                                   io_system, input, output, 4096)
        expect(algorithm.input).to eq(input)
      end

      it "passes output handle to algorithm" do
        algorithm = factory.create(:quantum, :decompressor,
                                   io_system, input, output, 4096)
        expect(algorithm.output).to eq(output)
      end

      it "passes buffer_size to algorithm" do
        algorithm = factory.create(:lzx, :compressor,
                                   io_system, input, output, 16384)
        expect(algorithm.buffer_size).to eq(16384)
      end
    end

    context "with integer type constants" do
      it "normalizes COMP_TYPE_NONE (0) to :none" do
        decompressor = factory.create(
          Cabriolet::Constants::COMP_TYPE_NONE,
          :decompressor, io_system, input, output, 4096
        )
        expect(decompressor)
          .to be_a(Cabriolet::Decompressors::None)
      end

      it "normalizes COMP_TYPE_MSZIP (1) to :mszip" do
        compressor = factory.create(
          Cabriolet::Constants::COMP_TYPE_MSZIP,
          :compressor, io_system, input, output, 4096
        )
        expect(compressor).to be_a(Cabriolet::Compressors::MSZIP)
      end

      it "normalizes COMP_TYPE_QUANTUM (2) to :quantum" do
        decompressor = factory.create(
          Cabriolet::Constants::COMP_TYPE_QUANTUM,
          :decompressor, io_system, input, output, 4096
        )
        expect(decompressor)
          .to be_a(Cabriolet::Decompressors::Quantum)
      end

      it "normalizes COMP_TYPE_LZX (3) to :lzx" do
        compressor = factory.create(
          Cabriolet::Constants::COMP_TYPE_LZX,
          :compressor, io_system, input, output, 4096
        )
        expect(compressor).to be_a(Cabriolet::Compressors::LZX)
      end
    end

    context "with error handling" do
      it "raises UnsupportedFormatError for unknown type" do
        expect do
          factory.create(:unknown, :decompressor,
                         io_system, input, output, 4096)
        end.to raise_error(Cabriolet::UnsupportedFormatError,
                           /Unknown decompressor algorithm: unknown/)
      end

      it "raises UnsupportedFormatError for unregistered compressor" do
        expect do
          factory.create(:none, :compressor,
                         io_system, input, output, 4096)
        end.to raise_error(Cabriolet::UnsupportedFormatError,
                           /Unknown compressor algorithm: none/)
      end

      it "raises ArgumentError for invalid category" do
        expect do
          factory.create(:mszip, :invalid,
                         io_system, input, output, 4096)
        end.to raise_error(Cabriolet::ArgumentError,
                           /Invalid category: invalid/)
      end
    end
  end

  describe "#registered?" do
    let(:factory) { described_class.new }

    it "returns true for registered decompressor" do
      expect(factory.registered?(:mszip, :decompressor)).to be true
    end

    it "returns true for registered compressor" do
      expect(factory.registered?(:lzx, :compressor)).to be true
    end

    it "returns false for unregistered algorithm" do
      expect(factory.registered?(:unknown, :decompressor)).to be false
    end

    it "returns false for 'none' compressor (not registered)" do
      expect(factory.registered?(:none, :compressor)).to be false
    end

    it "returns true for 'none' decompressor" do
      expect(factory.registered?(:none, :decompressor)).to be true
    end
  end

  describe "#list" do
    let(:factory) { described_class.new }

    context "without category filter" do
      it "returns both compressors and decompressors" do
        list = factory.list
        expect(list).to have_key(:compressor)
        expect(list).to have_key(:decompressor)
      end

      it "returns a copy of the algorithms hash" do
        list = factory.list
        list[:compressor][:fake] = {}
        expect(factory.algorithms[:compressor]).not_to have_key(:fake)
      end

      it "includes all registered decompressors" do
        list = factory.list
        expect(list[:decompressor].keys)
          .to contain_exactly(:none, :lzss, :mszip, :lzx, :quantum)
      end

      it "includes all registered compressors" do
        list = factory.list
        expect(list[:compressor].keys)
          .to contain_exactly(:lzss, :mszip, :lzx, :quantum)
      end
    end

    context "with category filter" do
      it "returns only decompressors when filtered" do
        list = factory.list(:decompressor)
        expect(list.keys)
          .to contain_exactly(:none, :lzss, :mszip, :lzx, :quantum)
      end

      it "returns only compressors when filtered" do
        list = factory.list(:compressor)
        expect(list.keys)
          .to contain_exactly(:lzss, :mszip, :lzx, :quantum)
      end

      it "returns empty hash for invalid category" do
        list = factory.list(:invalid)
        expect(list).to eq({})
      end

      it "returns a copy of the category hash" do
        list = factory.list(:compressor)
        list[:fake] = {}
        expect(factory.algorithms[:compressor]).not_to have_key(:fake)
      end
    end
  end

  describe "#unregister" do
    let(:factory) { described_class.new }

    it "removes registered decompressor" do
      expect(factory.registered?(:mszip, :decompressor)).to be true
      factory.unregister(:mszip, :decompressor)
      expect(factory.registered?(:mszip, :decompressor)).to be false
    end

    it "removes registered compressor" do
      expect(factory.registered?(:lzx, :compressor)).to be true
      factory.unregister(:lzx, :compressor)
      expect(factory.registered?(:lzx, :compressor)).to be false
    end

    it "returns true when algorithm is removed" do
      result = factory.unregister(:quantum, :decompressor)
      expect(result).to be true
    end

    it "returns false when algorithm not found" do
      result = factory.unregister(:unknown, :decompressor)
      expect(result).to be false
    end

    it "does not affect other category" do
      factory.unregister(:lzss, :compressor)
      expect(factory.registered?(:lzss, :decompressor)).to be true
    end
  end

  describe "custom algorithm registration" do
    let(:factory) { described_class.new(auto_register: false) }

    # Create custom test classes
    let(:custom_compressor) do
      Class.new(Cabriolet::Compressors::Base) do
        def compress
          0
        end
      end
    end

    let(:custom_decompressor) do
      Class.new(Cabriolet::Decompressors::Base) do
        def decompress(_bytes)
          0
        end
      end
    end

    before do
      stub_const("CustomCompressor", custom_compressor)
      stub_const("CustomDecompressor", custom_decompressor)
    end

    it "allows registering custom compressor" do
      factory.register(:custom, CustomCompressor, category: :compressor)
      expect(factory.registered?(:custom, :compressor)).to be true
    end

    it "allows registering custom decompressor" do
      factory.register(:custom, CustomDecompressor,
                       category: :decompressor)
      expect(factory.registered?(:custom, :decompressor)).to be true
    end

    it "can create instances of custom compressor" do
      factory.register(:custom, CustomCompressor, category: :compressor)
      io_system = Cabriolet::System::IOSystem.new
      input = instance_double(Cabriolet::System::MemoryHandle)
      output = instance_double(Cabriolet::System::MemoryHandle)

      algorithm = factory.create(:custom, :compressor,
                                 io_system, input, output, 4096)
      expect(algorithm).to be_a(CustomCompressor)
    end

    it "can create instances of custom decompressor" do
      factory.register(:custom, CustomDecompressor,
                       category: :decompressor)
      io_system = Cabriolet::System::IOSystem.new
      input = instance_double(Cabriolet::System::MemoryHandle)
      output = instance_double(Cabriolet::System::MemoryHandle)

      algorithm = factory.create(:custom, :decompressor,
                                 io_system, input, output, 4096)
      expect(algorithm).to be_a(CustomDecompressor)
    end
  end

  describe "module-level factory access" do
    it "provides access to global factory via Cabriolet.algorithm_factory" do
      expect(Cabriolet.algorithm_factory)
        .to be_a(described_class)
    end

    it "returns the same instance on repeated calls" do
      factory1 = Cabriolet.algorithm_factory
      factory2 = Cabriolet.algorithm_factory
      expect(factory1).to equal(factory2)
    end

    it "allows replacing the global factory" do
      original = Cabriolet.algorithm_factory
      new_factory = described_class.new(auto_register: false)
      Cabriolet.algorithm_factory = new_factory
      expect(Cabriolet.algorithm_factory).to equal(new_factory)
      # Restore original
      Cabriolet.algorithm_factory = original
    end
  end

  describe "Integration: Custom Algorithm Registration" do
    let(:io_system) { Cabriolet::System::IOSystem.new }

    describe "custom decompressor" do
      # Simple custom decompressor that reverses input data
      let(:custom_decompressor_class) do
        Class.new(Cabriolet::Decompressors::Base) do
          def decompress(input_size, output_size)
            # Custom decompression logic - simple reverse as example
            data = @input.read(input_size)
            @output.write(data.reverse)
            output_size
          end
        end
      end

      before do
        stub_const("CustomReverseDecompressor", custom_decompressor_class)
      end

      it "allows registration of custom decompressor globally" do
        # Register custom algorithm globally
        Cabriolet.algorithm_factory.register(
          :custom_reverse,
          CustomReverseDecompressor,
          category: :decompressor,
        )

        # Verify registration
        expect(Cabriolet.algorithm_factory.registered?(:custom_reverse,
                                                       :decompressor)).to be true

        # Use in a format handler
        input_data = "Hello, World!"
        input_handle = Cabriolet::System::MemoryHandle.new(input_data, Cabriolet::Constants::MODE_READ)
        output_handle = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)

        decompressor = Cabriolet.algorithm_factory.create(
          :custom_reverse,
          :decompressor,
          io_system,
          input_handle,
          output_handle,
          input_data.bytesize,
        )

        decompressor.decompress(input_data.bytesize, input_data.bytesize)
        output_handle.rewind
        result = output_handle.read

        expect(result).to eq(input_data.reverse)

        # Cleanup global registration
        Cabriolet.algorithm_factory.unregister(:custom_reverse, :decompressor)
      end

      it "allows per-instance custom factory" do
        # Ensure it's not already registered globally (cleanup from previous test)
        Cabriolet.algorithm_factory.unregister(:custom_reverse, :decompressor)

        # Create isolated custom factory
        custom_factory = described_class.new(auto_register: false)
        custom_factory.register(
          :custom_reverse,
          CustomReverseDecompressor,
          category: :decompressor,
        )

        # Verify custom factory has the algorithm
        expect(custom_factory.registered?(:custom_reverse,
                                          :decompressor)).to be true

        # Verify global factory does NOT have it (isolation)
        expect(Cabriolet.algorithm_factory.registered?(:custom_reverse,
                                                       :decompressor)).to be false

        # Use custom factory
        input_data = "Test Data"
        input_handle = Cabriolet::System::MemoryHandle.new(input_data, Cabriolet::Constants::MODE_READ)
        output_handle = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)

        decompressor = custom_factory.create(
          :custom_reverse,
          :decompressor,
          io_system,
          input_handle,
          output_handle,
          input_data.bytesize,
        )

        decompressor.decompress(input_data.bytesize, input_data.bytesize)
        output_handle.rewind
        result = output_handle.read

        expect(result).to eq(input_data.reverse)
      end

      it "demonstrates dependency injection pattern with custom factory" do
        # Create custom factory for testing
        test_factory = described_class.new(auto_register: false)
        test_factory.register(
          :test_algo,
          CustomReverseDecompressor,
          category: :decompressor,
        )

        # This demonstrates how format handlers could accept custom factories
        # (showing the pattern, even though CAB::Decompressor doesn't currently support it)
        expect(test_factory.registered?(:test_algo, :decompressor)).to be true
        expect(Cabriolet.algorithm_factory.registered?(:test_algo,
                                                       :decompressor)).to be false
      end
    end

    describe "custom compressor" do
      # Simple custom compressor that uppercases input data
      let(:custom_compressor_class) do
        Class.new(Cabriolet::Compressors::Base) do
          def compress
            # Custom compression logic - simple upcase as example
            data = @input.read
            @output.write(data.upcase)
            data.bytesize
          end
        end
      end

      before do
        stub_const("CustomUpcaseCompressor", custom_compressor_class)
      end

      it "allows registration of custom compressor" do
        Cabriolet.algorithm_factory.register(
          :custom_upcase,
          CustomUpcaseCompressor,
          category: :compressor,
        )

        input_data = "hello world"
        input_handle = Cabriolet::System::MemoryHandle.new(input_data, Cabriolet::Constants::MODE_READ)
        output_handle = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)

        compressor = Cabriolet.algorithm_factory.create(
          :custom_upcase,
          :compressor,
          io_system,
          input_handle,
          output_handle,
          input_data.bytesize,
        )

        compressor.compress
        output_handle.rewind
        result = output_handle.read

        expect(result).to eq("HELLO WORLD")

        # Cleanup
        Cabriolet.algorithm_factory.unregister(:custom_upcase, :compressor)
      end

      it "demonstrates round-trip with custom algorithms" do
        # Register both compressor and decompressor
        reverse_comp = Class.new(Cabriolet::Compressors::Base) do
          def compress
            data = @input.read
            @output.write(data.reverse)
            data.bytesize
          end
        end

        reverse_decomp = Class.new(Cabriolet::Decompressors::Base) do
          def decompress(input_size, output_size)
            data = @input.read(input_size)
            @output.write(data.reverse)
            output_size
          end
        end

        stub_const("ReverseCompressor", reverse_comp)
        stub_const("ReverseDecompressor", reverse_decomp)

        Cabriolet.algorithm_factory.register(
          :reverse,
          ReverseCompressor,
          category: :compressor,
        )
        Cabriolet.algorithm_factory.register(
          :reverse,
          ReverseDecompressor,
          category: :decompressor,
        )

        # Compress
        original = "Test Data"
        compress_input = Cabriolet::System::MemoryHandle.new(original, Cabriolet::Constants::MODE_READ)
        compress_output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)

        compressor = Cabriolet.algorithm_factory.create(
          :reverse,
          :compressor,
          io_system,
          compress_input,
          compress_output,
          original.bytesize,
        )
        compressor.compress

        # Decompress
        compress_output.rewind
        compressed_data = compress_output.read

        decompress_input = Cabriolet::System::MemoryHandle.new(compressed_data,
                                                               Cabriolet::Constants::MODE_READ)
        decompress_output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)

        decompressor = Cabriolet.algorithm_factory.create(
          :reverse,
          :decompressor,
          io_system,
          decompress_input,
          decompress_output,
          compressed_data.bytesize,
        )
        decompressor.decompress(compressed_data.bytesize, original.bytesize)

        # Verify round-trip
        decompress_output.rewind
        result = decompress_output.read
        expect(result).to eq(original)

        # Cleanup
        Cabriolet.algorithm_factory.unregister(:reverse, :compressor)
        Cabriolet.algorithm_factory.unregister(:reverse, :decompressor)
      end
    end

    describe "replacing built-in algorithms" do
      # Hypothetical optimized LZSS implementation
      let(:optimized_lzss_class) do
        Class.new(Cabriolet::Decompressors::Base) do
          def decompress(_input_size, _output_size)
            # Hypothetical optimized implementation
            @output.write("OPTIMIZED")
            9
          end
        end
      end

      before do
        stub_const("OptimizedLZSS", optimized_lzss_class)
      end

      it "allows replacing built-in algorithm with custom implementation" do
        # Save original for restoration
        original_registered = Cabriolet.algorithm_factory.registered?(:lzss,
                                                                      :decompressor)

        # Unregister built-in
        Cabriolet.algorithm_factory.unregister(:lzss, :decompressor)

        # Verify unregistered
        expect(Cabriolet.algorithm_factory.registered?(:lzss,
                                                       :decompressor)).to be false

        # Register optimized version
        Cabriolet.algorithm_factory.register(
          :lzss,
          OptimizedLZSS,
          category: :decompressor,
          priority: 10,
        )

        # Verify custom version is registered
        expect(Cabriolet.algorithm_factory.registered?(:lzss,
                                                       :decompressor)).to be true

        # Create instance and verify it's the custom class
        input_handle = Cabriolet::System::MemoryHandle.new("dummy", Cabriolet::Constants::MODE_READ)
        output_handle = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)

        decompressor = Cabriolet.algorithm_factory.create(
          :lzss,
          :decompressor,
          io_system,
          input_handle,
          output_handle,
          100,
        )

        expect(decompressor).to be_a(OptimizedLZSS)

        # Verify it uses custom implementation
        decompressor.decompress(100, 100)
        output_handle.rewind
        result = output_handle.read
        expect(result).to eq("OPTIMIZED")

        # Restore original if it was registered
        if original_registered
          Cabriolet.algorithm_factory.unregister(:lzss, :decompressor)
          Cabriolet.algorithm_factory.register(
            :lzss,
            Cabriolet::Decompressors::LZSS,
            category: :decompressor,
          )
        end
      end

      it "allows replacing with higher priority for selection" do
        # Create two versions - one optimized with higher priority
        standard = Class.new(Cabriolet::Compressors::Base) do
          def compress
            @output.write("STANDARD")
            8
          end
        end

        optimized = Class.new(Cabriolet::Compressors::Base) do
          def compress
            @output.write("OPTIMIZED")
            9
          end
        end

        stub_const("StandardAlgo", standard)
        stub_const("OptimizedAlgo", optimized)

        # Register both with different priorities
        Cabriolet.algorithm_factory.register(
          :custom_algo,
          StandardAlgo,
          category: :compressor,
          priority: 0,
        )

        Cabriolet.algorithm_factory.register(
          :custom_algo_opt,
          OptimizedAlgo,
          category: :compressor,
          priority: 10,
        )

        # Verify both are registered
        expect(Cabriolet.algorithm_factory.registered?(:custom_algo,
                                                       :compressor)).to be true
        expect(Cabriolet.algorithm_factory.registered?(:custom_algo_opt,
                                                       :compressor)).to be true

        # Check priority values
        info_standard = Cabriolet.algorithm_factory.list(:compressor)[:custom_algo]
        info_optimized = Cabriolet.algorithm_factory.list(:compressor)[:custom_algo_opt]

        expect(info_standard[:priority]).to eq(0)
        expect(info_optimized[:priority]).to eq(10)

        # Cleanup
        Cabriolet.algorithm_factory.unregister(:custom_algo, :compressor)
        Cabriolet.algorithm_factory.unregister(:custom_algo_opt, :compressor)
      end
    end

    describe "format-specific algorithm registration" do
      let(:cab_specific_algo) do
        Class.new(Cabriolet::Decompressors::Base) do
          def decompress(_input_size, _output_size)
            @output.write("CAB-SPECIFIC")
            12
          end
        end
      end

      before do
        stub_const("CABSpecificAlgo", cab_specific_algo)
      end

      it "registers algorithm only for specific format" do
        Cabriolet.algorithm_factory.register(
          :custom_cab_lzx,
          CABSpecificAlgo,
          category: :decompressor,
          format: :cab,
        )

        info = Cabriolet.algorithm_factory.list(:decompressor)[:custom_cab_lzx]
        expect(info).not_to be_nil
        expect(info[:format]).to eq(:cab)
        expect(info[:class]).to eq(CABSpecificAlgo)

        # Cleanup
        Cabriolet.algorithm_factory.unregister(:custom_cab_lzx, :decompressor)
      end

      it "supports multiple format-specific variants" do
        chm_algo = Class.new(Cabriolet::Compressors::Base) do
          def compress
            @output.write("CHM")
            3
          end
        end

        szdd_algo = Class.new(Cabriolet::Compressors::Base) do
          def compress
            @output.write("SZDD")
            4
          end
        end

        stub_const("CHMAlgo", chm_algo)
        stub_const("SZDDAlgo", szdd_algo)

        # Register format-specific variants
        Cabriolet.algorithm_factory.register(
          :custom_format_algo,
          CABSpecificAlgo,
          category: :decompressor,
          format: :cab,
        )

        Cabriolet.algorithm_factory.register(
          :custom_format_algo_chm,
          CHMAlgo,
          category: :compressor,
          format: :chm,
        )

        Cabriolet.algorithm_factory.register(
          :custom_format_algo_szdd,
          SZDDAlgo,
          category: :compressor,
          format: :szdd,
        )

        # Verify all are registered with correct format
        cab_info = Cabriolet.algorithm_factory.list(:decompressor)[:custom_format_algo]
        chm_info = Cabriolet.algorithm_factory.list(:compressor)[:custom_format_algo_chm]
        szdd_info = Cabriolet.algorithm_factory.list(:compressor)[:custom_format_algo_szdd]

        expect(cab_info[:format]).to eq(:cab)
        expect(chm_info[:format]).to eq(:chm)
        expect(szdd_info[:format]).to eq(:szdd)

        # Cleanup
        Cabriolet.algorithm_factory.unregister(:custom_format_algo,
                                               :decompressor)
        Cabriolet.algorithm_factory.unregister(:custom_format_algo_chm,
                                               :compressor)
        Cabriolet.algorithm_factory.unregister(:custom_format_algo_szdd,
                                               :compressor)
      end
    end

    describe "real-world usage patterns" do
      it "supports creating isolated test environments" do
        # Create separate factory for testing without affecting global state
        test_factory = described_class.new(auto_register: false)

        # Register only what's needed for the test
        test_algo = Class.new(Cabriolet::Compressors::Base) do
          def compress
            @output.write("TEST")
            4
          end
        end
        stub_const("TestAlgo", test_algo)

        test_factory.register(:test, TestAlgo, category: :compressor)

        # Verify isolation
        expect(test_factory.registered?(:test, :compressor)).to be true
        expect(Cabriolet.algorithm_factory.registered?(:test,
                                                       :compressor)).to be false

        # Global factory still has all built-in algorithms
        expect(Cabriolet.algorithm_factory.registered?(:mszip,
                                                       :compressor)).to be true
        expect(test_factory.registered?(:mszip, :compressor)).to be false
      end

      it "supports algorithm experimentation and benchmarking" do
        # Register multiple implementations for benchmarking
        impl1 = Class.new(Cabriolet::Compressors::Base) do
          def compress
            @output.write("IMPL1")
            5
          end
        end

        impl2 = Class.new(Cabriolet::Compressors::Base) do
          def compress
            @output.write("IMPL2-OPTIMIZED")
            15
          end
        end

        stub_const("Implementation1", impl1)
        stub_const("Implementation2", impl2)

        benchmark_factory = described_class.new(auto_register: false)
        benchmark_factory.register(:impl1, Implementation1,
                                   category: :compressor)
        benchmark_factory.register(:impl2, Implementation2,
                                   category: :compressor)

        # Both implementations are available for comparison
        expect(benchmark_factory.list(:compressor).keys).to contain_exactly(
          :impl1, :impl2
        )

        # Can create instances of each for benchmarking
        input = Cabriolet::System::MemoryHandle.new("test", Cabriolet::Constants::MODE_READ)
        output1 = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        output2 = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)

        comp1 = benchmark_factory.create(:impl1, :compressor, io_system, input,
                                         output1, 4)
        input.rewind
        comp2 = benchmark_factory.create(:impl2, :compressor, io_system, input,
                                         output2, 4)

        expect(comp1).to be_a(Implementation1)
        expect(comp2).to be_a(Implementation2)
      end
    end
  end
end
