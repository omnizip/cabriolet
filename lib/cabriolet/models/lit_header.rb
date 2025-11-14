# frozen_string_literal: true

module Cabriolet
  module Models
    # Represents the header of a Microsoft Reader LIT file
    #
    # LIT files are Microsoft Reader eBook files that use LZX compression
    # and may use DES encryption for DRM-protected content.
    class LITHeader
      attr_accessor :version, :filename, :length, :encrypted, :files

      def initialize
        @version = 0
        @filename = ""
        @length = 0
        @encrypted = false
        @files = []
      end

      # Check if the LIT file is encrypted
      #
      # @return [Boolean] true if the file uses DES encryption
      def encrypted?
        @encrypted
      end
    end

    # Represents a file entry within a LIT archive
    class LITFile
      attr_accessor :filename, :offset, :length, :compressed, :encrypted

      def initialize
        @filename = ""
        @offset = 0
        @length = 0
        @compressed = true
        @encrypted = false
      end

      # Check if the file is compressed
      #
      # @return [Boolean] true if the file uses LZX compression
      def compressed?
        @compressed
      end

      # Check if the file is encrypted
      #
      # @return [Boolean] true if the file uses DES encryption
      def encrypted?
        @encrypted
      end
    end
  end
end
