# frozen_string_literal: true

require_relative "guid_generator"
require_relative "content_type_detector"
require_relative "directory_builder"
require_relative "structure_builder"
require_relative "header_writer"
require_relative "piece_builder"
require_relative "content_encoder"

module Cabriolet
  module LIT
    # Compressor creates LIT eBook files
    #
    # LIT files are Microsoft Reader eBook files that use LZX compression.
    # The compressor allows adding multiple files to create a LIT archive.
    #
    # NOTE: This implementation creates non-encrypted LIT files only.
    # DES encryption (DRM protection) is not implemented.
    class Compressor
      attr_reader :io_system, :files

      # Initialize a new LIT compressor
      #
      # @param io_system [System::IOSystem, nil] Custom I/O system or nil for default
      # @param algorithm_factory [AlgorithmFactory, nil] Custom algorithm factory or nil for default
      def initialize(io_system = nil, algorithm_factory = nil)
        @io_system = io_system || System::IOSystem.new
        @algorithm_factory = algorithm_factory || Cabriolet.algorithm_factory
        @files = []
      end

      # Add a file to the LIT archive
      #
      # @param source_path [String] Path to the source file
      # @param lit_path [String] Path within the LIT archive
      # @param options [Hash] Options for the file
      # @option options [Boolean] :compress Whether to compress the file (default: true)
      # @return [void]
      def add_file(source_path, lit_path, **options)
        compress = options.fetch(:compress, true)

        @files << {
          source: source_path,
          lit_path: lit_path,
          compress: compress,
        }
      end

      # Generate the LIT archive
      #
      # @param output_file [String] Path to output LIT file
      # @param options [Hash] Generation options
      # @option options [Integer] :version LIT format version (default: 1)
      # @option options [Integer] :language_id Language ID (default: 0x409 English)
      # @option options [Integer] :creator_id Creator ID (default: 0)
      # @return [Integer] Bytes written to output file
      # @raise [Errors::CompressionError] if compression fails
      def generate(output_file, **options)
        version = options.fetch(:version, 1)
        language_id = options.fetch(:language_id, 0x409)
        creator_id = options.fetch(:creator_id, 0)

        raise ArgumentError, "No files added to archive" if @files.empty?
        raise ArgumentError, "Version must be 1" unless version == 1

        # Prepare file data
        file_data = prepare_files

        # Build LIT structure
        structure_builder = StructureBuilder.new(
          io_system: @io_system,
          version: version,
          language_id: language_id,
          creator_id: creator_id,
        )
        lit_structure = structure_builder.build(file_data)

        # Write to output file
        output_handle = @io_system.open(output_file, Constants::MODE_WRITE)
        begin
          bytes_written = write_lit_file(output_handle, lit_structure)
          bytes_written
        ensure
          @io_system.close(output_handle)
        end
      end

      private

      # Write complete LIT file
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param structure [Hash] LIT structure
      # @return [Integer] Bytes written
      def write_lit_file(output_handle, structure)
        header_writer = HeaderWriter.new(@io_system)

        bytes_written = 0

        # Write primary header (40 bytes)
        bytes_written += header_writer.write_primary_header(output_handle,
                                                            structure)

        # Write piece structures (5 * 16 bytes = 80 bytes)
        bytes_written += header_writer.write_piece_structures(output_handle,
                                                              structure[:pieces])

        # Write secondary header
        bytes_written += header_writer.write_secondary_header(
          output_handle,
          structure[:secondary_header],
        )

        # Write piece data
        bytes_written += write_piece_data(output_handle, structure)

        bytes_written
      end

      # Write piece data
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param structure [Hash] LIT structure
      # @return [Integer] Bytes written
      def write_piece_data(output_handle, structure)
        total_bytes = 0

        # Write piece 0: File size information
        piece0_data = PieceBuilder.build_piece0(structure[:file_data])
        total_bytes += @io_system.write(output_handle, piece0_data)

        # Write piece 1: Directory (IFCM structure)
        piece1_data = PieceBuilder.build_piece1(structure[:directory])
        total_bytes += @io_system.write(output_handle, piece1_data)

        # Write piece 2: Index information
        piece2_data = PieceBuilder.build_piece2
        total_bytes += @io_system.write(output_handle, piece2_data)

        # Write piece 3: GUID
        total_bytes += @io_system.write(output_handle, structure[:piece3_guid])

        # Write piece 4: GUID
        total_bytes += @io_system.write(output_handle, structure[:piece4_guid])

        # Write actual content data (after pieces, this is where files go)
        total_bytes += write_content_data(output_handle, structure)

        total_bytes
      end

      # Write content data (actual file contents)
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param structure [Hash] LIT structure
      # @return [Integer] Bytes written
      def write_content_data(output_handle, structure)
        total_bytes = 0

        # Write each file's content
        structure[:file_data].each do |file_info|
          total_bytes += @io_system.write(output_handle, file_info[:data])
        end

        # Write NameList
        namelist_data = ContentEncoder.build_namelist_data(structure[:sections])
        total_bytes += @io_system.write(output_handle, namelist_data)

        # Write manifest
        manifest_data = ContentEncoder.build_manifest_data(structure[:manifest])
        total_bytes += @io_system.write(output_handle, manifest_data)

        total_bytes
      end

      # Prepare file data for archiving
      #
      # @return [Array<Hash>] Array of file information hashes
      def prepare_files
        @files.map do |file_info|
          source = file_info[:source]
          lit_path = file_info[:lit_path]
          compress = file_info[:compress]

          # Read source file
          handle = @io_system.open(source, Constants::MODE_READ)
          begin
            size = @io_system.seek(handle, 0, Constants::SEEK_END)
            @io_system.seek(handle, 0, Constants::SEEK_START)
            data = @io_system.read(handle, size)
          ensure
            @io_system.close(handle)
          end

          {
            lit_path: lit_path,
            data: data,
            uncompressed_size: data.bytesize,
            compress: compress,
          }
        end
      end
    end
  end
end
