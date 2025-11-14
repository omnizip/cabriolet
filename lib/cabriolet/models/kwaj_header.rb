# frozen_string_literal: true

module Cabriolet
  module Models
    # Represents a KWAJ file header
    #
    # KWAJ files support multiple compression methods and optional headers
    # determined by flag bits. The header structure is more flexible than SZDD.
    class KWAJHeader
      # Compression type
      # @return [Integer] One of KWAJ_COMP_* constants
      attr_accessor :comp_type

      # Offset to compressed data
      # @return [Integer] Byte offset where compressed data starts
      attr_accessor :data_offset

      # Header flags
      # @return [Integer] Bitfield indicating which optional headers are present
      attr_accessor :headers

      # Uncompressed length
      # @return [Integer, nil] Length of uncompressed data if present
      attr_accessor :length

      # Original filename
      # @return [String, nil] Original filename if present
      attr_accessor :filename

      # Extra text data
      # @return [String, nil] Extra text data if present
      attr_accessor :extra

      # Length of extra data
      # @return [Integer] Number of bytes in extra data
      attr_accessor :extra_length

      # Initialize a new KWAJ header
      def initialize
        @comp_type = Constants::KWAJ_COMP_NONE
        @data_offset = 0
        @headers = 0
        @length = nil
        @filename = nil
        @extra = nil
        @extra_length = 0
      end

      # Get human-readable compression type name
      #
      # @return [String] Compression type name
      def compression_name
        case @comp_type
        when Constants::KWAJ_COMP_NONE
          "None"
        when Constants::KWAJ_COMP_XOR
          "XOR"
        when Constants::KWAJ_COMP_SZDD
          "SZDD"
        when Constants::KWAJ_COMP_LZH
          "LZH"
        when Constants::KWAJ_COMP_MSZIP
          "MSZIP"
        else
          "Unknown (#{@comp_type})"
        end
      end

      # Check if header has length field
      #
      # @return [Boolean] true if length is present
      def has_length?
        @headers.anybits?(Constants::KWAJ_HDR_HASLENGTH)
      end

      # Check if header has filename
      #
      # @return [Boolean] true if filename is present
      def has_filename?
        @headers.anybits?(Constants::KWAJ_HDR_HASFILENAME)
      end

      # Check if header has file extension
      #
      # @return [Boolean] true if file extension is present
      def has_file_extension?
        @headers.anybits?(Constants::KWAJ_HDR_HASFILEEXT)
      end

      # Check if header has extra text
      #
      # @return [Boolean] true if extra text is present
      def has_extra_text?
        @headers.anybits?(Constants::KWAJ_HDR_HASEXTRATEXT)
      end
    end
  end
end
