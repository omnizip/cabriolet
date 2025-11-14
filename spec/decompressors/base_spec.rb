# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::Decompressors::Base do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:input_data) { "test input data" }
  let(:input_handle) { Cabriolet::System::MemoryHandle.new(input_data) }
  let(:output_handle) { Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE) }
  let(:buffer_size) { 1024 }

  subject(:decompressor) do
    described_class.new(io_system, input_handle, output_handle, buffer_size)
  end

  describe "#initialize" do
    it "initializes with all required parameters" do
      expect(decompressor.io_system).to eq(io_system)
      expect(decompressor.input).to eq(input_handle)
      expect(decompressor.output).to eq(output_handle)
      expect(decompressor.buffer_size).to eq(buffer_size)
    end

    it "stores io_system" do
      expect(decompressor.io_system).to be_a(Cabriolet::System::IOSystem)
    end

    it "stores input handle" do
      expect(decompressor.input).to be_a(Cabriolet::System::MemoryHandle)
    end

    it "stores output handle" do
      expect(decompressor.output).to be_a(Cabriolet::System::MemoryHandle)
    end

    it "stores buffer_size" do
      expect(decompressor.buffer_size).to eq(1024)
    end
  end

  describe "#decompress" do
    it "raises NotImplementedError" do
      expect do
        decompressor.decompress(100)
      end.to raise_error(NotImplementedError, /must implement #decompress/)
    end

    it "includes class name in error message" do
      expect do
        decompressor.decompress(100)
      end.to raise_error(NotImplementedError, /Cabriolet::Decompressors::Base/)
    end
  end

  describe "#free" do
    it "does not raise error when called" do
      expect { decompressor.free }.not_to raise_error
    end

    it "returns nil" do
      expect(decompressor.free).to be_nil
    end

    it "can be called multiple times" do
      decompressor.free
      expect { decompressor.free }.not_to raise_error
    end
  end

  describe "attribute readers" do
    it "provides read access to io_system" do
      expect(decompressor).to respond_to(:io_system)
      expect(decompressor).not_to respond_to(:io_system=)
    end

    it "provides read access to input" do
      expect(decompressor).to respond_to(:input)
      expect(decompressor).not_to respond_to(:input=)
    end

    it "provides read access to output" do
      expect(decompressor).to respond_to(:output)
      expect(decompressor).not_to respond_to(:output=)
    end

    it "provides read access to buffer_size" do
      expect(decompressor).to respond_to(:buffer_size)
      expect(decompressor).not_to respond_to(:buffer_size=)
    end
  end

  describe "subclass implementation" do
    let(:test_decompressor_class) do
      Class.new(described_class) do
        def decompress(bytes)
          # Simple implementation that just copies data
          total = 0
          while total < bytes
            chunk_size = [bytes - total, @buffer_size].min
            data = @io_system.read(@input, chunk_size)
            break if data.empty?

            @io_system.write(@output, data)
            total += data.bytesize
          end
          total
        end
      end
    end

    it "can be subclassed and implement decompress" do
      subclass_instance = test_decompressor_class.new(
        io_system,
        input_handle,
        output_handle,
        buffer_size,
      )

      bytes_decompressed = subclass_instance.decompress(10)
      expect(bytes_decompressed).to eq(10)
      expect(output_handle.data).to eq(input_data[0, 10])
    end

    it "inherits all attributes from base" do
      subclass_instance = test_decompressor_class.new(
        io_system,
        input_handle,
        output_handle,
        buffer_size,
      )

      expect(subclass_instance.io_system).to eq(io_system)
      expect(subclass_instance.input).to eq(input_handle)
      expect(subclass_instance.output).to eq(output_handle)
      expect(subclass_instance.buffer_size).to eq(buffer_size)
    end
  end

  describe "integration with handles" do
    it "works with file handles" do
      Dir.mktmpdir do |dir|
        input_file = File.join(dir, "input.dat")
        output_file = File.join(dir, "output.dat")

        File.write(input_file, "test data")

        file_input = Cabriolet::System::FileHandle.new(
          input_file,
          Cabriolet::Constants::MODE_READ,
        )
        file_output = Cabriolet::System::FileHandle.new(
          output_file,
          Cabriolet::Constants::MODE_WRITE,
        )

        file_decompressor = described_class.new(
          io_system,
          file_input,
          file_output,
          1024,
        )

        expect(file_decompressor.input).to eq(file_input)
        expect(file_decompressor.output).to eq(file_output)

        file_input.close
        file_output.close
      end
    end

    it "works with memory handles" do
      mem_decompressor = described_class.new(
        io_system,
        input_handle,
        output_handle,
        512,
      )

      expect(mem_decompressor.input).to be_a(Cabriolet::System::MemoryHandle)
      expect(mem_decompressor.output).to be_a(Cabriolet::System::MemoryHandle)
    end
  end
end
