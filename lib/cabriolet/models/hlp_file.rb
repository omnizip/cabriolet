# frozen_string_literal: true

module Cabriolet
  module Models
    # HLP internal file model
    #
    # Represents a file within an HLP archive. HLP files contain an internal
    # file system where each file can be compressed using LZSS MODE_MSHELP.
    class HLPFile
      attr_accessor :filename, :offset, :length, :compressed_length,
                    :compressed, :data

      # Initialize HLP file
      #
      # @param filename [String] File name within the HLP archive
      # @param offset [Integer] Offset in the HLP archive
      # @param length [Integer] Uncompressed file length
      # @param compressed_length [Integer] Compressed file length
      # @param compressed [Boolean] Whether the file is compressed
      def initialize(filename: nil, offset: 0, length: 0,
                     compressed_length: 0, compressed: true)
        @filename = filename
        @offset = offset
        @length = length
        @compressed_length = compressed_length
        @compressed = compressed
        @data = nil
      end

      # Check if file is compressed
      #
      # @return [Boolean] true if file is compressed
      def compressed?
        @compressed
      end

      # Get the size to read from archive
      #
      # @return [Integer] Size to read (compressed or uncompressed)
      def read_size
        compressed? ? @compressed_length : @length
      end
    end
  end
end
