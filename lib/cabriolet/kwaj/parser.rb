# frozen_string_literal: true

module Cabriolet
  module KWAJ
    # Parser reads and parses KWAJ file headers
    #
    # KWAJ files support multiple compression methods and have variable-length
    # headers with optional fields determined by flag bits.
    class Parser
      attr_reader :io_system

      # Initialize a new parser
      #
      # @param io_system [System::IOSystem] I/O system for reading
      def initialize(io_system)
        @io_system = io_system
      end

      # Parse a KWAJ file and return header information
      #
      # @param filename [String] Path to the KWAJ file
      # @return [Models::KWAJHeader] Parsed header
      # @raise [Errors::ParseError] if the file is not a valid KWAJ
      def parse(filename)
        handle = @io_system.open(filename, Constants::MODE_READ)
        header = parse_handle(handle)
        @io_system.close(handle)
        header
      end

      # Parse KWAJ header from an already-open handle
      #
      # @param handle [System::FileHandle, System::MemoryHandle] Open handle
      # @return [Models::KWAJHeader] Parsed header
      # @raise [Errors::ParseError] if not a valid KWAJ
      def parse_handle(handle)
        # Read base header (14 bytes)
        base_data = @io_system.read(handle, 14)
        raise ParseError, "Cannot read KWAJ header" if base_data.bytesize < 14

        # Parse base header
        base = Binary::KWAJStructures::BaseHeader.read(base_data)

        # Verify signature
        unless Binary::KWAJStructures.valid_signature?(
          base.signature1, base.signature2
        )
          raise ParseError, "Invalid KWAJ signature"
        end

        # Create header model
        header = Models::KWAJHeader.new
        header.comp_type = base.comp_method
        header.data_offset = base.data_offset
        header.headers = base.flags

        # Parse optional headers based on flags
        parse_optional_headers(handle, header)

        header
      end

      private

      # Parse optional headers based on flag bits
      #
      # @param handle [System::FileHandle, System::MemoryHandle] Open handle
      # @param header [Models::KWAJHeader] Header to populate
      # @return [void]
      # @raise [Errors::ParseError] if header parsing fails
      def parse_optional_headers(handle, header)
        # Optional length field (4 bytes)
        if header.has_length?
          data = @io_system.read(handle, 4)
          raise ParseError, "Cannot read length field" if data.bytesize < 4

          header.length = data.unpack1("V") # Little-endian uint32
        end

        # Optional unknown field 1 (2 bytes)
        if header.headers.anybits?(Constants::KWAJ_HDR_HASUNKNOWN1)
          data = @io_system.read(handle, 2)
          raise ParseError, "Cannot read unknown1 field" if data.bytesize < 2
          # We read it but don't store it
        end

        # Optional unknown field 2 (variable length)
        if header.headers.anybits?(Constants::KWAJ_HDR_HASUNKNOWN2)
          data = @io_system.read(handle, 2)
          raise ParseError, "Cannot read unknown2 length" if data.bytesize < 2

          length = data.unpack1("v") # Little-endian uint16

          # Skip the unknown data
          if length.positive?
            skip_data = @io_system.read(handle, length)
            if skip_data.bytesize < length
              raise ParseError,
                    "Cannot read unknown2 data"
            end
          end
        end

        # Optional filename and extension
        if header.has_filename? || header.has_file_extension?
          parse_filename(handle,
                         header)
        end

        # Optional extra text (variable length)
        return unless header.has_extra_text?

        data = @io_system.read(handle, 2)
        raise ParseError, "Cannot read extra text length" if
          data.bytesize < 2

        length = data.unpack1("v") # Little-endian uint16

        return unless length.positive?

        extra_data = @io_system.read(handle, length)
        if extra_data.bytesize < length
          raise ParseError,
                "Cannot read extra text data"
        end

        header.extra = extra_data
        header.extra_length = length
      end

      # Parse filename and extension fields
      #
      # @param handle [System::FileHandle, System::MemoryHandle] Open handle
      # @param header [Models::KWAJHeader] Header to populate
      # @return [void]
      # @raise [Errors::ParseError] if filename parsing fails
      def parse_filename(handle, header)
        filename_parts = []

        # Read filename (up to 9 bytes, null-terminated)
        if header.has_filename?
          name_data = @io_system.read(handle, 9)
          raise ParseError, "Cannot read filename" if name_data.empty?

          # Find null terminator or end of data
          null_pos = name_data.index("\x00")
          raise ParseError, "Filename not null-terminated" unless null_pos

          filename_parts << name_data[0...null_pos]
          # Seek back to position after null terminator
          bytes_to_skip = null_pos + 1 - name_data.bytesize
          @io_system.seek(handle, bytes_to_skip, Constants::SEEK_CUR) if
            bytes_to_skip != 0

          # No null terminator in 9 bytes is an error

        end

        # Read extension (up to 4 bytes, null-terminated)
        if header.has_file_extension?
          ext_data = @io_system.read(handle, 4)
          raise ParseError, "Cannot read file extension" if ext_data.empty?

          # Find null terminator or end of data
          null_pos = ext_data.index("\x00")
          raise ParseError, "File extension not null-terminated" unless null_pos

          extension = ext_data[0...null_pos]
          filename_parts << ".#{extension}" unless extension.empty?
          # Seek back to position after null terminator
          bytes_to_skip = null_pos + 1 - ext_data.bytesize
          @io_system.seek(handle, bytes_to_skip, Constants::SEEK_CUR) if
            bytes_to_skip != 0

          # No null terminator in 4 bytes is an error

        end

        header.filename = filename_parts.join unless filename_parts.empty?
      end
    end
  end
end
