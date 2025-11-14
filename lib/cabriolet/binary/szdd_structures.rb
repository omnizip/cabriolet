# frozen_string_literal: true

require "bindata"

module Cabriolet
  module Binary
    # SZDD file format binary structures
    module SZDDStructures
      # SZDD signatures
      SIGNATURE_NORMAL = [0x53, 0x5A, 0x44, 0x44, 0x88, 0xF0, 0x27, 0x33]
        .pack("C*").freeze
      SIGNATURE_QBASIC = [0x53, 0x5A, 0x20, 0x88, 0xF0, 0x27, 0x33, 0xD1]
        .pack("C*").freeze

      # SZDD header for NORMAL format (EXPAND.EXE)
      #
      # Structure:
      # - 8 bytes: signature (SZDD\x88\xF0\x27\x33)
      # - 1 byte: compression mode (0x41)
      # - 1 byte: missing character
      # - 4 bytes: uncompressed size (little-endian)
      class NormalHeader < BinData::Record
        endian :little

        string :signature, length: 8
        uint8  :compression_mode
        uint8  :missing_char
        uint32 :uncompressed_size
      end

      # SZDD header for QBASIC format
      #
      # Structure:
      # - 8 bytes: signature (SZDD \x88\xF0\x27\x33\xD1)
      # - 4 bytes: uncompressed size (little-endian)
      class QBasicHeader < BinData::Record
        endian :little

        string :signature, length: 8
        uint32 :uncompressed_size
      end

      # Header data for NORMAL format (after signature)
      class NormalData < BinData::Record
        endian :little

        uint8  :compression_mode
        uint8  :missing_char
        uint32 :uncompressed_size
      end

      # Header data for QBASIC format (after signature)
      class QBasicData < BinData::Record
        endian :little

        uint32 :uncompressed_size
      end
    end
  end
end
