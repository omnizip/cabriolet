# frozen_string_literal: true

module Cabriolet
  module Models
    # HLP file header model
    #
    # NOTE: This implementation is based on the knowledge that HLP files use
    # LZSS compression with MODE_MSHELP, but cannot be fully validated due to
    # lack of test fixtures. Testing relies on round-trip
    # compression/decompression and comparison with libmspack tools if
    # available.
    class HLPHeader
      attr_accessor :magic, :version, :filename, :length, :files

      # Initialize HLP header
      #
      # @param magic [String] Magic number (should be specific to HLP)
      # @param version [Integer] Format version
      # @param filename [String] Original filename
      # @param length [Integer] Uncompressed file length
      def initialize(magic: nil, version: nil, filename: nil, length: 0)
        @magic = magic
        @version = version
        @filename = filename
        @length = length
        @files = []
      end

      # Check if header is valid
      #
      # @return [Boolean] true if header appears valid
      def valid?
        !@magic.nil? && !@version.nil?
      end
    end
  end
end
