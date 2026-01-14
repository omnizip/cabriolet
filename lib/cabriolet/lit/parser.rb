# frozen_string_literal: true

require_relative "../binary/lit_structures"
require_relative "../models/lit_header"
require_relative "../errors"

module Cabriolet
  module LIT
    # Parser for Microsoft Reader LIT files
    #
    # Handles parsing of the complex LIT file structure including:
    # - Primary and secondary headers with piece table
    # - IFCM/AOLL/AOLI directory chunks with encoded integers
    # - DataSpace sections with transform layers
    # - Manifest file with filename mappings
    #
    # Based on the openclit/SharpLit reference implementation.
    class Parser
      attr_reader :io_system

      def initialize(io_system = nil)
        @io_system = io_system || System::IOSystem.new
      end

      # Parse a LIT file and return the model
      #
      # @param filename [String] Path to LIT file
      # @return [Models::LITFile] Parsed LIT file structure
      # @raise [Errors::ParseError] if file is invalid or unsupported
      def parse(filename)
        handle = @io_system.open(filename, Constants::MODE_READ)

        begin
          lit_file = Models::LITFile.new

          # Parse primary header
          parse_primary_header(handle, lit_file)

          # Parse pieces
          pieces = parse_pieces(handle, lit_file)

          # Parse secondary header
          parse_secondary_header(handle, lit_file, pieces)

          # Parse directory from piece 1
          parse_directory(handle, lit_file, pieces[1])

          # Parse sections
          parse_sections(handle, lit_file)

          # Parse manifest
          parse_manifest(handle, lit_file)

          lit_file
        ensure
          @io_system.close(handle) if handle
        end
      end

      private

      # Parse primary header (40 bytes)
      def parse_primary_header(handle, lit_file)
        @io_system.seek(handle, 0, Constants::SEEK_START)
        header_data = @io_system.read(handle, 40)

        header = Binary::LITStructures::PrimaryHeader.read(header_data)

        # Verify signature
        unless header.signature == Binary::LITStructures::SIGNATURE
          raise Cabriolet::ParseError,
                "Invalid LIT signature: #{header.signature.inspect}"
        end

        # Verify version
        unless header.version == 1
          raise Cabriolet::ParseError,
                "Unsupported LIT version #{header.version}, only version 1 is supported"
        end

        # Store header info
        lit_file.version = header.version
        lit_file.header_guid = header.header_guid

        [header, header.num_pieces, header.secondary_header_length]
      end

      # Parse piece structures
      def parse_pieces(handle, lit_file)
        _, num_pieces, = parse_primary_header(handle, lit_file)

        # Skip to pieces (after primary header)
        @io_system.seek(handle, 40, Constants::SEEK_START)

        pieces = []
        num_pieces.times do
          piece_data = @io_system.read(handle, 16)
          piece = Binary::LITStructures::PieceStructure.read(piece_data)

          # Verify no 64-bit values
          if piece.offset_high != 0 || piece.size_high != 0
            raise Cabriolet::ParseError,
                  "64-bit piece values not supported"
          end

          pieces << {
            offset: piece.offset_low,
            size: piece.size_low,
          }
        end

        # Read piece data
        pieces.each_with_index do |piece, index|
          @io_system.seek(handle, piece[:offset], Constants::SEEK_START)
          piece[:data] = @io_system.read(handle, piece[:size])

          # Store GUIDs from pieces 3 and 4
          case index
          when 3
            lit_file.piece3_guid = piece[:data]
          when 4
            lit_file.piece4_guid = piece[:data]
          end
        end

        pieces
      end

      # Parse secondary header (SECHDR + CAOL + ITSF)
      def parse_secondary_header(handle, lit_file, pieces)
        _, num_pieces, sec_hdr_len = parse_primary_header(handle, lit_file)

        # Calculate content_offset: the content starts after all pieces
        # Primary header: 40 bytes
        # Piece structures: 5 * 16 = 80 bytes
        # Secondary header: variable (sec_hdr_len)
        # Then pieces 0-4 data
        # Content starts after the last piece
        if pieces&.length&.positive?
          last_piece = pieces.last
          lit_file.content_offset = last_piece[:offset] + last_piece[:size]
        else
          # Fallback calculation
          offset = 40 + (num_pieces * 16)
          @io_system.seek(handle, offset, Constants::SEEK_START)
          sec_hdr_data = @io_system.read(handle, sec_hdr_len)
          sec_hdr = Binary::LITStructures::SecondaryHeader.read(sec_hdr_data)
          lit_file.content_offset = sec_hdr.content_offset
        end

        lit_file.timestamp = 0
        lit_file.language_id = 0x409
        lit_file.creator_id = 0
        lit_file.entry_chunklen = 0x2000
        lit_file.count_chunklen = 0x200
        lit_file.entry_unknown = 0x100000
        lit_file.count_unknown = 0x20000
      end

      # Parse directory structure from piece 1
      def parse_directory(_handle, lit_file, piece)
        data = piece[:data]
        return unless data

        # Parse IFCM header
        ifcm = Binary::LITStructures::IFCMHeader.read(data[0, 32])

        unless ifcm.tag == Binary::LITStructures::Tags::IFCM
          raise Cabriolet::ParseError,
                "Invalid IFCM tag: #{format('0x%08X', ifcm.tag)}"
        end

        # Create directory model
        directory = Models::LITDirectory.new
        directory.num_chunks = ifcm.num_chunks
        directory.entry_chunklen = lit_file.entry_chunklen
        directory.count_chunklen = lit_file.count_chunklen
        directory.entries = []

        # Parse each chunk
        chunk_size = ifcm.chunk_size
        ifcm.num_chunks.times do |chunk_idx|
          chunk_offset = 32 + (chunk_idx * chunk_size)
          chunk_data = data[chunk_offset, chunk_size]

          parse_directory_chunk(chunk_data, chunk_size, directory)
        end

        lit_file.directory = directory
      end

      # Parse a single directory chunk (AOLL or AOLI)
      def parse_directory_chunk(data, chunk_size, directory)
        tag = data[0, 4].unpack1("V")

        case tag
        when Binary::LITStructures::Tags::AOLL
          parse_aoll_chunk(data, chunk_size, directory)
        when Binary::LITStructures::Tags::AOLI
          # AOLI chunks are for indexing, we can skip them for reading
          nil
        end
      end

      # Parse AOLL (list) chunk
      def parse_aoll_chunk(data, chunk_size, directory)
        header = Binary::LITStructures::AOLLHeader.read(data[0, 48])

        # Calculate data area
        quickref_offset = header.quickref_offset
        data_size = chunk_size - (quickref_offset + 48)
        data_offset = 48

        # Parse entries using encoded integers
        remaining = data_size
        pos = data_offset

        while remaining.positive?
          entry = parse_directory_entry(data, pos, remaining)
          break unless entry

          directory.entries << entry

          # Update position using instance variable
          entry_size = entry.instance_variable_get(:@_bytes_read)
          pos += entry_size
          remaining -= entry_size
        end
      end

      # Parse directory entry with encoded integers
      def parse_directory_entry(data, pos, remaining)
        return nil if remaining <= 0

        start_pos = pos

        # Read name length (encoded integer)
        name_length, bytes = read_encoded_int(data, pos, remaining)
        return nil unless name_length

        pos += bytes
        remaining -= bytes

        # Read name
        return nil if remaining < name_length

        name = data[pos, name_length].force_encoding("UTF-8")
        pos += name_length
        remaining -= name_length

        # Read section (encoded integer)
        section, bytes = read_encoded_int(data, pos, remaining)
        return nil unless section

        pos += bytes
        remaining -= bytes

        # Read offset (encoded integer)
        offset, bytes = read_encoded_int(data, pos, remaining)
        return nil unless offset

        pos += bytes
        remaining -= bytes

        # Read size (encoded integer)
        size, bytes = read_encoded_int(data, pos, remaining)
        return nil unless size

        pos += bytes
        remaining - bytes

        # Create entry
        entry = Models::LITDirectoryEntry.new
        entry.name = name
        entry.section = section
        entry.offset = offset
        entry.size = size

        # Attach metadata for position tracking
        entry.instance_variable_set(:@_bytes_read, pos - start_pos)
        entry
      end

      # Read an encoded integer (variable length)
      #
      # MSB indicates continuation, lower 7 bits are data
      def read_encoded_int(data, pos, remaining)
        return [nil, 0] if remaining <= 0

        value = 0
        bytes_read = 0

        loop do
          return [nil, 0] if bytes_read >= remaining

          byte = data[pos + bytes_read].ord
          bytes_read += 1

          value <<= 7
          value |= (byte & 0x7F)

          break unless byte.anybits?(0x80)
        end

        [value, bytes_read]
      end

      # Parse sections from ::DataSpace/NameList
      def parse_sections(handle, lit_file)
        return unless lit_file.directory

        # The NameList entry in the directory doesn't point to a valid NameList structure
        # Instead, create sections based on the directory entries themselves

        # Find unique section IDs from directory (excluding section 0 which is uncompressed)
        section_ids = lit_file.directory.entries.map(&:section).uniq.sort
        section_ids.delete(0) # Skip section 0 (uncompressed)

        # Build an array indexed by section_id
        # sections[section_id] gives the section for that ID
        max_section_id = section_ids.last || 0
        sections = Array.new(max_section_id + 1) # Create array with nil placeholders

        section_ids.each do |section_id|
          # Create a section object
          section = Models::LITSection.new

          # Determine section name based on directory entries
          # Look for storage section entries in the directory
          section.name = find_section_name(lit_file, section_id)

          sections[section_id] = section
        end

        # Parse transform information for each section (skip nil entries)
        sections.compact.each do |section|
          parse_section_transforms(handle, lit_file, section)
        end

        lit_file.sections = sections
      end

      # Find section name from directory entries
      def find_section_name(lit_file, section_id)
        # Get all storage section names from section 0
        storage_sections = lit_file.directory.entries.select do |e|
          e.section.zero? &&
            e.name.start_with?("::DataSpace/Storage/") &&
            e.name.count("/") == 3 # ::DataSpace/Storage/SectionName/
        end.map do |e|
          e.name.match(/^::DataSpace\/Storage\/([^\/]+)\//)[1]
        end.uniq

        # Map section IDs to storage section names
        # For LIT files, the mapping is typically:
        # - Section 1: Not used
        # - Section 2: MSCompressed (LZX compression)
        # - Section 3: EbEncryptOnlyDS or EbEncryptDS (DES encryption)
        case section_id
        when 2
          # Section 2 is typically MSCompressed
          if storage_sections.include?("MSCompressed")
            "MSCompressed"
          elsif storage_sections.include?("EbEncryptDS")
            "EbEncryptDS"
          else
            storage_sections.first || "Section2"
          end
        when 3
          # Section 3 is typically encryption-related
          if storage_sections.include?("EbEncryptOnlyDS")
            "EbEncryptOnlyDS"
          elsif storage_sections.include?("EbEncryptDS")
            "EbEncryptDS"
          else
            "Section3"
          end
        else
          format("Section%d", section_id)
        end
      end

      # Parse transform information for a section
      def parse_section_transforms(handle, lit_file, section)
        # Build transform list path
        transform_path = Binary::LITStructures::Paths::STORAGE +
          section.name +
          Binary::LITStructures::Paths::TRANSFORM_LIST

        transform_entry = lit_file.directory.find(transform_path)
        return unless transform_entry

        # Read transform list data
        @io_system.seek(
          handle,
          lit_file.content_offset + transform_entry.offset,
          Constants::SEEK_START,
        )
        transform_data = @io_system.read(handle, transform_entry.size)

        # Parse transforms (GUIDs)
        section.transforms = []
        pos = 0

        while pos + 16 <= transform_data.bytesize
          guid_bytes = transform_data[pos, 16]
          guid = format_transform_guid(guid_bytes)
          section.transforms << guid

          # Set flags based on GUID
          case guid
          when Binary::LITStructures::GUIDs::DESENCRYPT
            section.encrypted = true
            lit_file.drm_level = 1
          when Binary::LITStructures::GUIDs::LZXCOMPRESS
            section.compressed = true
          end

          pos += 16
        end

        # Parse LZX control data if compressed
        if section.compressed
          parse_lzx_control_data(handle, lit_file, section)
        end
      end

      # Parse LZX control data and reset table
      def parse_lzx_control_data(handle, lit_file, section)
        # Find control data entry
        control_path = Binary::LITStructures::Paths::STORAGE +
          section.name +
          Binary::LITStructures::Paths::CONTROL_DATA

        control_entry = lit_file.directory.find(control_path)
        return unless control_entry

        # Read control data
        @io_system.seek(
          handle,
          lit_file.content_offset + control_entry.offset,
          Constants::SEEK_START,
        )
        control_data = @io_system.read(handle, control_entry.size)

        return unless control_data.bytesize >= 32

        # Parse control data structure
        control = Binary::LITStructures::LZXControlData.read(control_data)

        # Calculate window size
        window_size = 15
        size_code = control.window_size_code
        while size_code.positive?
          size_code >>= 1
          window_size += 1
        end

        section.window_size = window_size

        # Parse reset table
        parse_reset_table_info(handle, lit_file, section)
      end

      # Parse reset table information
      def parse_reset_table_info(handle, lit_file, section)
        # Find reset table entry
        reset_table_path = Binary::LITStructures::Paths::STORAGE +
          section.name +
          "/Transform/#{Binary::LITStructures::GUIDs::LZXCOMPRESS}/InstanceData/ResetTable"

        reset_entry = lit_file.directory.find(reset_table_path)
        return unless reset_entry

        # Read reset table
        @io_system.seek(
          handle,
          lit_file.content_offset + reset_entry.offset,
          Constants::SEEK_START,
        )
        reset_data = @io_system.read(handle, reset_entry.size)

        return unless reset_data.bytesize >= 40

        # Parse reset table header
        header = Binary::LITStructures::ResetTableHeader.read(reset_data[0, 40])

        section.uncompressed_length = header.uncompressed_length
        section.compressed_length = header.compressed_length
        section.reset_interval = header.reset_interval

        # Parse reset points
        entry_offset = header.header_length + 8
        num_entries = header.num_entries

        reset_points = []
        (num_entries - 1).times do
          break if entry_offset + 8 > reset_data.bytesize

          offset_low = reset_data[entry_offset, 4].unpack1("V")
          offset_high = reset_data[entry_offset + 4, 4].unpack1("V")

          # Skip 64-bit offsets (not supported)
          break if offset_high != 0

          reset_points << offset_low
          entry_offset += 8
        end

        section.reset_table = reset_points
      end

      # Format GUID bytes as string
      def format_transform_guid(bytes)
        parts = bytes.unpack("VvvnH12")
        format(
          "{%<part0>08X-%<part1>04X-%<part2>04X-%<part3>04X-%<part4>s}",
          part0: parts[0], part1: parts[1], part2: parts[2],
          part3: parts[3], part4: parts[4].upcase
        )
      end

      # Parse NameList format
      def parse_namelist(data)
        sections = []
        pos = 2 # Skip initial field

        # Read number of sections
        return sections if pos >= data.bytesize

        num_sections = data[pos, 2].unpack1("v")
        pos += 2

        num_sections.times do
          break if pos >= data.bytesize

          # Read section name length
          name_length = data[pos, 2].unpack1("v")
          pos += 2

          break if pos + (name_length * 2) > data.bytesize

          # Read section name (UTF-16LE)
          name_bytes = data[pos, name_length * 2]
          name = name_bytes.unpack("v*").pack("U*").force_encoding("UTF-8")
          pos += (name_length * 2) + 2 # +2 for null terminator

          section = Models::LITSection.new
          section.name = name
          sections << section
        end

        sections
      end

      # Parse manifest file
      def parse_manifest(handle, lit_file)
        return unless lit_file.directory

        # Find manifest entry
        manifest_entry = lit_file.directory.find(
          Binary::LITStructures::Paths::MANIFEST,
        )
        return unless manifest_entry

        # Read manifest
        @io_system.seek(
          handle,
          lit_file.content_offset + manifest_entry.offset,
          Constants::SEEK_START,
        )
        manifest_data = @io_system.read(handle, manifest_entry.size)

        # Parse manifest
        lit_file.manifest = parse_manifest_data(manifest_data)
      end

      # Parse manifest data
      def parse_manifest_data(data)
        manifest = Models::LITManifest.new
        manifest.mappings = []

        pos = 0

        while pos < data.bytesize
          # Read directory name length
          break if pos >= data.bytesize

          dir_length = data[pos].ord
          pos += 1
          break if dir_length.zero?

          # Skip directory name
          pos += dir_length

          # Read 4 groups (HTML spine, HTML other, CSS, Images)
          4.times do |group|
            break if pos + 4 > data.bytesize

            num_files = data[pos, 4].unpack1("V")
            pos += 4

            num_files.times do
              mapping = parse_manifest_entry(data, pos, group)
              break unless mapping

              manifest.mappings << mapping
              pos += mapping.instance_variable_get(:@_bytes_read)
            end
          end
        end

        manifest
      end

      # Parse single manifest entry
      def parse_manifest_entry(data, pos, group)
        return nil if pos + 5 > data.bytesize

        start_pos = pos

        # Read offset
        offset = data[pos, 4].unpack1("V")
        pos += 4

        # Read internal name
        internal_length = data[pos].ord
        pos += 1
        return nil if pos + internal_length > data.bytesize

        internal_name = data[pos, internal_length].force_encoding("UTF-8")
        pos += internal_length

        # Read original name
        return nil if pos >= data.bytesize

        original_length = data[pos].ord
        pos += 1
        return nil if pos + original_length > data.bytesize

        original_name = data[pos, original_length].force_encoding("UTF-8")
        pos += original_length

        # Read content type
        return nil if pos >= data.bytesize

        type_length = data[pos].ord
        pos += 1
        return nil if pos + type_length > data.bytesize

        content_type = data[pos, type_length].force_encoding("UTF-8")
        pos += type_length

        # Skip terminator
        pos += 1

        mapping = Models::LITManifestMapping.new
        mapping.offset = offset
        mapping.internal_name = internal_name
        mapping.original_name = original_name
        mapping.content_type = content_type
        mapping.group = group

        # Attach metadata for position tracking
        mapping.instance_variable_set(:@_bytes_read, pos - start_pos)
        mapping
      end
    end
  end
end
