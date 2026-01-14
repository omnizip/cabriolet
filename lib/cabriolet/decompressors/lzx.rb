# frozen_string_literal: true

require_relative "base"

module Cabriolet
  module Decompressors
    # LZX handles LZX compressed data
    # Based on libmspack lzxd.c implementation
    #
    # The LZX method was created by Jonathan Forbes and Tomi Poutanen,
    # adapted by Microsoft Corporation.
    class LZX < Base
      # Frame size (32KB per frame)
      FRAME_SIZE = 32_768

      # Block types
      BLOCKTYPE_INVALID = 0
      BLOCKTYPE_VERBATIM = 1
      BLOCKTYPE_ALIGNED = 2
      BLOCKTYPE_UNCOMPRESSED = 3

      # Match constants
      MIN_MATCH = 2
      MAX_MATCH = 257
      NUM_CHARS = 256

      # Tree constants
      PRETREE_NUM_ELEMENTS = 20
      PRETREE_MAXSYMBOLS = 20
      PRETREE_TABLEBITS = 6

      ALIGNED_NUM_ELEMENTS = 8
      ALIGNED_MAXSYMBOLS = 8
      ALIGNED_TABLEBITS = 7

      NUM_PRIMARY_LENGTHS = 7
      NUM_SECONDARY_LENGTHS = 249
      LENGTH_MAXSYMBOLS = 250
      LENGTH_TABLEBITS = 12

      # Position slots for different window sizes
      POSITION_SLOTS = [30, 32, 34, 36, 38, 42, 50, 66, 98, 162, 290].freeze

      # Extra bits for position slots
      EXTRA_BITS = [
        0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8,
        9, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 15, 16, 16
      ].freeze

      # Position base offsets
      POSITION_BASE = [
        0, 1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64, 96, 128, 192, 256, 384, 512,
        768, 1024, 1536, 2048, 3072, 4096, 6144, 8192, 12_288, 16_384, 24_576, 32_768,
        49_152, 65_536, 98_304, 131_072, 196_608, 262_144, 393_216, 524_288, 655_360,
        786_432, 917_504, 1_048_576, 1_179_648, 1_310_720, 1_441_792, 1_572_864, 1_703_936,
        1_835_008, 1_966_080, 2_097_152, 2_228_224, 2_359_296, 2_490_368, 2_621_440, 2_752_512,
        2_883_584, 3_014_656, 3_145_728, 3_276_800, 3_407_872, 3_538_944, 3_670_016, 3_801_088,
        3_932_160, 4_063_232, 4_194_304, 4_325_376, 4_456_448, 4_587_520, 4_718_592, 4_849_664,
        4_980_736, 5_111_808, 5_242_880, 5_373_952, 5_505_024, 5_636_096, 5_767_168, 5_898_240,
        6_029_312, 6_160_384, 6_291_456, 6_422_528, 6_553_600, 6_684_672, 6_815_744, 6_946_816,
        7_077_888, 7_208_960, 7_340_032, 7_471_104, 7_602_176, 7_733_248, 7_864_320, 7_995_392,
        8_126_464, 8_257_536, 8_388_608, 8_519_680, 8_650_752, 8_781_824, 8_912_896, 9_043_968,
        9_175_040, 9_306_112, 9_437_184, 9_568_256, 9_699_328, 9_830_400, 9_961_472, 10_092_544,
        10_223_616, 10_354_688, 10_485_760, 10_616_832, 10_747_904, 10_878_976, 11_010_048,
        11_141_120, 11_272_192, 11_403_264, 11_534_336, 11_665_408, 11_796_480, 11_927_552,
        12_058_624, 12_189_696, 12_320_768, 12_451_840, 12_582_912, 12_713_984, 12_845_056,
        12_976_128, 13_107_200, 13_238_272, 13_369_344, 13_500_416, 13_631_488, 13_762_560,
        13_893_632, 14_024_704, 14_155_776, 14_286_848, 14_417_920, 14_548_992, 14_680_064,
        14_811_136, 14_942_208, 15_073_280, 15_204_352, 15_335_424, 15_466_496, 15_597_568,
        15_728_640, 15_859_712, 15_990_784, 16_121_856, 16_252_928, 16_384_000, 16_515_072,
        16_646_144, 16_777_216, 16_908_288, 17_039_360, 17_170_432, 17_301_504, 17_432_576,
        17_563_648, 17_694_720, 17_825_792, 17_956_864, 18_087_936, 18_219_008, 18_350_080,
        18_481_152, 18_612_224, 18_743_296, 18_874_368, 19_005_440, 19_136_512, 19_267_584,
        19_398_656, 19_529_728, 19_660_800, 19_791_872, 19_922_944, 20_054_016, 20_185_088,
        20_316_160, 20_447_232, 20_578_304, 20_709_376, 20_840_448, 20_971_520, 21_102_592,
        21_233_664, 21_364_736, 21_495_808, 21_626_880, 21_757_952, 21_889_024, 22_020_096,
        22_151_168, 22_282_240, 22_413_312, 22_544_384, 22_675_456, 22_806_528, 22_937_600,
        23_068_672, 23_199_744, 23_330_816, 23_461_888, 23_592_960, 23_724_032, 23_855_104,
        23_986_176, 24_117_248, 24_248_320, 24_379_392, 24_510_464, 24_641_536, 24_772_608,
        24_903_680, 25_034_752, 25_165_824, 25_296_896, 25_427_968, 25_559_040, 25_690_112,
        25_821_184, 25_952_256, 26_083_328, 26_214_400, 26_345_472, 26_476_544, 26_607_616,
        26_738_688, 26_869_760, 27_000_832, 27_131_904, 27_262_976, 27_394_048, 27_525_120,
        27_656_192, 27_787_264, 27_918_336, 28_049_408, 28_180_480, 28_311_552, 28_442_624,
        28_573_696, 28_704_768, 28_835_840, 28_966_912, 29_097_984, 29_229_056, 29_360_128,
        29_491_200, 29_622_272, 29_753_344, 29_884_416, 30_015_488, 30_146_560, 30_277_632,
        30_408_704, 30_539_776, 30_670_848, 30_801_920, 30_932_992, 31_064_064, 31_195_136,
        31_326_208, 31_457_280, 31_588_352, 31_719_424, 31_850_496, 31_981_568, 32_112_640,
        32_243_712, 32_374_784, 32_505_856, 32_636_928, 32_768_000, 32_899_072, 33_030_144,
        33_161_216, 33_292_288, 33_423_360
      ].freeze

      attr_reader :window_bits, :reset_interval, :output_length, :is_delta

      # Initialize LZX decompressor
      #
      # @param io_system [System::IOSystem] I/O system for reading/writing
      # @param input [System::FileHandle, System::MemoryHandle] Input handle
      # @param output [System::FileHandle, System::MemoryHandle] Output handle
      # @param buffer_size [Integer] Buffer size for I/O operations
      # @param window_bits [Integer] Window size (15-21 for regular, 17-25 for DELTA)
      # @param reset_interval [Integer] Frame count between resets (0 = never)
      # @param output_length [Integer] Expected output length for E8 processing
      # @param is_delta [Boolean] Whether this is LZX DELTA format
      def initialize(io_system, input, output, buffer_size, window_bits:,
                     reset_interval: 0, output_length: 0, is_delta: false, salvage: false, **_kwargs)
        super(io_system, input, output, buffer_size)

        # Validate window_bits
        if is_delta
          unless (17..25).cover?(window_bits)
            raise ArgumentError,
                  "LZX DELTA window_bits must be 17-25, got #{window_bits}"
          end
        elsif !(15..21).cover?(window_bits)
          raise ArgumentError,
                "LZX window_bits must be 15-21, got #{window_bits}"
        end

        @window_bits = window_bits
        @window_size = 1 << window_bits
        @reset_interval = reset_interval
        @output_length = output_length
        @is_delta = is_delta

        # Calculate number of position slots
        @num_offsets = POSITION_SLOTS[window_bits - 15] << 3
        @maintree_maxsymbols = NUM_CHARS + @num_offsets

        # Initialize window
        @window = "\0" * @window_size
        @window_posn = 0
        @frame_posn = 0
        @frame = 0

        # Initialize R0, R1, R2 (LRU offset registers)
        @r0 = 1
        @r1 = 1
        @r2 = 1

        # Initialize block state
        @block_type = BLOCKTYPE_INVALID
        @block_length = 0
        @block_remaining = 0
        @header_read = false

        # Intel E8 transformation state
        @intel_filesize = 0
        @intel_started = false
        @e8_buf = "\0" * FRAME_SIZE

        # Initialize bitstream (LZX uses MSB-first bit ordering per libmspack lzxd.c)
        @bitstream = Binary::Bitstream.new(io_system, input, buffer_size,
                                           bit_order: :msb, salvage: salvage)

        # Initialize Huffman trees
        initialize_trees

        # Output tracking
        @offset = 0
        @output_ptr = 0
        @output_end = 0
      end

      # Set output length (for Intel E8 processing)
      #
      # @param length [Integer] Expected output length
      # @return [void]
      def set_output_length(length)
        @output_length = length if length.positive?
      end

      # Decompress LZX data
      #
      # @param bytes [Integer] Number of bytes to decompress
      # @return [Integer] Number of bytes decompressed
      def decompress(bytes)
        return 0 if bytes <= 0

        # Read Intel filesize header if not already read (once per stream)
        read_intel_header unless @header_read

        total_written = 0
        end_frame = ((@offset + bytes) / FRAME_SIZE) + 1

        while @frame < end_frame
          # Check reset interval - reset offset registers at frame boundaries
          if @reset_interval.positive? && (@frame % @reset_interval).zero? && @frame.positive?
            @r0 = @r1 = @r2 = 1
          end

          # Read DELTA chunk size if needed
          @bitstream.read_bits(16) if @is_delta

          # Calculate frame size
          frame_size = calculate_frame_size

          # Decode blocks until frame is complete
          decode_frame(frame_size)

          # Apply Intel E8 transformation if needed
          frame_data = if should_apply_e8_transform?(frame_size)
                         apply_e8_transform(frame_size)
                       else
                         @window[@frame_posn, frame_size]
                       end

          # Write frame
          write_amount = [bytes - total_written, frame_size].min
          io_system.write(output, frame_data[0, write_amount])
          total_written += write_amount
          @offset += frame_size

          # Advance frame
          @frame += 1
          @frame_posn += frame_size
          @frame_posn = 0 if @frame_posn == @window_size
          @window_posn = 0 if @window_posn == @window_size

          # Re-align bitstream (byte_align is safe to call even if already aligned)
          @bitstream.byte_align
        end

        total_written
      end

      private

      # Initialize Huffman code length arrays
      #
      # @return [void]
      def initialize_trees
        @pretree_lengths = Array.new(PRETREE_MAXSYMBOLS, 0)
        @maintree_lengths = Array.new(@maintree_maxsymbols, 0)
        @length_lengths = Array.new(LENGTH_MAXSYMBOLS, 0)
        @aligned_lengths = Array.new(ALIGNED_MAXSYMBOLS, 0)

        @pretree = nil
        @maintree = nil
        @length_tree = nil
        @aligned_tree = nil
        @length_empty = false
      end

      # Reset LZX state (called at reset intervals)
      #
      # Per libmspack: Only reset state variables, NOT Huffman code lengths.
      # Lengths persist across blocks and are updated via delta encoding.
      # They are only zeroed at initialization (in initialize_trees).
      #
      # @return [void]
      def reset_state
        @r0 = 1
        @r1 = 1
        @r2 = 1
        @header_read = false
        @block_remaining = 0
        @block_type = BLOCKTYPE_INVALID

        # NOTE: Do NOT reset @maintree_lengths or @length_lengths here!
        # Per libmspack lzxd.c line 267-269, lengths are initialized to 0
        # only once (at start) "because deltas will be applied to them".
        # Resetting them here breaks delta encoding between blocks.
      end

      # Read Intel filesize header (once per stream, before any frames)
      #
      # Format per libmspack:
      # - 1 bit: Intel flag (if 0, filesize = 0; if 1, read 32-bit filesize)
      # - If flag is 1: 32 bits for filesize (16 bits high, 16 bits low)
      #
      # @return [void]
      def read_intel_header
        if @bitstream.read_bits(1) == 1
          high = @bitstream.read_bits(16)
          low = @bitstream.read_bits(16)
          @intel_filesize = (high << 16) | low
        else
          @intel_filesize = 0
        end
        @header_read = true
      end

      # Calculate frame size
      #
      # @return [Integer] Frame size in bytes
      def calculate_frame_size
        frame_size = FRAME_SIZE
        frame_size = @output_length - @offset if @output_length.positive? && (@output_length - @offset) < frame_size
        frame_size
      end

      # Decode blocks until frame is complete
      #
      # @param frame_size [Integer] Target frame size
      # @return [void]
      def decode_frame(frame_size)
        bytes_todo = @frame_posn + frame_size - @window_posn

        while bytes_todo.positive?
          # Read new block header if needed
          read_block_header if @block_remaining.zero?

          # Decode as much as possible
          this_run = [@block_remaining, bytes_todo].min
          bytes_todo -= this_run
          @block_remaining -= this_run

          case @block_type
          when BLOCKTYPE_VERBATIM, BLOCKTYPE_ALIGNED
            decode_huffman_block(this_run)
          when BLOCKTYPE_UNCOMPRESSED
            decode_uncompressed_block(this_run)
          else
            raise DecompressionError, "Invalid block type: #{@block_type}"
          end
        end
      end

      # Read block header
      #
      # LZX block header format (per libmspack):
      # - 3 bits: block_type
      # - 24 bits: block_length (16 bits high, 8 bits low, combined as (high << 8) | low)
      #
      # @return [void]
      def read_block_header
        # Align for uncompressed blocks - this ensures correct byte alignment
        # when reading the R0, R1, R2 values from the block header
        @bitstream.byte_align if @block_type == BLOCKTYPE_UNCOMPRESSED && @block_length.allbits?(1)

        # Read block type (3 bits)
        @block_type = @bitstream.read_bits(3)

        # Read block length (24 bits: 16 bits high, then 8 bits low)
        high = @bitstream.read_bits(16)
        low = @bitstream.read_bits(8)
        @block_length = (high << 8) | low
        @block_remaining = @block_length

        case @block_type
        when BLOCKTYPE_ALIGNED
          read_aligned_block_header
        when BLOCKTYPE_VERBATIM
          read_verbatim_block_header
        when BLOCKTYPE_UNCOMPRESSED
          read_uncompressed_block_header
        else
          # Per libmspack lzxd.c line 519-521, BLOCKTYPE_INVALID (0) and
          # blocktypes 4-7 are all invalid and should raise an error
          raise DecompressionError, "Invalid block type: #{@block_type}"
        end
      end

      # Read aligned block header (aligned tree + main/length trees)
      #
      # @return [void]
      def read_aligned_block_header
        # Read aligned tree lengths
        8.times do |i|
          @aligned_lengths[i] = @bitstream.read_bits(3)
        end

        # Build aligned tree
        # Note: Aligned tree may be incomplete (Kraft sum < 1.0), which is valid
        # as long as the unused codes are never encountered in the bitstream
        @aligned_tree = Huffman::Tree.new(@aligned_lengths, ALIGNED_MAXSYMBOLS,
                                          bit_order: :msb)
        @aligned_tree.build_table(ALIGNED_TABLEBITS)

        # Read main and length trees (same as verbatim)
        read_main_and_length_trees
      end

      # Read verbatim block header (main/length trees)
      #
      # @return [void]
      def read_verbatim_block_header
        read_main_and_length_trees
      end

      # Read main and length trees
      #
      # @return [void]
      def read_main_and_length_trees
        # Read main tree lengths using pretree
        # Note: Each call to read_lengths reads its own pretree (per libmspack lzxd_read_lens)
        read_lengths(@maintree_lengths, 0, 256)
        read_lengths(@maintree_lengths, 256, @maintree_maxsymbols)

        # Build main tree
        @maintree = Huffman::Tree.new(@maintree_lengths, @maintree_maxsymbols,
                                      bit_order: :msb)
        unless @maintree.build_table(LENGTH_TABLEBITS)
          raise DecompressionError,
                "Failed to build main tree"
        end

        # Mark if E8 literal is present
        @intel_started = true if @maintree_lengths[0xE8] != 0

        # Read length tree
        read_lengths(@length_lengths, 0, NUM_SECONDARY_LENGTHS)

        # Build length tree (may be empty)
        @length_tree = Huffman::Tree.new(@length_lengths, LENGTH_MAXSYMBOLS,
                                         bit_order: :msb)
        if @length_tree.build_table(LENGTH_TABLEBITS)
          @length_empty = false
        else
          # Check if tree is completely empty (all zeros)
          @length_empty = @length_lengths[0...LENGTH_MAXSYMBOLS].all?(&:zero?)
          unless @length_empty
            raise DecompressionError,
                  "Failed to build length tree"
          end
        end
      end

      # Read pretree (20 elements, 4 bits each)
      #
      # @return [void]
      def read_pretree
        20.times do |i|
          @pretree_lengths[i] = @bitstream.read_bits(4)
        end

        @pretree = Huffman::Tree.new(@pretree_lengths, PRETREE_MAXSYMBOLS,
                                     bit_order: :msb)
        return if @pretree.build_table(PRETREE_TABLEBITS)

        raise DecompressionError, "Failed to build pretree"
      end

      # Read code lengths using pretree
      #
      # Per libmspack's lzxd_read_lens, each call reads its own pretree first
      #
      # @param lengths [Array<Integer>] Target length array
      # @param first [Integer] First symbol index
      # @param last [Integer] Last symbol index (exclusive)
      # @return [void]
      def read_lengths(lengths, first, last)
        # Read and build pretree (20 elements, 4 bits each)
        read_pretree

        x = first

        while x < last
          z = Huffman::Decoder.decode_symbol(
            @bitstream, @pretree.table, PRETREE_TABLEBITS,
            @pretree_lengths, PRETREE_MAXSYMBOLS
          )

          case z
          when 17
            # Run of (4 + read 4 bits) zeros
            run = @bitstream.read_bits(4) + 4
            run.times do
              lengths[x] = 0
              x += 1
            end
          when 18
            # Run of (20 + read 5 bits) zeros
            run = @bitstream.read_bits(5) + 20
            run.times do
              lengths[x] = 0
              x += 1
            end
          when 19
            # Run of (4 + read 1 bit) * (read symbol)
            run = @bitstream.read_bits(1) + 4
            z = Huffman::Decoder.decode_symbol(
              @bitstream, @pretree.table, PRETREE_TABLEBITS,
              @pretree_lengths, PRETREE_MAXSYMBOLS
            )
            z = lengths[x] - z
            z += 17 if z.negative?
            run.times do
              lengths[x] = z
              x += 1
            end
          else
            # Delta from previous length
            z = lengths[x] - z
            z += 17 if z.negative?
            lengths[x] = z
            x += 1
          end
        end
      end

      # Read uncompressed block header
      #
      # @return [void]
      def read_uncompressed_block_header
        @intel_started = true

        # Align to byte boundary
        @bitstream.byte_align

        # Read R0, R1, R2
        bytes = Array.new(12) { @bitstream.read_bits(8) }
        @r0 = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24)
        @r1 = bytes[4] | (bytes[5] << 8) | (bytes[6] << 16) | (bytes[7] << 24)
        @r2 = bytes[8] | (bytes[9] << 8) | (bytes[10] << 16) | (bytes[11] << 24)
      end

      # Decode Huffman-compressed block
      #
      # @param run_length [Integer] Number of bytes to decode
      # @return [void]
      def decode_huffman_block(run_length)
        while run_length.positive?
          # Decode main symbol
          main_element = Huffman::Decoder.decode_symbol(
            @bitstream, @maintree.table, LENGTH_TABLEBITS,
            @maintree_lengths, @maintree_maxsymbols
          )

          if main_element < NUM_CHARS
            # Literal byte
            @window.setbyte(@window_posn, main_element)
            @window_posn += 1
            run_length -= 1
          else
            # Match: decode length and offset, then decrement run_length by match_length
            match_length = decode_match(main_element, run_length)
            run_length -= match_length
          end
        end
      end

      # Decode and copy a match
      #
      # @param main_element [Integer] Main tree symbol
      # @param run_length [Integer] Remaining run length (unused, kept for compatibility)
      # @return [Integer] Match length (bytes consumed)
      def decode_match(main_element, _run_length)
        main_element -= NUM_CHARS

        # Decode match length
        match_length = main_element & NUM_PRIMARY_LENGTHS
        if match_length == NUM_PRIMARY_LENGTHS
          if @length_empty
            raise DecompressionError,
                  "Length tree needed but empty"
          end

          length_footer = Huffman::Decoder.decode_symbol(
            @bitstream, @length_tree.table, LENGTH_TABLEBITS,
            @length_lengths, LENGTH_MAXSYMBOLS
          )
          match_length += length_footer
        end
        match_length += MIN_MATCH

        # Decode match offset
        position_slot = main_element >> 3

        case position_slot
        when 0
          match_offset = @r0
        when 1
          @r1, @r0 = @r0, @r1
          match_offset = @r0
        when 2
          @r2, @r0 = @r0, @r2
          match_offset = @r0
        else
          # Calculate offset from position slot
          extra = position_slot >= 36 ? 17 : EXTRA_BITS[position_slot]
          match_offset = POSITION_BASE[position_slot] - 2

          if extra >= 3 && @block_type == BLOCKTYPE_ALIGNED
            # Use aligned offset tree for last 3 bits
            if extra > 3
              verbatim_bits = @bitstream.read_bits(extra - 3)
              match_offset += verbatim_bits << 3
            end
            aligned_bits = Huffman::Decoder.decode_symbol(
              @bitstream, @aligned_tree.table, ALIGNED_TABLEBITS,
              @aligned_lengths, ALIGNED_MAXSYMBOLS
            )
            match_offset += aligned_bits
          elsif extra.positive?
            verbatim_bits = @bitstream.read_bits(extra)
            match_offset += verbatim_bits
          end

          # Update LRU queue
          @r2 = @r1
          @r1 = @r0
          @r0 = match_offset
        end

        # LZX DELTA extended match length
        match_length += decode_extended_length if match_length == MAX_MATCH && @is_delta

        # Validate match
        if @window_posn + match_length > @window_size
          raise DecompressionError,
                "Match runs over window boundary"
        end

        # Copy match
        copy_match(match_offset, match_length)

        # Return match length so caller can decrement run_length
        match_length
      end

      # Decode extended match length for LZX DELTA
      #
      # @return [Integer] Additional length
      def decode_extended_length
        # Peek 3 bits for huffman tree
        bits = @bitstream.peek_bits(3)

        if bits.nobits?(1)
          # '0' -> 8 extra bits
          @bitstream.skip_bits(1)
          @bitstream.read_bits(8)
        elsif bits.nobits?(2)
          # '10' -> 10 extra bits + 0x100
          @bitstream.skip_bits(2)
          @bitstream.read_bits(10) + 0x100
        elsif bits.nobits?(4)
          # '110' -> 12 extra bits + 0x500
          @bitstream.skip_bits(3)
          @bitstream.read_bits(12) + 0x500
        else
          # '111' -> 15 extra bits
          @bitstream.skip_bits(3)
          @bitstream.read_bits(15)
        end
      end

      # Copy match from window
      #
      # @param offset [Integer] Match offset
      # @param length [Integer] Match length
      # @return [void]
      def copy_match(offset, length)
        if offset > @window_posn
          # Match wraps around window - validate it doesn't read beyond available data
          # Per libmspack lzxd.c lines 622-628: check if match offset goes beyond
          # what has been decompressed so far (accounting for any reference data)
          ref_data_size = 0 # We don't support reference data yet (LZX DELTA feature)
          if offset > @offset && (offset - @window_posn) > ref_data_size
            raise DecompressionError, "Match offset beyond LZX stream"
          end

          # Copy from end of window
          src_pos = @window_size - (offset - @window_posn)
          copy_len = offset - @window_posn

          if copy_len < length
            # Copy first part from end of window
            copy_len.times do
              @window.setbyte(@window_posn, @window.getbyte(src_pos))
              @window_posn += 1
              src_pos += 1
            end
            # Copy rest from beginning
            src_pos = 0
            (length - copy_len).times do
              @window.setbyte(@window_posn, @window.getbyte(src_pos))
              @window_posn += 1
              src_pos += 1
            end
          else
            # Copy entirely from end of window
            length.times do
              @window.setbyte(@window_posn, @window.getbyte(src_pos))
              @window_posn += 1
              src_pos += 1
            end
          end
        else
          # Normal copy
          src_pos = @window_posn - offset
          length.times do
            @window.setbyte(@window_posn, @window.getbyte(src_pos))
            @window_posn += 1
            src_pos += 1
          end
        end
      end

      # Decode uncompressed block
      #
      # @param run_length [Integer] Number of bytes to decode
      # @return [void]
      def decode_uncompressed_block(run_length)
        run_length.times do
          byte = @bitstream.read_bits(8)
          @window.setbyte(@window_posn, byte)
          @window_posn += 1
        end
      end

      # Check if Intel E8 transformation should be applied
      #
      # @param frame_size [Integer] Frame size
      # @return [Boolean] true if transformation should be applied
      def should_apply_e8_transform?(frame_size)
        @intel_started &&
          @intel_filesize.positive? &&
          @frame < 32_768 &&
          frame_size > 10
      end

      # Apply Intel E8 transformation
      #
      # @param frame_size [Integer] Frame size
      # @return [String] Transformed data
      def apply_e8_transform(frame_size)
        # Copy frame data to E8 buffer
        @e8_buf[0, frame_size] = @window[@frame_posn, frame_size]

        # Transform E8 calls
        data_pos = 0
        data_end = frame_size - 10
        cur_pos = @offset

        while data_pos < data_end
          # Look for E8 opcode
          unless @e8_buf.getbyte(data_pos) == 0xE8
            data_pos += 1
            cur_pos += 1
            next
          end

          # Read absolute offset (little-endian)
          abs_off = @e8_buf.getbyte(data_pos + 1) |
            (@e8_buf.getbyte(data_pos + 2) << 8) |
            (@e8_buf.getbyte(data_pos + 3) << 16) |
            (@e8_buf.getbyte(data_pos + 4) << 24)

          # Convert to signed
          abs_off -= 0x100000000 if abs_off >= 0x80000000

          # Check if should transform
          if abs_off >= -cur_pos && abs_off < @intel_filesize
            # Calculate relative offset
            rel_off = abs_off >= 0 ? abs_off - cur_pos : abs_off + @intel_filesize

            # Write relative offset (little-endian)
            @e8_buf.setbyte(data_pos + 1, rel_off & 0xFF)
            @e8_buf.setbyte(data_pos + 2, (rel_off >> 8) & 0xFF)
            @e8_buf.setbyte(data_pos + 3, (rel_off >> 16) & 0xFF)
            @e8_buf.setbyte(data_pos + 4, (rel_off >> 24) & 0xFF)
          end

          data_pos += 5
          cur_pos += 5
        end

        @e8_buf[0, frame_size]
      end
    end
  end
end
