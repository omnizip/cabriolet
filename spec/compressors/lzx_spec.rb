# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::Compressors::LZX do
  let(:io) { Cabriolet::System::IOSystem.new }

  describe "#compress" do
    context "with simple data" do
      it "compresses and decompresses a short string" do
        original = "Hello, World!"

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original)
        output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(io, input, output, 4096,
                                         window_bits: 15)
        compressor.compress

        # Decompress
        compressed_data = output.data
        compressed = Cabriolet::System::MemoryHandle.new(compressed_data)
        result = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::LZX.new(
          io, compressed, result, 4096,
          window_bits: 15, output_length: original.bytesize
        )
        decompressor.decompress(original.bytesize)

        expect(result.data).to eq(original)
      end

      it "compresses and decompresses empty data" do
        original = ""

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original)
        output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(io, input, output, 4096,
                                         window_bits: 15)
        bytes_compressed = compressor.compress

        expect(bytes_compressed).to eq(0)
      end
    end

    context "with repetitive data" do
      it "compresses and decompresses repetitive patterns" do
        original = "Test " * 100

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original)
        output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(io, input, output, 4096,
                                         window_bits: 15)
        compressor.compress

        # Decompress
        compressed_data = output.data
        compressed = Cabriolet::System::MemoryHandle.new(compressed_data)
        result = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::LZX.new(
          io, compressed, result, 4096,
          window_bits: 15, output_length: original.bytesize
        )
        decompressor.decompress(original.bytesize)

        expect(result.data).to eq(original)
      end

      it "compresses and decompresses long repetitive data" do
        original = "ABCDEFGH" * 1000

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original)
        output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(io, input, output, 4096,
                                         window_bits: 15)
        compressor.compress

        # Decompress
        compressed_data = output.data
        compressed = Cabriolet::System::MemoryHandle.new(compressed_data)
        result = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::LZX.new(
          io, compressed, result, 4096,
          window_bits: 15, output_length: original.bytesize
        )
        decompressor.decompress(original.bytesize)

        expect(result.data).to eq(original)
      end
    end

    context "with various data sizes" do
      it "compresses and decompresses data smaller than frame size" do
        original = "a" * 1000

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original)
        output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(io, input, output, 4096,
                                         window_bits: 15)
        compressor.compress

        # Decompress
        compressed_data = output.data
        compressed = Cabriolet::System::MemoryHandle.new(compressed_data)
        result = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::LZX.new(
          io, compressed, result, 4096,
          window_bits: 15, output_length: original.bytesize
        )
        decompressor.decompress(original.bytesize)

        expect(result.data).to eq(original)
      end

      it "compresses and decompresses data exactly one frame size" do
        original = "X" * 32_768

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original)
        output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(io, input, output, 4096,
                                         window_bits: 15)
        compressor.compress

        # Decompress
        compressed_data = output.data
        compressed = Cabriolet::System::MemoryHandle.new(compressed_data)
        result = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::LZX.new(
          io, compressed, result, 4096,
          window_bits: 15, output_length: original.bytesize
        )
        decompressor.decompress(original.bytesize)

        expect(result.data).to eq(original)
      end

      it "compresses and decompresses data spanning multiple frames" do
        original = "MultiFrame" * 10_000

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original)
        output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(io, input, output, 4096,
                                         window_bits: 15)
        compressor.compress

        # Decompress
        compressed_data = output.data
        compressed = Cabriolet::System::MemoryHandle.new(compressed_data)
        result = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::LZX.new(
          io, compressed, result, 4096,
          window_bits: 15, output_length: original.bytesize
        )
        decompressor.decompress(original.bytesize)

        expect(result.data).to eq(original)
      end
    end

    context "with different window sizes" do
      [15, 16, 17, 18, 19, 20, 21].each do |bits|
        it "compresses and decompresses with #{bits}-bit window" do
          original = "WindowTest_#{bits}" * 500

          # Compress
          input = Cabriolet::System::MemoryHandle.new(original)
          output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
          compressor = described_class.new(io, input, output, 4096,
                                           window_bits: bits)
          compressor.compress

          # Decompress
          compressed_data = output.data
          compressed = Cabriolet::System::MemoryHandle.new(compressed_data)
          result = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
          decompressor = Cabriolet::Decompressors::LZX.new(
            io, compressed, result, 4096,
            window_bits: bits, output_length: original.bytesize
          )
          decompressor.decompress(original.bytesize)

          expect(result.data).to eq(original)
        end
      end
    end

    context "with mixed content" do
      it "compresses and decompresses text with various patterns" do
        original = <<~TEXT
          The quick brown fox jumps over the lazy dog.
          The quick brown fox jumps over the lazy dog.
          1234567890 ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz
          Repetition: #{'ABC' * 100}
          Random: #{'x' * 500}
        TEXT

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original)
        output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(io, input, output, 4096,
                                         window_bits: 15)
        compressor.compress

        # Decompress
        compressed_data = output.data
        compressed = Cabriolet::System::MemoryHandle.new(compressed_data)
        result = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::LZX.new(
          io, compressed, result, 4096,
          window_bits: 15, output_length: original.bytesize
        )
        decompressor.decompress(original.bytesize)

        expect(result.data).to eq(original)
      end

      it "compresses and decompresses binary-like data" do
        # Create binary-like pattern
        original = (0..255).to_a.pack("C*") * 100

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original)
        output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(io, input, output, 4096,
                                         window_bits: 15)
        compressor.compress

        # Decompress
        compressed_data = output.data
        compressed = Cabriolet::System::MemoryHandle.new(compressed_data)
        result = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::LZX.new(
          io, compressed, result, 4096,
          window_bits: 15, output_length: original.bytesize
        )
        decompressor.decompress(original.bytesize)

        expect(result.data).to eq(original)
      end
    end

    context "with edge cases" do
      it "handles single byte" do
        original = "A"

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original)
        output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(io, input, output, 4096,
                                         window_bits: 15)
        compressor.compress

        # Decompress
        compressed_data = output.data
        compressed = Cabriolet::System::MemoryHandle.new(compressed_data)
        result = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::LZX.new(
          io, compressed, result, 4096,
          window_bits: 15, output_length: original.bytesize
        )
        decompressor.decompress(original.bytesize)

        expect(result.data).to eq(original)
      end

      it "handles all same bytes" do
        original = "Z" * 5000

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original)
        output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(io, input, output, 4096,
                                         window_bits: 15)
        compressor.compress

        # Decompress
        compressed_data = output.data
        compressed = Cabriolet::System::MemoryHandle.new(compressed_data)
        result = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::LZX.new(
          io, compressed, result, 4096,
          window_bits: 15, output_length: original.bytesize
        )
        decompressor.decompress(original.bytesize)

        expect(result.data).to eq(original)
      end
    end

    context "validation" do
      it "validates window_bits parameter" do
        input = Cabriolet::System::MemoryHandle.new("test")
        output = Cabriolet::System::MemoryHandle.new

        expect do
          described_class.new(io, input, output, 4096, window_bits: 14)
        end.to raise_error(ArgumentError, /window_bits must be 15-21/)

        expect do
          described_class.new(io, input, output, 4096, window_bits: 22)
        end.to raise_error(ArgumentError, /window_bits must be 15-21/)
      end
    end
  end

  describe "compression effectiveness" do
    it "achieves compression on highly repetitive data",
       skip: "Waiting on LZX VERBATIM/ALIGNED block implementation for actual compression" do
      original = "REPEAT" * 5000

      # Compress
      input = Cabriolet::System::MemoryHandle.new(original)
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
      compressor = described_class.new(io, input, output, 4096, window_bits: 15)
      compressor.compress

      compressed_size = output.data.bytesize
      original_size = original.bytesize

      # Should achieve significant compression
      expect(compressed_size).to be < original_size
      compression_ratio = (compressed_size.to_f / original_size) * 100
      puts "Compression ratio for repetitive data: #{compression_ratio.round(2)}%"
    end
  end
end
