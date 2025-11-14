# frozen_string_literal: true

module Cabriolet
  module SZDD
    # Parser reads and parses SZDD file headers
    #
    # SZDD files are single-file compressed archives using LZSS compression.
    # There are two format variants:
    # - NORMAL: Used by MS-DOS EXPAND.EXE (signature: SZDD\x88\xF0\x27\x33)
    # - QBASIC: Used by QBasic (signature: SZDD \x88\xF0\x27\x33\xD1)
    class Parser
      attr_reader :io_system

      # Expected compression mode for NORMAL format
      COMPRESSION_MODE_NORMAL = 0x41

      # Initialize a new parser
      #
      # @param io_system [System::IOSystem] I/O system for reading
      def initialize(io_system)
        @io_system = io_system
      end

      # Parse an SZDD file and return header information
      #
      # @param filename [String] Path to the SZDD file
      # @return [Models::SZDDHeader] Parsed header
      # @raise [Errors::ParseError] if the file is not a valid SZDD
      def parse(filename)
        handle = @io_system.open(filename, Constants::MODE_READ)
        header = parse_handle(handle, filename)
        @io_system.close(handle)
        header
      end

      # Parse SZDD header from an already-open handle
      #
      # @param handle [System::FileHandle, System::MemoryHandle] Open handle
      # @param filename [String] Filename for reference
      # @return [Models::SZDDHeader] Parsed header
      # @raise [Errors::ParseError] if not a valid SZDD
      def parse_handle(handle, filename = nil)
        # Read signature (8 bytes)
        signature = @io_system.read(handle, 8)
        raise ParseError, "Cannot read SZDD signature" if
          signature.bytesize < 8

        # Determine format based on signature
        if signature == Binary::SZDDStructures::SIGNATURE_NORMAL
          parse_normal_header(handle, filename)
        elsif signature == Binary::SZDDStructures::SIGNATURE_QBASIC
          parse_qbasic_header(handle, filename)
        else
          raise ParseError, "Invalid SZDD signature"
        end
      end

      # Get the data offset for the compressed data
      #
      # @param format [Symbol] Format type (:normal or :qbasic)
      # @return [Integer] Offset in bytes where compressed data starts
      def data_offset(format)
        format == Models::SZDDHeader::FORMAT_NORMAL ? 14 : 12
      end

      private

      # Parse NORMAL format SZDD header (EXPAND.EXE)
      #
      # @param handle [System::FileHandle, System::MemoryHandle] Open handle
      # @param filename [String, nil] Filename for reference
      # @return [Models::SZDDHeader] Parsed header
      # @raise [Errors::ParseError] if header is invalid
      def parse_normal_header(handle, filename)
        # Read remaining header fields (6 bytes)
        # - 1 byte: compression mode (should be 0x41)
        # - 1 byte: missing character
        # - 4 bytes: uncompressed size (little-endian)
        header_data = @io_system.read(handle, 6)
        raise ParseError, "Cannot read SZDD header" if
          header_data.bytesize < 6

        compression_mode = header_data[0].ord
        missing_char = header_data[1].chr
        uncompressed_size = header_data[2..5].unpack1("V") # Little-endian uint32

        # Validate compression mode
        unless compression_mode == COMPRESSION_MODE_NORMAL
          raise ParseError,
                "Invalid compression mode: #{compression_mode}"
        end

        # Create header model
        Models::SZDDHeader.new(
          format: Models::SZDDHeader::FORMAT_NORMAL,
          length: uncompressed_size,
          missing_char: missing_char,
          filename: filename,
        )
      end

      # Parse QBASIC format SZDD header
      #
      # @param handle [System::FileHandle, System::MemoryHandle] Open handle
      # @param filename [String, nil] Filename for reference
      # @return [Models::SZDDHeader] Parsed header
      # @raise [Errors::ParseError] if header is invalid
      def parse_qbasic_header(handle, filename)
        # Read remaining header fields (4 bytes)
        # - 4 bytes: uncompressed size (little-endian)
        header_data = @io_system.read(handle, 4)
        raise ParseError, "Cannot read SZDD header" if
          header_data.bytesize < 4

        uncompressed_size = header_data.unpack1("V") # Little-endian uint32

        # Create header model (no missing character in QBASIC format)
        Models::SZDDHeader.new(
          format: Models::SZDDHeader::FORMAT_QBASIC,
          length: uncompressed_size,
          missing_char: nil,
          filename: filename,
        )
      end
    end
  end
end
