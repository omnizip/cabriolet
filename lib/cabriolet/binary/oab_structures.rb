# frozen_string_literal: true

require "bindata"

module Cabriolet
  module Binary
    # OAB (Outlook Offline Address Book) binary structures
    #
    # OAB files use LZX compression and come in two formats:
    # - Full files (version 3.1)
    # - Incremental patches (version 3.2)
    module OABStructures
      # OAB header for full files (version 3.1)
      #
      # Structure (16 bytes):
      # - 4 bytes: version_hi (should be 3)
      # - 4 bytes: version_lo (should be 1 for full files)
      # - 4 bytes: block_max (maximum block size)
      # - 4 bytes: target_size (decompressed output size)
      class FullHeader < BinData::Record
        endian :little

        uint32 :version_hi
        uint32 :version_lo
        uint32 :block_max
        uint32 :target_size

        # Check if header is valid
        #
        # @return [Boolean]
        def valid?
          version_hi == 3 && version_lo == 1
        end
      end

      # OAB block header for full files
      #
      # Structure (16 bytes):
      # - 4 bytes: flags (0=uncompressed, 1=LZX compressed)
      # - 4 bytes: compressed_size
      # - 4 bytes: uncompressed_size
      # - 4 bytes: crc (CRC32 of decompressed data)
      class BlockHeader < BinData::Record
        endian :little

        uint32 :flags
        uint32 :compressed_size
        uint32 :uncompressed_size
        uint32 :crc

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

      # OAB header for patch files (version 3.2)
      #
      # Structure (28 bytes):
      # - 4 bytes: version_hi (should be 3)
      # - 4 bytes: version_lo (should be 2 for patches)
      # - 4 bytes: block_max (maximum block size)
      # - 4 bytes: source_size (base file size)
      # - 4 bytes: target_size (output file size)
      # - 4 bytes: source_crc (CRC32 of base file)
      # - 4 bytes: target_crc (CRC32 of output file)
      class PatchHeader < BinData::Record
        endian :little

        uint32 :version_hi
        uint32 :version_lo
        uint32 :block_max
        uint32 :source_size
        uint32 :target_size
        uint32 :source_crc
        uint32 :target_crc

        # Check if header is valid
        #
        # @return [Boolean]
        def valid?
          version_hi == 3 && version_lo == 2
        end
      end

      # OAB block header for patch files
      #
      # Structure (20 bytes):
      # - 4 bytes: flags (0=uncompressed, 1=LZX compressed)
      # - 4 bytes: patch_size (compressed patch data size)
      # - 4 bytes: target_size (decompressed output block size)
      # - 4 bytes: source_size (base data needed for this block)
      # - 4 bytes: crc (CRC32 of decompressed output)
      class PatchBlockHeader < BinData::Record
        endian :little

        uint32 :flags
        uint32 :patch_size
        uint32 :target_size
        uint32 :source_size
        uint32 :crc

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
    end
  end
end
