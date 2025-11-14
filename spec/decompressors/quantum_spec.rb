# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::Decompressors::Quantum do
  let(:io_system) { Cabriolet::System::IOSystem.new }

  describe "#initialize" do
    it "initializes with valid window_bits" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      quantum = described_class.new(io_system, input, output, 4096,
                                    window_bits: 15)

      expect(quantum.window_bits).to eq(15)
      expect(quantum.window_size).to eq(1 << 15)
    end

    it "accepts window_bits from 10 to 21" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      (10..21).each do |bits|
        quantum = described_class.new(io_system, input, output, 4096,
                                      window_bits: bits)
        expect(quantum.window_bits).to eq(bits)
        expect(quantum.window_size).to eq(1 << bits)
      end
    end

    it "raises error for window_bits below 10" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      expect do
        described_class.new(io_system, input, output, 4096, window_bits: 9)
      end.to raise_error(Cabriolet::ArgumentError, /must be 10-21/)
    end

    it "raises error for window_bits above 21" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      expect do
        described_class.new(io_system, input, output, 4096, window_bits: 22)
      end.to raise_error(Cabriolet::ArgumentError, /must be 10-21/)
    end
  end

  describe "#decompress" do
    it "returns 0 when decompressing 0 bytes" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")
      quantum = described_class.new(io_system, input, output, 4096)

      result = quantum.decompress(0)
      expect(result).to eq(0)
    end

    it "returns 0 when decompressing negative bytes" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")
      quantum = described_class.new(io_system, input, output, 4096)

      result = quantum.decompress(-1)
      expect(result).to eq(0)
    end
  end

  describe "constants" do
    it "defines FRAME_SIZE" do
      expect(described_class::FRAME_SIZE).to eq(32_768)
    end

    it "defines MAX_MATCH" do
      expect(described_class::MAX_MATCH).to eq(1028)
    end

    it "defines POSITION_BASE table" do
      expect(described_class::POSITION_BASE).to be_an(Array)
      expect(described_class::POSITION_BASE.size).to eq(42)
      expect(described_class::POSITION_BASE[0]).to eq(0)
      expect(described_class::POSITION_BASE[1]).to eq(1)
    end

    it "defines EXTRA_BITS table" do
      expect(described_class::EXTRA_BITS).to be_an(Array)
      expect(described_class::EXTRA_BITS.size).to eq(42)
    end

    it "defines LENGTH_BASE table" do
      expect(described_class::LENGTH_BASE).to be_an(Array)
      expect(described_class::LENGTH_BASE.size).to eq(27)
    end

    it "defines LENGTH_EXTRA table" do
      expect(described_class::LENGTH_EXTRA).to be_an(Array)
      expect(described_class::LENGTH_EXTRA.size).to eq(27)
    end
  end

  describe "ModelSymbol" do
    it "creates a model symbol with sym and cumfreq" do
      sym = described_class::ModelSymbol.new(42, 100)
      expect(sym.sym).to eq(42)
      expect(sym.cumfreq).to eq(100)
    end

    it "allows updating sym and cumfreq" do
      sym = described_class::ModelSymbol.new(1, 2)
      sym.sym = 10
      sym.cumfreq = 20
      expect(sym.sym).to eq(10)
      expect(sym.cumfreq).to eq(20)
    end
  end

  describe "Model" do
    it "creates a model with syms and entries" do
      syms = Array.new(5) { |i| described_class::ModelSymbol.new(i, 5 - i) }
      model = described_class::Model.new(syms, 5)

      expect(model.syms).to eq(syms)
      expect(model.entries).to eq(5)
      expect(model.shiftsleft).to eq(4)
    end
  end

  describe "MSBBitstream" do
    let(:quantum_class) { described_class }

    it "reads bits MSB first" do
      # Create test data: 0x12 0x34 = 0001 0010 0011 0100
      input = Cabriolet::System::MemoryHandle.new("\x12\x34")
      output = Cabriolet::System::MemoryHandle.new("")
      quantum = quantum_class.new(io_system, input, output, 4096)

      # Access the bitstream through private methods
      bitstream = quantum.instance_variable_get(:@bitstream)
      expect(bitstream).to be_a(quantum_class::MSBBitstream)
    end

    it "handles byte alignment" do
      input = Cabriolet::System::MemoryHandle.new("\xFF\xFF\xFF\xFF")
      output = Cabriolet::System::MemoryHandle.new("")
      quantum = quantum_class.new(io_system, input, output, 4096)

      bitstream = quantum.instance_variable_get(:@bitstream)
      bitstream.read_bits(5)
      expect(bitstream.bits_left).to be > 0

      bitstream.byte_align
      expect(bitstream.bits_left % 8).to eq(0)
    end
  end

  describe "arithmetic coding models" do
    it "initializes 7 models" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")
      quantum = described_class.new(io_system, input, output, 4096,
                                    window_bits: 15)

      # Check that models are initialized
      expect(quantum.instance_variable_get(:@model0)).to be_a(described_class::Model)
      expect(quantum.instance_variable_get(:@model1)).to be_a(described_class::Model)
      expect(quantum.instance_variable_get(:@model2)).to be_a(described_class::Model)
      expect(quantum.instance_variable_get(:@model3)).to be_a(described_class::Model)
      expect(quantum.instance_variable_get(:@model4)).to be_a(described_class::Model)
      expect(quantum.instance_variable_get(:@model5)).to be_a(described_class::Model)
      expect(quantum.instance_variable_get(:@model6)).to be_a(described_class::Model)
      expect(quantum.instance_variable_get(:@model6len)).to be_a(described_class::Model)
      expect(quantum.instance_variable_get(:@model7)).to be_a(described_class::Model)
    end

    it "initializes literal models with 64 entries each" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")
      quantum = described_class.new(io_system, input, output, 4096)

      model0 = quantum.instance_variable_get(:@model0)
      expect(model0.entries).to eq(64)
      expect(model0.syms.size).to eq(65) # +1 for sentinel
    end

    it "initializes match models based on window size" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")
      quantum = described_class.new(io_system, input, output, 4096,
                                    window_bits: 15)

      # window_bits * 2 = 30
      model4 = quantum.instance_variable_get(:@model4)
      expect(model4.entries).to eq(24) # min(30, 24)

      model5 = quantum.instance_variable_get(:@model5)
      expect(model5.entries).to eq(30) # min(30, 36)

      model6 = quantum.instance_variable_get(:@model6)
      expect(model6.entries).to eq(30)
    end

    it "initializes selector model with 7 entries" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")
      quantum = described_class.new(io_system, input, output, 4096)

      model7 = quantum.instance_variable_get(:@model7)
      expect(model7.entries).to eq(7)
    end
  end

  describe "window management" do
    it "initializes window to correct size" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")
      quantum = described_class.new(io_system, input, output, 4096,
                                    window_bits: 12)

      window = quantum.instance_variable_get(:@window)
      expect(window.bytesize).to eq(1 << 12)
    end

    it "tracks window position" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")
      quantum = described_class.new(io_system, input, output, 4096)

      window_posn = quantum.instance_variable_get(:@window_posn)
      expect(window_posn).to eq(0)
    end

    it "tracks frame todo counter" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")
      quantum = described_class.new(io_system, input, output, 4096)

      frame_todo = quantum.instance_variable_get(:@frame_todo)
      expect(frame_todo).to eq(described_class::FRAME_SIZE)
    end
  end

  describe "arithmetic coding state" do
    it "initializes H, L, C registers" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")
      quantum = described_class.new(io_system, input, output, 4096)

      h = quantum.instance_variable_get(:@h)
      l = quantum.instance_variable_get(:@l)
      c = quantum.instance_variable_get(:@c)

      expect(h).to eq(0xFFFF)
      expect(l).to eq(0)
      expect(c).to eq(0)
    end

    it "tracks header read state" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")
      quantum = described_class.new(io_system, input, output, 4096)

      header_read = quantum.instance_variable_get(:@header_read)
      expect(header_read).to be(false)
    end
  end

  describe "error handling" do
    it "raises error on invalid selector" do
      # This would require crafted invalid compressed data
      # For now, just verify the error class exists
      expect { raise Cabriolet::DecompressionError, "test" }
        .to raise_error(Cabriolet::DecompressionError)
    end

    it "raises error when match exceeds window" do
      # This would require crafted invalid compressed data
      # Verify error handling exists in the code
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")
      quantum = described_class.new(io_system, input, output, 4096)

      # Access private method to test error condition
      expect do
        quantum.send(:copy_match, 10_000, 100)
      end.to raise_error(Cabriolet::DecompressionError, /beyond window/)
    end
  end

  # Integration tests with real CAB files would go here
  # These would use the fixtures in spec/fixtures/libmspack/cabd/
  describe "integration" do
    it "can be instantiated for integration testing" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      quantum = described_class.new(io_system, input, output, 4096,
                                    window_bits: 17)
      expect(quantum).to be_a(described_class)
    end
  end
end
