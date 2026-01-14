# frozen_string_literal: true

require_relative "../binary/chm_structures"
require_relative "../models/chm_header"
require_relative "../models/chm_file"
require_relative "../errors"

module Cabriolet
  module CHM
    # Parser for CHM (Compiled HTML Help) files
    class Parser
      # Expected GUID values in CHM headers
      GUID1 = [0x10, 0xFD, 0x01, 0x7C, 0xAA, 0x7B, 0xD0, 0x11,
               0x9E, 0x0C, 0x00, 0xA0, 0xC9, 0x22, 0xE6, 0xEC].pack("C*")
      GUID2 = [0x11, 0xFD, 0x01, 0x7C, 0xAA, 0x7B, 0xD0, 0x11,
               0x9E, 0x0C, 0x00, 0xA0, 0xC9, 0x22, 0xE6, 0xEC].pack("C*")

      # System file names
      CONTENT_NAME = "::DataSpace/Storage/MSCompressed/Content"
      CONTROL_NAME = "::DataSpace/Storage/MSCompressed/ControlData"
      SPANINFO_NAME = "::DataSpace/Storage/MSCompressed/SpanInfo"
      RTABLE_NAME = "::DataSpace/Storage/MSCompressed/Transform/" \
                    "{7FC28940-9D31-11D0-9B27-00A0C91E9C7C}/InstanceData/ResetTable"

      attr_reader :io, :chm

      def initialize(io)
        @io = io
        @chm = Models::CHMHeader.new
      end

      # Parse the CHM file
      # @param entire [Boolean] If true, parse all file entries. If false, only headers.
      # @return [Models::CHMHeader]
      def parse(entire: true)
        read_itsf_header
        read_header_sections
        read_directory_header

        read_file_entries if entire

        @chm
      end

      private

      # Read the ITSF header (main file header)
      def read_itsf_header
        @io.seek(0, Constants::SEEK_START)
        header = Binary::CHMITSFHeader.read(@io)

        # Check signature
        unless header.signature == "ITSF"
          raise SignatureError,
                "Invalid ITSF signature"
        end

        # Check GUIDs
        # Note: Some CHM files have both GUIDs set to GUID1 (unusual but valid)
        # Standard files have GUID1 and GUID2 as expected
        # We validate that guid2 matches either GUID1 or GUID2
        unless [GUID1, GUID2].include?(header.guid2)
          raise SignatureError,
                "Invalid CHM GUIDs (guid2 should match CHM format GUID)"
        end

        @chm.version = header.version
        @chm.timestamp = header.timestamp
        @chm.language = header.language_id
      end

      # Read header sections table and header section 0
      def read_header_sections
        section_table = Binary::CHMHeaderSectionTable.read(@io)

        offset_hs0 = section_table.offset_hs0
        @chm.dir_offset = section_table.offset_hs1
        @chm.sec0.offset = section_table.offset_cs0

        # Seek to header section 0
        @io.seek(offset_hs0, Constants::SEEK_START)
        hs0 = Binary::CHMHeaderSection0.read(@io)
        @chm.length = hs0.file_len
      end

      # Read header section 1 (directory header)
      def read_directory_header
        @io.seek(@chm.dir_offset, Constants::SEEK_START)
        hs1 = Binary::CHMHeaderSection1.read(@io)

        # Check signature
        unless hs1.signature == "ITSP"
          raise SignatureError,
                "Invalid ITSP signature"
        end

        @chm.dir_offset = @io.tell
        @chm.chunk_size = hs1.chunk_size
        @chm.density = hs1.density
        @chm.depth = hs1.depth
        @chm.index_root = hs1.index_root
        @chm.num_chunks = hs1.num_chunks
        @chm.first_pmgl = hs1.first_pmgl
        @chm.last_pmgl = hs1.last_pmgl

        # For CHM versions < 3, calculate section 0 offset
        @chm.sec0.offset = @chm.dir_offset + (@chm.chunk_size * @chm.num_chunks) if @chm.version < 3

        validate_chunk_parameters
      end

      # Validate chunk parameters
      def validate_chunk_parameters
        # Check if content offset is valid
        if @chm.sec0.offset > @chm.length
          raise FormatError,
                "Content section offset beyond file length"
        end

        # Chunk size must be large enough
        raise FormatError, "Chunk size too small" if @chm.chunk_size < 20

        # Must have chunks
        raise FormatError, "No chunks in CHM file" if @chm.num_chunks.zero?

        # Sanity limits
        if @chm.num_chunks > 100_000
          raise FormatError,
                "Too many chunks (> 100,000)"
        end

        if @chm.chunk_size > 8192
          raise FormatError,
                "Chunk size too large (> 8192)"
        end

        # Validate chunk indices
        if @chm.first_pmgl > @chm.last_pmgl
          raise FormatError,
                "First PMGL > Last PMGL"
        end

        return unless @chm.index_root != 0xFFFFFFFF && @chm.index_root >= @chm.num_chunks

        raise FormatError, "Index root out of range"
      end

      # Read all file entries from PMGL chunks
      def read_file_entries
        # Seek to first PMGL chunk
        if @chm.first_pmgl != 0
          pmgl_offset = @chm.first_pmgl * @chm.chunk_size
          @io.seek(@chm.dir_offset + pmgl_offset, Constants::SEEK_START)
        end

        num_chunks = @chm.last_pmgl - @chm.first_pmgl + 1
        last_file = nil

        num_chunks.times do
          chunk = @io.read(@chm.chunk_size)
          next unless chunk && chunk.length == @chm.chunk_size

          # Check if this is a PMGL chunk
          next unless chunk[0, 4] == "PMGL"

          files = parse_pmgl_chunk(chunk)
          files.each do |file|
            if file.system_file?
              # Add to system files list
              file.next_file = @chm.sysfiles
              @chm.sysfiles = file
              identify_system_file(file)
            else
              # Add to regular files list
              if last_file
                last_file.next_file = file
              else
                @chm.files = file
              end
              last_file = file
            end
          end
        end
      end

      # Parse a PMGL chunk to extract file entries
      # @param chunk [String] The chunk data
      # @return [Array<Models::CHMFile>] The files found in this chunk
      def parse_pmgl_chunk(chunk)
        files = []

        # Read number of entries (last 2 bytes)
        num_entries = chunk[-2, 2].unpack1("v")

        # Start reading entries after PMGL header
        pos = 20 # PMGL header is 20 bytes
        chunk_end = chunk.length - 2

        num_entries.times do
          break if pos >= chunk_end

          begin
            # Read name length
            name_len, pos = Binary::ENCINTReader.read_from_string(chunk, pos)
            break if pos + name_len > chunk_end

            # Read name
            name = chunk[pos, name_len]
            pos += name_len

            # Read section, offset, length
            section, pos = Binary::ENCINTReader.read_from_string(chunk, pos)
            offset, pos = Binary::ENCINTReader.read_from_string(chunk, pos)
            length, pos = Binary::ENCINTReader.read_from_string(chunk, pos)

            # Skip blank or single-char names
            next if name_len < 2 || name[0].nil? || name[1].nil?

            # Skip directory entries (end with '/')
            next if offset.zero? && length.zero? && name[-1] == "/"

            # Validate section number
            next if section > 1

            # Create file entry
            file = Models::CHMFile.new
            file.filename = name.force_encoding("UTF-8")
            file.section = (section.zero? ? @chm.sec0 : @chm.sec1)
            file.offset = offset
            file.length = length

            files << file
          rescue Cabriolet::FormatError
            # Skip malformed entries
            break
          end
        end

        files
      end

      # Identify and link system files
      def identify_system_file(file)
        case file.filename
        when CONTENT_NAME
          @chm.sec1.content = file
        when CONTROL_NAME
          @chm.sec1.control = file
        when SPANINFO_NAME
          @chm.sec1.spaninfo = file
        when RTABLE_NAME
          @chm.sec1.rtable = file
        end
      end
    end
  end
end
