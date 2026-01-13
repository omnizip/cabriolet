# frozen_string_literal: true

module Cabriolet
  module Models
    # Represents an SZDD file header
    #
    # SZDD files are single-file compressed archives using LZSS compression.
    # They were commonly used with MS-DOS COMPRESS.EXE and EXPAND.EXE commands.
    class SZDDHeader
      # SZDD format types
      FORMAT_NORMAL = :normal
      FORMAT_QBASIC = :qbasic

      # Format of the SZDD file (:normal or :qbasic)
      # @return [Symbol]
      attr_accessor :format

      # Uncompressed file size in bytes
      # @return [Integer]
      attr_accessor :length

      # Missing character from the original filename (NORMAL format only)
      # Commonly the last character (e.g., 't' in 'file.txt' -> 'file.tx_')
      # @return [String, nil]
      attr_accessor :missing_char

      # Original or suggested filename
      # @return [String, nil]
      attr_accessor :filename

      # Initialize a new SZDD header
      #
      # @param format [Symbol] Format type (:normal or :qbasic)
      # @param length [Integer] Uncompressed size
      # @param missing_char [String, nil] Missing filename character
      # @param filename [String, nil] Original filename
      def initialize(format: FORMAT_NORMAL, length: 0, missing_char: nil,
                     filename: nil)
        @format = format
        @length = length
        @missing_char = missing_char
        @filename = filename
      end

      # Check if this is a NORMAL format SZDD file
      #
      # @return [Boolean]
      def normal_format?
        @format == FORMAT_NORMAL
      end

      # Check if this is a QBASIC format SZDD file
      #
      # @return [Boolean]
      def qbasic_format?
        @format == FORMAT_QBASIC
      end

      # Generate suggested output filename from compressed filename
      #
      # @param compressed_filename [String] The compressed filename
      # @return [String] Suggested output filename
      def suggested_filename(compressed_filename)
        return compressed_filename unless normal_format? && @missing_char

        # Replace trailing underscore with missing character
        # SZDD headers store the missing character in lowercase,
        # but DOS filenames are traditionally uppercase
        missing_char_upper = @missing_char.upcase
        compressed_filename.sub(/\.(\w+)_$/, ".\\1#{missing_char_upper}")
      end
    end
  end
end
