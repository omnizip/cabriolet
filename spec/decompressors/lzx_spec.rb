# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::Decompressors::LZX do
  let(:io_system) { Cabriolet::System::IOSystem.new }

  # Helper: compress data using the LZX compressor for round-trip tests
  def compress_with_lzx(data, window_bits)
    io = Cabriolet::System::IOSystem.new
    input = Cabriolet::System::MemoryHandle.new(data)
    output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
    compressor = Cabriolet::Compressors::LZX.new(io, input, output, 4096,
                                                 window_bits: window_bits)
    compressor.compress
    output.data
  end

  describe "#initialize" do
    context "with valid window_bits" do
      it "initializes with window_bits 15 for regular LZX" do
        input = Cabriolet::System::MemoryHandle.new("")
        output = Cabriolet::System::MemoryHandle.new("")

        lzx = described_class.new(io_system, input, output, 4096,
                                  window_bits: 15)

        expect(lzx.window_bits).to eq(15)
        expect(lzx.is_delta).to be false
      end

      it "initializes with window_bits 21 for regular LZX" do
        input = Cabriolet::System::MemoryHandle.new("")
        output = Cabriolet::System::MemoryHandle.new("")

        lzx = described_class.new(io_system, input, output, 4096,
                                  window_bits: 21)

        expect(lzx.window_bits).to eq(21)
      end

      it "initializes with window_bits 17 for LZX DELTA" do
        input = Cabriolet::System::MemoryHandle.new("")
        output = Cabriolet::System::MemoryHandle.new("")

        lzx = described_class.new(io_system, input, output, 4096,
                                  window_bits: 17, is_delta: true)

        expect(lzx.window_bits).to eq(17)
        expect(lzx.is_delta).to be true
      end

      it "initializes with window_bits 25 for LZX DELTA" do
        input = Cabriolet::System::MemoryHandle.new("")
        output = Cabriolet::System::MemoryHandle.new("")

        lzx = described_class.new(io_system, input, output, 4096,
                                  window_bits: 25, is_delta: true)

        expect(lzx.window_bits).to eq(25)
        expect(lzx.is_delta).to be true
      end
    end

    context "with invalid window_bits" do
      it "raises error for window_bits < 15 in regular LZX" do
        input = Cabriolet::System::MemoryHandle.new("")
        output = Cabriolet::System::MemoryHandle.new("")

        expect do
          described_class.new(io_system, input, output, 4096,
                              window_bits: 14)
        end.to raise_error(Cabriolet::ArgumentError, /must be 15-21/)
      end

      it "raises error for window_bits > 21 in regular LZX" do
        input = Cabriolet::System::MemoryHandle.new("")
        output = Cabriolet::System::MemoryHandle.new("")

        expect do
          described_class.new(io_system, input, output, 4096,
                              window_bits: 22)
        end.to raise_error(Cabriolet::ArgumentError, /must be 15-21/)
      end

      it "raises error for window_bits < 17 in LZX DELTA" do
        input = Cabriolet::System::MemoryHandle.new("")
        output = Cabriolet::System::MemoryHandle.new("")

        expect do
          described_class.new(io_system, input, output, 4096,
                              window_bits: 16, is_delta: true)
        end.to raise_error(Cabriolet::ArgumentError, /must be 17-25/)
      end

      it "raises error for window_bits > 25 in LZX DELTA" do
        input = Cabriolet::System::MemoryHandle.new("")
        output = Cabriolet::System::MemoryHandle.new("")

        expect do
          described_class.new(io_system, input, output, 4096,
                              window_bits: 26, is_delta: true)
        end.to raise_error(Cabriolet::ArgumentError, /must be 17-25/)
      end
    end

    it "initializes with reset_interval" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15, reset_interval: 2)

      expect(lzx.reset_interval).to eq(2)
    end

    it "initializes with output_length" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15, output_length: 65_536)

      expect(lzx.output_length).to eq(65_536)
    end
  end

  describe "#set_output_length" do
    it "updates output_length" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15)

      lzx.set_output_length(32_768)
      expect(lzx.output_length).to eq(32_768)
    end

    it "ignores zero or negative length" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15, output_length: 100)

      lzx.set_output_length(0)
      expect(lzx.output_length).to eq(100)

      lzx.set_output_length(-1)
      expect(lzx.output_length).to eq(100)
    end
  end

  describe "#decompress" do
    it "returns 0 for zero bytes requested" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15)

      expect(lzx.decompress(0)).to eq(0)
    end

    it "returns 0 for negative bytes requested" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15)

      expect(lzx.decompress(-1)).to eq(0)
    end
  end

  describe "constants" do
    it "defines FRAME_SIZE" do
      expect(described_class::FRAME_SIZE).to eq(32_768)
    end

    it "defines block types" do
      expect(described_class::BLOCKTYPE_INVALID).to eq(0)
      expect(described_class::BLOCKTYPE_VERBATIM).to eq(1)
      expect(described_class::BLOCKTYPE_ALIGNED).to eq(2)
      expect(described_class::BLOCKTYPE_UNCOMPRESSED).to eq(3)
    end

    it "defines match constants" do
      expect(described_class::MIN_MATCH).to eq(2)
      expect(described_class::MAX_MATCH).to eq(257)
      expect(described_class::NUM_CHARS).to eq(256)
    end

    it "defines tree constants" do
      expect(described_class::PRETREE_NUM_ELEMENTS).to eq(20)
      expect(described_class::PRETREE_MAXSYMBOLS).to eq(20)
      expect(described_class::PRETREE_TABLEBITS).to eq(6)

      expect(described_class::ALIGNED_NUM_ELEMENTS).to eq(8)
      expect(described_class::ALIGNED_MAXSYMBOLS).to eq(8)
      expect(described_class::ALIGNED_TABLEBITS).to eq(7)

      expect(described_class::NUM_PRIMARY_LENGTHS).to eq(7)
      expect(described_class::NUM_SECONDARY_LENGTHS).to eq(249)
      expect(described_class::LENGTH_MAXSYMBOLS).to eq(250)
      expect(described_class::LENGTH_TABLEBITS).to eq(12)
    end

    it "defines position slots" do
      expect(described_class::POSITION_SLOTS).to be_an(Array)
      expect(described_class::POSITION_SLOTS.size).to eq(11)
      expect(described_class::POSITION_SLOTS.first).to eq(30)
      expect(described_class::POSITION_SLOTS.last).to eq(290)
    end

    it "defines extra bits" do
      expect(described_class::EXTRA_BITS).to be_an(Array)
      expect(described_class::EXTRA_BITS.size).to eq(36)
      expect(described_class::EXTRA_BITS[0...4]).to all(eq(0))
    end

    it "defines position base" do
      expect(described_class::POSITION_BASE).to be_an(Array)
      expect(described_class::POSITION_BASE.size).to eq(290)
      expect(described_class::POSITION_BASE.first).to eq(0)
      expect(described_class::POSITION_BASE[1]).to eq(1)
    end
  end

  describe "integration tests with fixtures" do
    let(:fixtures_dir) { File.join(__dir__, "../fixtures/libmspack/cabd") }

    context "with mszip_lzx_qtm.cab" do
      let(:cab_file) { File.join(fixtures_dir, "mszip_lzx_qtm.cab") }

      it "exists" do
        expect(File.exist?(cab_file)).to be true
      end

      # NOTE: Full integration test would require parsing the CAB file
      # and extracting LZX-compressed data. This is a placeholder for
      # when the full CAB parser is integrated.
    end

    context "with LZX-specific fixtures" do
      let(:lzx_premature_matches) do
        File.join(fixtures_dir, "lzx-premature-matches.cab")
      end
      let(:lzx_main_tree_no_lengths) do
        File.join(fixtures_dir, "lzx-main-tree-no-lengths.cab")
      end

      it "has lzx-premature-matches.cab" do
        expect(File.exist?(lzx_premature_matches)).to be true
      end

      it "has lzx-main-tree-no-lengths.cab" do
        expect(File.exist?(lzx_main_tree_no_lengths)).to be true
      end
    end
  end

  describe "window size calculations" do
    it "calculates correct window size for window_bits 15" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15)

      # Window size = 2^15 = 32KB
      expect(lzx.instance_variable_get(:@window_size)).to eq(32_768)
    end

    it "calculates correct window size for window_bits 21" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 21)

      # Window size = 2^21 = 2MB
      expect(lzx.instance_variable_get(:@window_size)).to eq(2_097_152)
    end

    it "calculates correct number of offsets for window_bits 15" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15)

      # POSITION_SLOTS[0] = 30, so num_offsets = 30 << 3 = 240
      expect(lzx.instance_variable_get(:@num_offsets)).to eq(240)
    end
  end

  describe "state initialization" do
    it "initializes R0, R1, R2 to 1" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15)

      expect(lzx.instance_variable_get(:@r0)).to eq(1)
      expect(lzx.instance_variable_get(:@r1)).to eq(1)
      expect(lzx.instance_variable_get(:@r2)).to eq(1)
    end

    it "initializes block state" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15)

      expect(lzx.instance_variable_get(:@block_type)).to eq(0)
      expect(lzx.instance_variable_get(:@block_length)).to eq(0)
      expect(lzx.instance_variable_get(:@block_remaining)).to eq(0)
      expect(lzx.instance_variable_get(:@header_read)).to be false
    end

    it "initializes Intel E8 state" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15)

      expect(lzx.instance_variable_get(:@intel_filesize)).to eq(0)
      expect(lzx.instance_variable_get(:@intel_started)).to be false
    end

    it "initializes frame tracking" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15)

      expect(lzx.instance_variable_get(:@window_posn)).to eq(0)
      expect(lzx.instance_variable_get(:@frame_posn)).to eq(0)
      expect(lzx.instance_variable_get(:@frame)).to eq(0)
      expect(lzx.instance_variable_get(:@offset)).to eq(0)
    end
  end

  describe "Huffman tree initialization" do
    it "initializes all tree length arrays" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15)

      pretree_lengths = lzx.instance_variable_get(:@pretree_lengths)
      expect(pretree_lengths).to be_an(Array)
      expect(pretree_lengths.size).to eq(20)
      expect(pretree_lengths).to all(eq(0))

      maintree_lengths = lzx.instance_variable_get(:@maintree_lengths)
      expect(maintree_lengths).to be_an(Array)
      expect(maintree_lengths.size).to eq(256 + 240) # NUM_CHARS + num_offsets

      length_lengths = lzx.instance_variable_get(:@length_lengths)
      expect(length_lengths).to be_an(Array)
      expect(length_lengths.size).to eq(250)

      aligned_lengths = lzx.instance_variable_get(:@aligned_lengths)
      expect(aligned_lengths).to be_an(Array)
      expect(aligned_lengths.size).to eq(8)
    end

    it "initializes tree objects to nil" do
      input = Cabriolet::System::MemoryHandle.new("")
      output = Cabriolet::System::MemoryHandle.new("")

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15)

      expect(lzx.instance_variable_get(:@pretree)).to be_nil
      expect(lzx.instance_variable_get(:@maintree)).to be_nil
      expect(lzx.instance_variable_get(:@length_tree)).to be_nil
      expect(lzx.instance_variable_get(:@aligned_tree)).to be_nil
    end
  end

  describe "frame position wrapping" do
    # Regression tests for frame_posn/window_posn wrapping.
    #
    # The window is a circular buffer of @window_size bytes. frame_posn tracks
    # where each frame starts. Normally frame_posn advances by exactly
    # FRAME_SIZE (32768), landing exactly on window_size, so == works.
    #
    # But the last frame of an output can be shorter than FRAME_SIZE (when
    # output_length is not a multiple of FRAME_SIZE). This leaves frame_posn
    # at a misaligned position. The next full frame then overshoots
    # window_size, so >= is required to catch it.
    #
    # Example with window_bits=15 (window_size=32768):
    #   Short frame: frame_posn = 0 + 232 = 232  (no reset, 232 < 32768)
    #   Next frame:  frame_posn = 232 + 32768 = 33000  (33000 > 32768!)
    #   With ==:  33000 == 32768 is false → no reset → nil window read → crash
    #   With >=:  33000 >= 32768 is true  → reset to 0 → correct

    it "resets frame_posn to 0 when it overshoots window_size" do
      input = Cabriolet::System::MemoryHandle.new("\x00" * 65_536)
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15, output_length: 33_000)

      # Simulate state after a short frame left frame_posn at 232
      lzx.instance_variable_set(:@header_read, true)
      lzx.instance_variable_set(:@intel_filesize, 0)
      lzx.instance_variable_set(:@frame_posn, 232)
      lzx.instance_variable_set(:@window_posn, 232)
      lzx.instance_variable_set(:@frame, 1)
      lzx.instance_variable_set(:@offset, 232)

      # Fill window with data so @window[232, 32768] doesn't return nil
      lzx.instance_variable_set(:@window, "A".b * 32_768)

      # Stub decode_frame so we don't need valid LZX bitstream data
      allow(lzx).to receive(:decode_frame) do |frame_size|
        wp = lzx.instance_variable_get(:@window_posn)
        new_wp = wp + frame_size
        new_wp = 0 if new_wp >= 32_768
        lzx.instance_variable_set(:@window_posn, new_wp)
      end

      bs = lzx.instance_variable_get(:@bitstream)
      allow(bs).to receive(:byte_align)

      lzx.decompress(32_768)

      # frame_posn went from 232 + 32768 = 33000, which overshoots window_size (32768).
      # The >= check must reset it to 0. If == were used, it would stay at 33000.
      frame_posn = lzx.instance_variable_get(:@frame_posn)
      expect(frame_posn).to eq(0),
                            "frame_posn should wrap to 0 when it overshoots window_size " \
                            "(got #{frame_posn}). The boundary check must use >= not =="
    end

    it "resets window_posn to 0 when it reaches window_size exactly" do
      input = Cabriolet::System::MemoryHandle.new("\x00" * 65_536)
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15, output_length: 32_768)

      lzx.instance_variable_set(:@header_read, true)
      lzx.instance_variable_set(:@intel_filesize, 0)
      lzx.instance_variable_set(:@frame_posn, 0)
      lzx.instance_variable_set(:@window_posn, 0)
      lzx.instance_variable_set(:@frame, 0)
      lzx.instance_variable_set(:@offset, 0)
      lzx.instance_variable_set(:@window, "A".b * 32_768)

      allow(lzx).to receive(:decode_frame) do |frame_size|
        lzx.instance_variable_set(:@window_posn, frame_size)
      end

      bs = lzx.instance_variable_get(:@bitstream)
      allow(bs).to receive(:byte_align)

      lzx.decompress(32_768)

      # frame_posn = 0 + 32768 = 32768 == window_size → reset to 0
      # This is the exact-match case that == also handles.
      expect(lzx.instance_variable_get(:@frame_posn)).to eq(0)
      expect(lzx.instance_variable_get(:@window_posn)).to eq(0)
    end

    it "does not reset frame_posn when it is within window_size" do
      input = Cabriolet::System::MemoryHandle.new("\x00" * 65_536)
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)

      # window_bits=16 → window_size=65536, so one FRAME_SIZE frame won't wrap
      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 16, output_length: 32_768)

      lzx.instance_variable_set(:@header_read, true)
      lzx.instance_variable_set(:@intel_filesize, 0)
      lzx.instance_variable_set(:@frame_posn, 0)
      lzx.instance_variable_set(:@window_posn, 0)
      lzx.instance_variable_set(:@frame, 0)
      lzx.instance_variable_set(:@offset, 0)
      lzx.instance_variable_set(:@window, "A".b * 65_536)

      allow(lzx).to receive(:decode_frame) do |frame_size|
        lzx.instance_variable_set(:@window_posn, frame_size)
      end

      bs = lzx.instance_variable_get(:@bitstream)
      allow(bs).to receive(:byte_align)

      lzx.decompress(32_768)

      # frame_posn = 0 + 32768 = 32768 < 65536 → no reset
      expect(lzx.instance_variable_get(:@frame_posn)).to eq(32_768)
    end
  end

  describe "nil frame_data guard" do
    # The nil guard is a defensive check: if @frame_posn is somehow out of
    # bounds (corrupt stream, regression in the >= wrap check), we get a
    # clear DecompressionError instead of a cryptic NoMethodError on nil.

    it "raises DecompressionError when frame_data is nil" do
      input = Cabriolet::System::MemoryHandle.new("\x00" * 65_536)
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15, output_length: 32_768)

      lzx.instance_variable_set(:@header_read, true)
      lzx.instance_variable_set(:@intel_filesize, 0)
      # Place frame_posn beyond window — forces @window[@frame_posn, n] → nil
      lzx.instance_variable_set(:@frame_posn, 40_000)
      lzx.instance_variable_set(:@window_posn, 0)
      lzx.instance_variable_set(:@frame, 0)
      lzx.instance_variable_set(:@offset, 0)
      lzx.instance_variable_set(:@window, "A".b * 32_768)

      allow(lzx).to receive(:decode_frame)
      bs = lzx.instance_variable_get(:@bitstream)
      allow(bs).to receive(:byte_align)

      expect { lzx.decompress(32_768) }.to raise_error(
        Cabriolet::DecompressionError, /nil frame data/
      )
    end

    it "breaks gracefully in salvage mode when frame_data is nil" do
      input = Cabriolet::System::MemoryHandle.new("\x00" * 65_536)
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)

      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15, output_length: 32_768, salvage: true)

      lzx.instance_variable_set(:@header_read, true)
      lzx.instance_variable_set(:@intel_filesize, 0)
      lzx.instance_variable_set(:@frame_posn, 40_000)
      lzx.instance_variable_set(:@window_posn, 0)
      lzx.instance_variable_set(:@frame, 0)
      lzx.instance_variable_set(:@offset, 0)
      lzx.instance_variable_set(:@window, "A".b * 32_768)

      allow(lzx).to receive(:decode_frame)
      bs = lzx.instance_variable_get(:@bitstream)
      allow(bs).to receive(:byte_align)

      # Should not raise — returns 0 bytes written and prints a warning
      result = lzx.decompress(32_768)
      expect(result).to eq(0)
    end
  end

  describe "pending frame data for multi-file extraction" do
    # Per libmspack: when decompress is called per-file within a shared
    # folder, a frame may be partially consumed by one call. The
    # remaining frame data must carry over to the next call.

    it "stores pending data when partial frame is written" do
      original = "Hello, World! This is test data."
      compressed = compress_with_lzx(original, 15)

      input = Cabriolet::System::MemoryHandle.new(compressed)
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15, output_length: original.bytesize)

      # Request only 10 bytes from a frame that contains more
      result = lzx.decompress(10)
      expect(result).to eq(10)
      expect(output.data.bytesize).to eq(10)
      expect(output.data).to eq(original[0, 10])

      # Pending data should be stored for the next call
      expect(lzx.instance_variable_get(:@pending_frame_data)).not_to be_nil
    end

    it "outputs pending data on subsequent decompress call" do
      original = "Hello, World! This is test data."
      compressed = compress_with_lzx(original, 15)

      input = Cabriolet::System::MemoryHandle.new(compressed)
      output1 = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
      lzx = described_class.new(io_system, input, output1, 4096,
                                window_bits: 15, output_length: original.bytesize)

      # First call: read 10 bytes
      lzx.decompress(10)

      # Second call: read the rest, with a new output handle
      output2 = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
      lzx.instance_variable_set(:@output, output2)
      remaining = original.bytesize - 10
      result = lzx.decompress(remaining)

      expect(result).to eq(remaining)
      expect(output2.data).to eq(original[10, remaining])
    end

    it "handles exact frame-sized writes without pending data" do
      # Data exactly one frame — no pending data should remain
      original = "X" * 32_768
      compressed = compress_with_lzx(original, 15)

      input = Cabriolet::System::MemoryHandle.new(compressed)
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15, output_length: original.bytesize)

      lzx.decompress(32_768)
      expect(lzx.instance_variable_get(:@pending_frame_data)).to be_nil
    end
  end

  describe "offset tracking" do
    # Per libmspack: @offset must track actual output bytes, not full
    # frame sizes. This ensures end_frame is calculated correctly for
    # subsequent decompress calls in multi-file extraction.

    it "tracks actual output bytes, not full frame bytes" do
      original = "A" * 100
      compressed = compress_with_lzx(original, 15)

      input = Cabriolet::System::MemoryHandle.new(compressed)
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15, output_length: original.bytesize)

      lzx.decompress(50)
      # @offset should be 50 (bytes actually output), not 32768 (full frame)
      expect(lzx.instance_variable_get(:@offset)).to eq(50)
    end
  end

  describe "16-bit word alignment between frames" do
    # Per libmspack: LZX frames are padded to 16-bit word boundaries,
    # not 8-bit byte boundaries. This test verifies multi-frame
    # round-trip where inter-frame alignment matters.

    it "correctly round-trips data spanning multiple frames" do
      # Data > 32KB forces multiple frames with inter-frame alignment
      original = "MultiFrame" * 5000 # 50KB

      compressed = compress_with_lzx(original, 15)

      input = Cabriolet::System::MemoryHandle.new(compressed)
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15, output_length: original.bytesize)
      lzx.decompress(original.bytesize)

      expect(output.data).to eq(original)
    end
  end

  describe "uncompressed block round-trip" do
    # The decompressor reads uncompressed block data via read_raw_byte
    # (bypassing the MSB bitstream). The compressor must write these
    # blocks as raw bytes too, not through the bitstream.

    it "round-trips short data through uncompressed blocks" do
      original = "Hello!"
      compressed = compress_with_lzx(original, 15)

      input = Cabriolet::System::MemoryHandle.new(compressed)
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15, output_length: original.bytesize)
      lzx.decompress(original.bytesize)

      expect(output.data).to eq(original)
    end

    it "round-trips binary data through uncompressed blocks" do
      original = (0..255).to_a.pack("C*")
      compressed = compress_with_lzx(original, 15)

      input = Cabriolet::System::MemoryHandle.new(compressed)
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15, output_length: original.bytesize)
      lzx.decompress(original.bytesize)

      expect(output.data).to eq(original)
    end

    it "round-trips odd-length data correctly" do
      # Odd-length exercises the padding byte between blocks
      original = "A" * 13
      compressed = compress_with_lzx(original, 15)

      input = Cabriolet::System::MemoryHandle.new(compressed)
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15, output_length: original.bytesize)
      lzx.decompress(original.bytesize)

      expect(output.data).to eq(original)
    end
  end

  describe "match overrun handling" do
    # Per libmspack: decode_huffman_block returns run_length which can
    # go negative when a match crosses a block boundary. The overrun
    # is detected by decode_frame and subtracted from block_remaining.

    it "raises on excessive overrun" do
      input = Cabriolet::System::MemoryHandle.new("\x00" * 1024)
      output = Cabriolet::System::MemoryHandle.new("", Cabriolet::Constants::MODE_WRITE)
      lzx = described_class.new(io_system, input, output, 4096,
                                window_bits: 15, output_length: 32_768)

      lzx.instance_variable_set(:@header_read, true)
      lzx.instance_variable_set(:@intel_filesize, 0)
      lzx.instance_variable_set(:@frame_posn, 0)
      lzx.instance_variable_set(:@window_posn, 0)
      lzx.instance_variable_set(:@frame, 0)
      lzx.instance_variable_set(:@offset, 0)
      lzx.instance_variable_set(:@window, "A".b * 32_768)

      # Stub decode_huffman_block to simulate a huge overrun
      allow(lzx).to receive(:read_block_header) do
        lzx.instance_variable_set(:@block_type, 1) # VERBATIM
        lzx.instance_variable_set(:@block_remaining, 100)
        lzx.instance_variable_set(:@block_length, 100)
      end

      allow(lzx).to receive(:decode_huffman_block).and_return(-200)

      expect { lzx.decompress(32_768) }.to raise_error(
        Cabriolet::DecompressionError, /Match overrun/
      )
    end
  end
end
