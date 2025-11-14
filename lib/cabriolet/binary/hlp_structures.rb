# frozen_string_literal: true

require "bindata"

module Cabriolet
  module Binary
    # HLP (Windows Help) file format binary structures
    #
    # NOTE: This implementation is based on the knowledge that HLP files use
    # LZSS compression with MODE_MSHELP, but cannot be fully validated due to
    # lack of test fixtures and incomplete libmspack implementation.
    module HLPStructures
      # HLP file signature (common Windows Help magic)
      # Note: Actual signature may vary; this is a placeholder
      SIGNATURE = "?_\x03\x00".b.freeze

      # HLP file header
      #
      # Structure (placeholder based on typical compressed formats):
      # - 4 bytes: signature/magic
      # - 2 bytes: version
      # - 4 bytes: file count
      # - 4 bytes: directory offset
      class Header < BinData::Record
        endian :little

        string :signature, length: 4
        uint16 :version
        uint32 :file_count
        uint32 :directory_offset
      end

      # HLP file entry in directory
      #
      # Structure:
      # - 4 bytes: filename length
      # - N bytes: filename (null-terminated)
      # - 4 bytes: offset in archive
      # - 4 bytes: uncompressed size
      # - 4 bytes: compressed size
      # - 1 byte: compression flag (0 = uncompressed, 1 = LZSS)
      class FileEntry < BinData::Record
        endian :little

        uint32 :filename_length
        string :filename, read_length: :filename_length
        uint32 :offset
        uint32 :uncompressed_size
        uint32 :compressed_size
        uint8  :compression_flag
      end

      # Topic header (for compressed help topics)
      #
      # Structure:
      # - 4 bytes: uncompressed size
      # - 4 bytes: compressed size
      class TopicHeader < BinData::Record
        endian :little

        uint32 :uncompressed_size
        uint32 :compressed_size
      end
    end
  end
end
