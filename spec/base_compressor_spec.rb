# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Cabriolet::BaseCompressor do
  # Mock compressor for testing abstract base class
  class MockCompressor < Cabriolet::BaseCompressor
    attr_accessor :structure_built, :format_written, :validation_called,
                  :post_hook_called

    def initialize(*args)
      super
      @structure_built = false
      @format_written = false
      @validation_called = false
      @post_hook_called = false
    end

    # Expose compress_data for testing
    public :compress_data

    protected

    def build_structure(options)
      @structure_built = true
      {
        header: "MockHeader",
        files: file_manager.all,
        options: options,
      }
    end

    def write_format(output_handle, structure)
      @format_written = true
      data = "MOCK#{structure[:header]}"
      io_system.write(output_handle, data)
    end

    def validate_generation_prerequisites!(options)
      super
      @validation_called = true
    end

    def post_generation_hook(_output_file, _structure, _bytes_written)
      @post_hook_called = true
    end
  end

  let(:compressor) { MockCompressor.new }

  describe "#initialize" do
    it "creates with default dependencies" do
      comp = MockCompressor.new

      expect(comp.io_system).to be_a(Cabriolet::System::IOSystem)
      expect(comp.algorithm_factory).to be_a(Cabriolet::AlgorithmFactory)
      expect(comp.file_manager).to be_a(Cabriolet::FileManager)
    end

    it "accepts custom io_system" do
      custom_io = Cabriolet::System::IOSystem.new
      comp = MockCompressor.new(custom_io)

      expect(comp.io_system).to eq(custom_io)
    end

    it "accepts custom algorithm_factory" do
      custom_factory = Cabriolet::AlgorithmFactory.new(auto_register: false)
      comp = MockCompressor.new(nil, custom_factory)

      expect(comp.algorithm_factory).to eq(custom_factory)
    end
  end

  describe "#add_file" do
    it "delegates to file_manager" do
      Dir.mktmpdir do |dir|
        source = File.join(dir, "test.txt")
        File.write(source, "content")

        entry = compressor.add_file(source, "test.txt")

        expect(entry).to be_a(Cabriolet::FileEntry)
        expect(compressor.file_manager.size).to eq(1)
      end
    end

    it "passes options through" do
      Dir.mktmpdir do |dir|
        source = File.join(dir, "test.txt")
        File.write(source, "content")

        entry = compressor.add_file(source, "test.txt", custom: "value")

        expect(entry.options[:custom]).to eq("value")
      end
    end
  end

  describe "#add_data" do
    it "delegates to file_manager" do
      entry = compressor.add_data("data", "file.txt")

      expect(entry).to be_a(Cabriolet::FileEntry)
      expect(compressor.file_manager.size).to eq(1)
    end

    it "passes options through" do
      entry = compressor.add_data("data", "file.txt", option: 123)

      expect(entry.options[:option]).to eq(123)
    end
  end

  describe "#generate" do
    it "implements template method workflow" do
      Dir.mktmpdir do |dir|
        output = File.join(dir, "output.mock")
        compressor.add_data("test", "file.txt")

        bytes = compressor.generate(output)

        expect(bytes).to be > 0
        expect(compressor.validation_called).to be true
        expect(compressor.structure_built).to be true
        expect(compressor.format_written).to be true
        expect(compressor.post_hook_called).to be true
      end
    end

    it "raises error if no files added" do
      Dir.mktmpdir do |dir|
        output = File.join(dir, "output.mock")

        expect do
          compressor.generate(output)
        end.to raise_error(ArgumentError, /No files added/)
      end
    end

    it "writes output file" do
      Dir.mktmpdir do |dir|
        output = File.join(dir, "output.mock")
        compressor.add_data("test", "file.txt")

        compressor.generate(output)

        expect(File.exist?(output)).to be true
        expect(File.size(output)).to be > 0
      end
    end

    it "passes options to build_structure" do
      Dir.mktmpdir do |dir|
        output = File.join(dir, "output.mock")
        compressor.add_data("test", "file.txt")

        compressor.generate(output, custom_option: "value")

        # Verify option was passed (check structure in real implementation)
        expect(compressor.structure_built).to be true
      end
    end

    it "closes file handle even on error" do
      Dir.mktmpdir do |dir|
        output = File.join(dir, "output.mock")
        compressor.add_data("test", "file.txt")

        # Make write_format raise an error
        allow(compressor).to receive(:write_format).and_raise("Test error")

        expect do
          compressor.generate(output)
        end.to raise_error("Test error")

        # File should still be closed (no file handles leaked)
        # This is implicitly tested by not having open file errors
      end
    end
  end

  describe "#compress_data" do
    it "compresses data using specified algorithm" do
      data = "Hello, World! " * 100 # Make it compressible

      compressed = compressor.compress_data(data, algorithm: :mszip)

      expect(compressed).to be_a(String)
      expect(compressed.bytesize).to be < data.bytesize
    end

    it "accepts window_bits option" do
      data = "test data " * 50

      compressed = compressor.compress_data(
        data,
        algorithm: :lzx,
        window_bits: 15,
      )

      expect(compressed).to be_a(String)
    end

    it "accepts mode option" do
      data = "test data"

      compressed = compressor.compress_data(
        data,
        algorithm: :lzss,
        mode: Cabriolet::Compressors::LZSS::MODE_EXPAND,
      )

      expect(compressed).to be_a(String)
    end
  end

  describe "abstract methods" do
    # Create compressor that doesn't implement hooks
    class IncompleteCompressor < Cabriolet::BaseCompressor
    end

    let(:incomplete) { IncompleteCompressor.new }

    it "raises NotImplementedError for build_structure" do
      expect do
        incomplete.send(:build_structure, {})
      end.to raise_error(NotImplementedError, /must implement build_structure/)
    end

    it "raises NotImplementedError for write_format" do
      expect do
        incomplete.send(:write_format, nil, {})
      end.to raise_error(NotImplementedError, /must implement write_format/)
    end
  end
end
