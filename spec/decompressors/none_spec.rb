# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::Decompressors::None do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:buffer_size) { 1024 }

  describe "#initialize" do
    it "inherits from Base" do
      expect(described_class.ancestors).to include(Cabriolet::Decompressors::Base)
    end

    it "initializes with all parameters" do
      input = Cabriolet::System::MemoryHandle.new("test")
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)

      decompressor = described_class.new(io_system, input, output, buffer_size)

      expect(decompressor.io_system).to eq(io_system)
      expect(decompressor.input).to eq(input)
      expect(decompressor.output).to eq(output)
      expect(decompressor.buffer_size).to eq(buffer_size)
    end
  end

  describe "#decompress" do
    let(:input_data) { "Hello, World! This is test data for decompression." }
    let(:input_handle) { Cabriolet::System::MemoryHandle.new(input_data) }
    let(:output_handle) { Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE) }
    let(:decompressor) do
      described_class.new(io_system, input_handle, output_handle, buffer_size)
    end

    it "copies exact number of bytes requested" do
      bytes_copied = decompressor.decompress(10)
      expect(bytes_copied).to eq(10)
      expect(output_handle.data).to eq("Hello, Wor")
    end

    it "copies all data when bytes requested exceeds available" do
      bytes_copied = decompressor.decompress(1000)
      expect(bytes_copied).to eq(input_data.bytesize)
      expect(output_handle.data).to eq(input_data)
    end

    it "copies data in chunks according to buffer size" do
      small_buffer_decompressor = described_class.new(
        io_system,
        input_handle,
        output_handle,
        8,
      )

      bytes_copied = small_buffer_decompressor.decompress(20)
      expect(bytes_copied).to eq(20)
      expect(output_handle.data).to eq(input_data[0, 20])
    end

    it "handles sequential decompress calls" do
      decompressor.decompress(10)
      decompressor.decompress(10)
      expect(output_handle.data).to eq(input_data[0, 20])
    end

    it "returns 0 when no data available" do
      empty_input = Cabriolet::System::MemoryHandle.new("")
      empty_decompressor = described_class.new(
        io_system,
        empty_input,
        output_handle,
        buffer_size,
      )

      bytes_copied = empty_decompressor.decompress(100)
      expect(bytes_copied).to eq(0)
    end

    it "stops at EOF even if more bytes requested" do
      bytes_copied = decompressor.decompress(input_data.bytesize + 100)
      expect(bytes_copied).to eq(input_data.bytesize)
      expect(output_handle.data).to eq(input_data)
    end

    it "preserves binary data exactly" do
      binary_data = "\x00\x01\x02\xFF\xFE\xFD".b
      binary_input = Cabriolet::System::MemoryHandle.new(binary_data)
      binary_output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
      binary_decompressor = described_class.new(
        io_system,
        binary_input,
        binary_output,
        buffer_size,
      )

      binary_decompressor.decompress(binary_data.bytesize)
      expect(binary_output.data).to eq(binary_data)
    end
  end

  describe "partial decompression" do
    let(:input_data) { "0123456789" * 10 } # 100 bytes
    let(:input_handle) { Cabriolet::System::MemoryHandle.new(input_data) }
    let(:output_handle) { Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE) }
    let(:decompressor) do
      described_class.new(io_system, input_handle, output_handle, 32)
    end

    it "decompresses data in multiple calls" do
      # First call
      bytes1 = decompressor.decompress(30)
      expect(bytes1).to eq(30)

      # Second call
      bytes2 = decompressor.decompress(30)
      expect(bytes2).to eq(30)

      # Third call
      bytes3 = decompressor.decompress(40)
      expect(bytes3).to eq(40)

      expect(output_handle.data.bytesize).to eq(100)
      expect(output_handle.data).to eq(input_data)
    end

    it "handles exact buffer-sized chunks" do
      chunk_size = 32
      total = 0

      3.times do
        bytes = decompressor.decompress(chunk_size)
        total += bytes
        expect(bytes).to eq(chunk_size)
      end

      expect(total).to eq(96)
    end
  end

  describe "buffer size variations" do
    let(:input_data) { "A" * 1000 }
    let(:input_handle) { Cabriolet::System::MemoryHandle.new(input_data) }
    let(:output_handle) { Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE) }

    it "works with very small buffer" do
      small_decompressor = described_class.new(io_system, input_handle,
                                               output_handle, 1)
      bytes = small_decompressor.decompress(100)
      expect(bytes).to eq(100)
      expect(output_handle.data).to eq("A" * 100)
    end

    it "works with large buffer" do
      large_decompressor = described_class.new(io_system, input_handle,
                                               output_handle, 10_000)
      bytes = large_decompressor.decompress(500)
      expect(bytes).to eq(500)
      expect(output_handle.data).to eq("A" * 500)
    end

    it "works with buffer size equal to data size" do
      equal_decompressor = described_class.new(io_system, input_handle,
                                               output_handle, 1000)
      bytes = equal_decompressor.decompress(1000)
      expect(bytes).to eq(1000)
      expect(output_handle.data).to eq(input_data)
    end
  end

  describe "EOF handling" do
    let(:input_data) { "Short" }
    let(:input_handle) { Cabriolet::System::MemoryHandle.new(input_data) }
    let(:output_handle) { Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE) }
    let(:decompressor) do
      described_class.new(io_system, input_handle, output_handle, buffer_size)
    end

    it "handles EOF gracefully" do
      bytes = decompressor.decompress(100)
      expect(bytes).to eq(5) # Only 5 bytes available
      expect(output_handle.data).to eq("Short")
    end

    it "returns 0 on subsequent calls after EOF" do
      decompressor.decompress(100)
      bytes = decompressor.decompress(10)
      expect(bytes).to eq(0)
    end
  end

  describe "integration with file handles" do
    it "works with file input and output" do
      Dir.mktmpdir do |dir|
        input_file = File.join(dir, "input.dat")
        output_file = File.join(dir, "output.dat")

        test_data = "Test file data for decompression"
        File.write(input_file, test_data)

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

        bytes = file_decompressor.decompress(test_data.bytesize)
        expect(bytes).to eq(test_data.bytesize)

        file_input.close
        file_output.close

        expect(File.read(output_file)).to eq(test_data)
      end
    end
  end

  describe "edge cases" do
    it "handles zero-byte decompress request" do
      input = Cabriolet::System::MemoryHandle.new("test")
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
      decompressor = described_class.new(io_system, input, output, buffer_size)

      bytes = decompressor.decompress(0)
      expect(bytes).to eq(0)
      expect(output.data).to eq("")
    end

    it "handles single byte request" do
      input = Cabriolet::System::MemoryHandle.new("test")
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
      decompressor = described_class.new(io_system, input, output, buffer_size)

      bytes = decompressor.decompress(1)
      expect(bytes).to eq(1)
      expect(output.data).to eq("t")
    end

    it "handles large single request" do
      large_data = "X" * 100_000
      input = Cabriolet::System::MemoryHandle.new(large_data)
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
      decompressor = described_class.new(io_system, input, output, 1024)

      bytes = decompressor.decompress(100_000)
      expect(bytes).to eq(100_000)
      expect(output.data).to eq(large_data)
    end
  end
end
