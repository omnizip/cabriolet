# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::Compressors::LZSS do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:buffer_size) { 4096 }

  describe "#compress" do
    context "with simple literal data" do
      it "compresses and decompresses data with no matches" do
        original_data = "abcdefghij"

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original_data)
        output = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(
          io_system,
          input,
          output,
          buffer_size,
        )
        compressed_size = compressor.compress

        expect(compressed_size).to be > 0

        # Decompress
        compressed_data = output.data
        compressed_input = Cabriolet::System::MemoryHandle.new(
          compressed_data,
        )
        result = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::LZSS.new(
          io_system,
          compressed_input,
          result,
          buffer_size,
        )
        decompressor.decompress(original_data.bytesize)

        expect(result.data).to eq(original_data)
      end
    end

    context "with repetitive data" do
      it "compresses and decompresses repeated sequences" do
        original_data = "aaaaaaaaaa" * 10

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original_data)
        output = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(
          io_system,
          input,
          output,
          buffer_size,
        )
        compressed_size = compressor.compress

        # Should compress well due to repetition
        expect(compressed_size).to be < original_data.bytesize

        # Decompress
        compressed_data = output.data
        compressed_input = Cabriolet::System::MemoryHandle.new(
          compressed_data,
        )
        result = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::LZSS.new(
          io_system,
          compressed_input,
          result,
          buffer_size,
        )
        decompressor.decompress(original_data.bytesize)

        expect(result.data).to eq(original_data)
      end

      it "compresses and decompresses a pattern" do
        original_data = "ABCABC" * 20

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original_data)
        output = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(
          io_system,
          input,
          output,
          buffer_size,
        )
        compressed_size = compressor.compress

        # Should compress well due to pattern
        expect(compressed_size).to be < original_data.bytesize

        # Decompress
        compressed_data = output.data
        compressed_input = Cabriolet::System::MemoryHandle.new(
          compressed_data,
        )
        result = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::LZSS.new(
          io_system,
          compressed_input,
          result,
          buffer_size,
        )
        decompressor.decompress(original_data.bytesize)

        expect(result.data).to eq(original_data)
      end
    end

    context "with mixed data" do
      it "compresses and decompresses mixed literal and match data" do
        original_data = "Hello World! Hello World! This is a test."

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original_data)
        output = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(
          io_system,
          input,
          output,
          buffer_size,
        )
        compressed_size = compressor.compress

        expect(compressed_size).to be > 0

        # Decompress
        compressed_data = output.data
        compressed_input = Cabriolet::System::MemoryHandle.new(
          compressed_data,
        )
        result = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::LZSS.new(
          io_system,
          compressed_input,
          result,
          buffer_size,
        )
        decompressor.decompress(original_data.bytesize)

        expect(result.data).to eq(original_data)
      end
    end

    context "with edge cases" do
      it "compresses and decompresses empty data" do
        original_data = ""

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original_data)
        output = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(
          io_system,
          input,
          output,
          buffer_size,
        )
        compressed_size = compressor.compress

        expect(compressed_size).to eq(0)

        # Decompress
        compressed_data = output.data
        compressed_input = Cabriolet::System::MemoryHandle.new(
          compressed_data,
        )
        result = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::LZSS.new(
          io_system,
          compressed_input,
          result,
          buffer_size,
        )
        decompressor.decompress(0)

        expect(result.data).to eq("")
      end

      it "compresses and decompresses single byte" do
        original_data = "A"

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original_data)
        output = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(
          io_system,
          input,
          output,
          buffer_size,
        )
        compressed_size = compressor.compress

        expect(compressed_size).to be > 0

        # Decompress
        compressed_data = output.data
        compressed_input = Cabriolet::System::MemoryHandle.new(
          compressed_data,
        )
        result = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::LZSS.new(
          io_system,
          compressed_input,
          result,
          buffer_size,
        )
        decompressor.decompress(original_data.bytesize)

        expect(result.data).to eq(original_data)
      end

      it "compresses and decompresses data exactly MIN_MATCH length" do
        original_data = "ABCABC"

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original_data)
        output = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(
          io_system,
          input,
          output,
          buffer_size,
        )
        compressed_size = compressor.compress

        expect(compressed_size).to be > 0

        # Decompress
        compressed_data = output.data
        compressed_input = Cabriolet::System::MemoryHandle.new(
          compressed_data,
        )
        result = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::LZSS.new(
          io_system,
          compressed_input,
          result,
          buffer_size,
        )
        decompressor.decompress(original_data.bytesize)

        expect(result.data).to eq(original_data)
      end
    end

    context "with large data" do
      it "compresses and decompresses data larger than window size" do
        # Create data larger than WINDOW_SIZE (4096 bytes)
        original_data = "ABCDEFGHIJ" * 500 # 5000 bytes

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original_data)
        output = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(
          io_system,
          input,
          output,
          buffer_size,
        )
        compressed_size = compressor.compress

        expect(compressed_size).to be > 0
        # Should compress well due to repetition
        expect(compressed_size).to be < original_data.bytesize

        # Decompress
        compressed_data = output.data
        compressed_input = Cabriolet::System::MemoryHandle.new(
          compressed_data,
        )
        result = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::LZSS.new(
          io_system,
          compressed_input,
          result,
          buffer_size,
        )
        decompressor.decompress(original_data.bytesize)

        expect(result.data).to eq(original_data)
      end
    end

    context "with different modes" do
      it "compresses and decompresses with MODE_EXPAND" do
        original_data = "Test data with MODE_EXPAND"

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original_data)
        output = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(
          io_system,
          input,
          output,
          buffer_size,
          Cabriolet::Compressors::LZSS::MODE_EXPAND,
        )
        compressed_size = compressor.compress

        expect(compressed_size).to be > 0

        # Decompress
        compressed_data = output.data
        compressed_input = Cabriolet::System::MemoryHandle.new(
          compressed_data,
        )
        result = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::LZSS.new(
          io_system,
          compressed_input,
          result,
          buffer_size,
          Cabriolet::Decompressors::LZSS::MODE_EXPAND,
        )
        decompressor.decompress(original_data.bytesize)

        expect(result.data).to eq(original_data)
      end

      it "compresses and decompresses with MODE_MSHELP" do
        original_data = "Test data with MODE_MSHELP"

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original_data)
        output = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(
          io_system,
          input,
          output,
          buffer_size,
          Cabriolet::Compressors::LZSS::MODE_MSHELP,
        )
        compressed_size = compressor.compress

        expect(compressed_size).to be > 0

        # Decompress
        compressed_data = output.data
        compressed_input = Cabriolet::System::MemoryHandle.new(
          compressed_data,
        )
        result = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::LZSS.new(
          io_system,
          compressed_input,
          result,
          buffer_size,
          Cabriolet::Decompressors::LZSS::MODE_MSHELP,
        )
        decompressor.decompress(original_data.bytesize)

        expect(result.data).to eq(original_data)
      end

      it "compresses and decompresses with MODE_QBASIC" do
        original_data = "Test data with MODE_QBASIC"

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original_data)
        output = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(
          io_system,
          input,
          output,
          buffer_size,
          Cabriolet::Compressors::LZSS::MODE_QBASIC,
        )
        compressed_size = compressor.compress

        expect(compressed_size).to be > 0

        # Decompress
        compressed_data = output.data
        compressed_input = Cabriolet::System::MemoryHandle.new(
          compressed_data,
        )
        result = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::LZSS.new(
          io_system,
          compressed_input,
          result,
          buffer_size,
          Cabriolet::Decompressors::LZSS::MODE_QBASIC,
        )
        decompressor.decompress(original_data.bytesize)

        expect(result.data).to eq(original_data)
      end
    end

    context "with binary data" do
      it "compresses and decompresses binary data" do
        original_data = [0x00, 0xFF, 0x01, 0xFE, 0x02, 0xFD] * 20
        original_data = original_data.pack("C*")

        # Compress
        input = Cabriolet::System::MemoryHandle.new(original_data)
        output = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)
        compressor = described_class.new(
          io_system,
          input,
          output,
          buffer_size,
        )
        compressed_size = compressor.compress

        expect(compressed_size).to be > 0

        # Decompress
        compressed_data = output.data
        compressed_input = Cabriolet::System::MemoryHandle.new(
          compressed_data,
        )
        result = Cabriolet::System::MemoryHandle.new("",
                                                     Cabriolet::Constants::MODE_WRITE)
        decompressor = Cabriolet::Decompressors::LZSS.new(
          io_system,
          compressed_input,
          result,
          buffer_size,
        )
        decompressor.decompress(original_data.bytesize)

        expect(result.data).to eq(original_data)
      end
    end
  end

  describe "compression efficiency" do
    it "compresses highly repetitive data better than random data" do
      repetitive_data = "A" * 1000
      random_data = (0...1000).map { rand(256) }.pack("C*")

      # Compress repetitive
      input1 = Cabriolet::System::MemoryHandle.new(repetitive_data)
      output1 = Cabriolet::System::MemoryHandle.new("",
                                                    Cabriolet::Constants::MODE_WRITE)
      compressor1 = described_class.new(io_system, input1, output1,
                                        buffer_size)
      rep_size = compressor1.compress

      # Compress random
      input2 = Cabriolet::System::MemoryHandle.new(random_data)
      output2 = Cabriolet::System::MemoryHandle.new("",
                                                    Cabriolet::Constants::MODE_WRITE)
      compressor2 = described_class.new(io_system, input2, output2,
                                        buffer_size)
      rand_size = compressor2.compress

      # Repetitive should compress much better
      expect(rep_size).to be < rand_size
    end
  end
end
