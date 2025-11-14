# frozen_string_literal: true

module Cabriolet
  module Models
    # OAB (Outlook Offline Address Book) file header
    #
    # OAB files come in two variants:
    # - Full files (version 3.1)
    # - Incremental patches (version 3.2)
    class OABHeader
      attr_accessor :version_hi, :version_lo, :block_max, :target_size, :source_size, :source_crc, :target_crc,
                    :is_patch

      # Create new OAB header
      #
      # @param version_hi [Integer] High version number
      # @param version_lo [Integer] Low version number (1=full, 2=patch)
      # @param block_max [Integer] Maximum block size
      # @param target_size [Integer] Decompressed output size
      # @param source_size [Integer] Base file size (patches only)
      # @param source_crc [Integer] Base file CRC (patches only)
      # @param target_crc [Integer] Target file CRC (patches only)
      def initialize(version_hi:, version_lo:, block_max:, target_size:,
                     source_size: nil, source_crc: nil, target_crc: nil)
        @version_hi = version_hi
        @version_lo = version_lo
        @block_max = block_max
        @target_size = target_size
        @source_size = source_size
        @source_crc = source_crc
        @target_crc = target_crc
        @is_patch = (version_lo == 2)
      end

      # Check if this is a valid OAB header
      #
      # @return [Boolean]
      def valid?
        version_hi == 3 && [1, 2].include?(version_lo)
      end

      # Check if this is an incremental patch
      #
      # @return [Boolean]
      def patch?
        is_patch
      end

      # Check if this is a full file
      #
      # @return [Boolean]
      def full?
        !is_patch
      end
    end

    # OAB block header for full files
    class OABBlockHeader
      attr_accessor :flags, :compressed_size, :uncompressed_size, :crc

      def initialize(flags:, compressed_size:, uncompressed_size:, crc:)
        @flags = flags
        @compressed_size = compressed_size
        @uncompressed_size = uncompressed_size
        @crc = crc
      end

      # Check if block is compressed
      #
      # @return [Boolean]
      def compressed?
        flags == 1
      end

      # Check if block is uncompressed
      #
      # @return [Boolean]
      def uncompressed?
        flags.zero?
      end
    end

    # OAB block header for patch files
    class OABPatchBlockHeader
      attr_accessor :patch_size, :target_size, :source_size, :crc

      def initialize(patch_size:, target_size:, source_size:, crc:)
        @patch_size = patch_size
        @target_size = target_size
        @source_size = source_size
        @crc = crc
      end
    end
  end
end
