# frozen_string_literal: true

require_relative "guid_generator"
require_relative "content_type_detector"
require_relative "directory_builder"

module Cabriolet
  module LIT
    # Builds complete LIT structure from file data
    class StructureBuilder
      attr_reader :io_system, :version, :language_id, :creator_id

      # Initialize structure builder
      #
      # @param io_system [System::IOSystem] I/O system for file operations
      # @param version [Integer] LIT format version
      # @param language_id [Integer] Language ID
      # @param creator_id [Integer] Creator ID
      def initialize(io_system:, version: 1, language_id: 0x409, creator_id: 0)
        @io_system = io_system
        @version = version
        @language_id = language_id
        @creator_id = creator_id
      end

      # Build complete LIT structure from file data
      #
      # @param file_data [Array<Hash>] File data array from prepare_files
      # @return [Hash] Complete LIT structure
      def build(file_data)
        structure = {}

        # Generate GUIDs
        structure[:header_guid] = GuidGenerator.generate
        structure[:piece3_guid] = Binary::LITStructures::GUIDs::PIECE3
        structure[:piece4_guid] = Binary::LITStructures::GUIDs::PIECE4

        # Build directory
        structure[:directory] = build_directory(file_data)

        # Build sections
        structure[:sections] = build_sections

        # Build manifest
        structure[:manifest] = build_manifest(file_data)

        # Build secondary header metadata
        structure[:secondary_header] = build_secondary_header_metadata

        # Calculate piece offsets and sizes
        structure[:pieces] = calculate_pieces(structure)

        # Update secondary header with content offset
        update_secondary_header_content_offset(structure)

        # Store metadata
        structure[:version] = @version
        structure[:file_data] = file_data

        structure
      end

      private

      # Build directory structure from file data
      #
      # @param file_data [Array<Hash>] File data array
      # @return [Hash] Directory structure
      def build_directory(file_data)
        builder = DirectoryBuilder.new

        # Add entries for all files
        section = 0
        offset = 0

        file_data.each do |file_info|
          builder.add_entry(
            name: file_info[:lit_path],
            section: section,
            offset: offset,
            size: file_info[:uncompressed_size],
          )
          offset += file_info[:uncompressed_size]
        end

        # Calculate NameList size
        namelist_size = calculate_namelist_size

        # Calculate manifest size
        manifest_size = calculate_manifest_size(file_data)

        # Add special entries for LIT structure
        builder.add_entry(
          name: Binary::LITStructures::Paths::NAMELIST,
          section: 0,
          offset: offset,
          size: namelist_size,
        )
        offset += namelist_size

        builder.add_entry(
          name: Binary::LITStructures::Paths::MANIFEST,
          section: 0,
          offset: offset,
          size: manifest_size,
        )

        builder.build
      end

      # Build sections array
      #
      # @return [Array<Hash>] Sections array
      def build_sections
        # For simple implementation: single uncompressed section
        [
          {
            name: "Uncompressed",
            transforms: [],
            compressed: false,
            encrypted: false,
          },
        ]
      end

      # Build manifest from file data
      #
      # @param file_data [Array<Hash>] File data array
      # @return [Hash] Manifest structure
      def build_manifest(file_data)
        mappings = []

        file_data.each_with_index do |file_info, index|
          mappings << {
            offset: index,
            internal_name: file_info[:lit_path],
            original_name: file_info[:lit_path],
            content_type: ContentTypeDetector.content_type(file_info[:lit_path]),
            group: ContentTypeDetector.file_group(file_info[:lit_path]),
          }
        end

        { mappings: mappings }
      end

      # Build secondary header metadata
      #
      # @return [Hash] Secondary header metadata
      def build_secondary_header_metadata
        # Calculate actual secondary header length
        temp_header = Binary::LITStructures::SecondaryHeader.new
        sec_hdr_length = temp_header.to_binary_s.bytesize

        {
          length: sec_hdr_length,
          entry_chunklen: 0x2000, # 8KB chunks for entry directory
          count_chunklen: 0x200,      # 512B chunks for count directory
          entry_unknown: 0x100000,
          count_unknown: 0x20000,
          entry_depth: 1,             # No AOLI index layer
          entry_entries: 0,           # Will be set when directory built
          count_entries: 0,           # Will be set when directory built
          content_offset: 0,          # Will be calculated after pieces
          timestamp: Time.now.to_i,
          language_id: @language_id,
          creator_id: @creator_id,
        }
      end

      # Calculate piece offsets and sizes
      #
      # @param structure [Hash] Partial structure (needs secondary_header)
      # @return [Array<Hash>] Pieces array
      def calculate_pieces(structure)
        pieces = []

        # Calculate starting offset (after headers and pieces)
        sec_hdr_length = structure[:secondary_header][:length]
        current_offset = 40 + 80 + sec_hdr_length

        # Piece 0: File size information (16 bytes)
        pieces << { offset: current_offset, size: 16 }
        current_offset += 16

        # Piece 1: Directory (IFCM structure)
        # Build DirectoryBuilder to calculate size
        dir_builder = DirectoryBuilder.new(chunk_size: structure[:directory][:chunk_size])
        structure[:directory][:entries].each do |entry|
          dir_builder.add_entry(
            name: entry[:name],
            section: entry[:section],
            offset: entry[:offset],
            size: entry[:size],
          )
        end
        piece1_size = dir_builder.calculate_size
        pieces << { offset: current_offset, size: piece1_size }
        current_offset += piece1_size

        # Piece 2: Index information (typically empty or minimal)
        piece2_size = 512
        pieces << { offset: current_offset, size: piece2_size }
        current_offset += piece2_size

        # Piece 3: Standard GUID (16 bytes)
        pieces << { offset: current_offset, size: 16 }
        current_offset += 16

        # Piece 4: Standard GUID (16 bytes)
        pieces << { offset: current_offset, size: 16 }

        pieces
      end

      # Update secondary header with final content offset
      #
      # @param structure [Hash] Structure to update
      def update_secondary_header_content_offset(structure)
        pieces = structure[:pieces]
        last_piece = pieces.last
        content_offset = last_piece[:offset] + last_piece[:size]

        structure[:secondary_header][:content_offset] = content_offset
      end

      # Calculate NameList size (estimate)
      #
      # @return [Integer] Estimated size
      def calculate_namelist_size
        # Simple estimate: ~100 bytes for minimal NameList
        100
      end

      # Calculate manifest size (estimate)
      #
      # @param file_data [Array<Hash>] File data array
      # @return [Integer] Estimated size
      def calculate_manifest_size(file_data)
        # Rough estimate: directory header + entries
        size = 10 # Directory header

        file_data.each do |file_info|
          # Per entry: offset (4) + 3 length bytes + names + content type + terminator
          size += 4 + 3
          size += (file_info[:lit_path].bytesize * 2) + 20 + 1
        end

        size
      end
    end
  end
end
