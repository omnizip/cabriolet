# frozen_string_literal: true

require "bindata"

module Cabriolet
  module Binary
    # Microsoft Reader LIT file format binary structures
    #
    # NOTE: LIT format specifications are not publicly documented.
    # These structures are based on analysis and reverse engineering.
    # DES-encrypted (DRM-protected) LIT files are not supported.
    module LITStructures
      # LIT file signature: "ITOLITLS" or similar variants
      # The actual signature may vary based on LIT version
      SIGNATURE = "ITOLITLS"

      # LIT file header
      #
      # Structure (approximate):
      # - 8 bytes: signature
      # - 4 bytes: version
      # - 4 bytes: flags (includes encryption flag)
      # - 4 bytes: file count
      # - 4 bytes: header size
      class LITHeader < BinData::Record
        endian :little

        string :signature, length: 8
        uint32 :version
        uint32 :flags
        uint32 :file_count
        uint32 :header_size
      end

      # LIT file entry in the directory
      #
      # Structure (approximate):
      # - 4 bytes: filename length
      # - N bytes: filename (UTF-8 or UTF-16)
      # - 8 bytes: file offset
      # - 8 bytes: compressed size
      # - 8 bytes: uncompressed size
      # - 4 bytes: flags (compressed, encrypted, etc.)
      class LITFileEntry < BinData::Record
        endian :little

        uint32 :filename_length
        string :filename, read_length: :filename_length
        uint64 :offset
        uint64 :compressed_size
        uint64 :uncompressed_size
        uint32 :flags
      end

      # LIT content section header
      #
      # Structure (approximate):
      # - 4 bytes: section type
      # - 4 bytes: section size
      # - 4 bytes: compression method (0 = none, 1 = LZX)
      # - 4 bytes: encryption method (0 = none, 1 = DES)
      class SectionHeader < BinData::Record
        endian :little

        uint32 :section_type
        uint32 :section_size
        uint32 :compression_method
        uint32 :encryption_method
      end

      # DES encryption header (if encrypted)
      #
      # NOTE: DES encryption is not currently supported.
      # This structure is provided for completeness.
      #
      # Structure (approximate):
      # - 16 bytes: encryption key hash
      # - 8 bytes: IV (initialization vector)
      # - 4 bytes: encryption flags
      class EncryptionHeader < BinData::Record
        endian :little

        string :key_hash, length: 16
        string :iv, length: 8
        uint32 :flags
      end

      # Flags for file entries
      module FileFlags
        COMPRESSED = 0x01
        ENCRYPTED  = 0x02
      end

      # Compression methods
      module CompressionMethod
        NONE = 0
        LZX  = 1
      end

      # Encryption methods
      module EncryptionMethod
        NONE = 0
        DES  = 1
      end
    end
  end
end
