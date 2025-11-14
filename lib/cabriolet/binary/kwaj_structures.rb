# frozen_string_literal: true

require "bindata"

module Cabriolet
  module Binary
    # KWAJ file format binary structures
    #
    # KWAJ has a fixed base header followed by optional headers determined
    # by flag bits in the header.
    module KWAJStructures
      # KWAJ base header (14 bytes)
      #
      # Structure:
      # - 4 bytes: signature1 (KWAJ)
      # - 4 bytes: signature2 (0xD127F088)
      # - 2 bytes: compression method
      # - 2 bytes: data offset
      # - 2 bytes: header flags
      class BaseHeader < BinData::Record
        endian :little

        uint32 :signature1
        uint32 :signature2
        uint16 :comp_method
        uint16 :data_offset
        uint16 :flags
      end

      # Optional length field (4 bytes)
      class LengthField < BinData::Record
        endian :little

        uint32 :uncompressed_length
      end

      # Optional unknown field 1 (2 bytes)
      class Unknown1Field < BinData::Record
        endian :little

        uint16 :unknown1
      end

      # Optional unknown field 2 (variable length)
      class Unknown2Field < BinData::Record
        endian :little

        uint16 :data_length
        string :data, read_length: :data_length
      end

      # Optional extra text field (variable length)
      class ExtraTextField < BinData::Record
        endian :little

        uint16 :text_length
        string :data, read_length: :text_length
      end

      # KWAJ signature constants
      SIGNATURE1 = 0x4A41574B # "KWAJ" in little-endian
      SIGNATURE2 = 0xD127F088

      # Helper method to check if a signature is valid
      #
      # @param sig1 [Integer] First signature value
      # @param sig2 [Integer] Second signature value
      # @return [Boolean] true if signatures are valid
      def self.valid_signature?(sig1, sig2)
        sig1 == SIGNATURE1 && sig2 == SIGNATURE2
      end
    end
  end
end
