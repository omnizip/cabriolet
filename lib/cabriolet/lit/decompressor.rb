# frozen_string_literal: true

require_relative "parser"
require_relative "../decompressors/lzx"
require_relative "../binary/lit_structures"
require_relative "../errors"

module Cabriolet
  module LIT
    # Decompressor for Microsoft Reader LIT files
    #
    # Handles complete LIT file extraction including:
    # - Parsing complex LIT structure with Parser
    # - DataSpace/Storage sections with transform layers
    # - LZX decompression with ResetTable
    # - Manifest-based filename restoration
    # - Section caching for efficiency
    #
    # Based on the openclit/SharpLit reference implementation.
    #
    # NOTE: DES encryption (DRM) is not supported.
    class Decompressor
      attr_reader :io_system, :parser
      attr_accessor :buffer_size

      # Default buffer size for decompression
      DEFAULT_BUFFER_SIZE = 8192

      def initialize(io_system = nil, algorithm_factory = nil)
        @io_system = io_system || System::IOSystem.new
        @algorithm_factory = algorithm_factory || Cabriolet.algorithm_factory
        @parser = Parser.new(@io_system)
        @section_cache = {}
        @buffer_size = DEFAULT_BUFFER_SIZE
      end

      # Open and parse a LIT file
      #
      # @param filename [String] Path to LIT file
      # @return [Models::LITFile] Parsed LIT file structure
      # @raise [Errors::ParseError] if file is invalid
      # @raise [NotImplementedError] if file is DRM-encrypted
      def open(filename)
        lit_file = @parser.parse(filename)

        # Store filename for later extraction
        lit_file.instance_variable_set(:@filename, filename)

        # Check for DRM
        if lit_file.encrypted?
          raise NotImplementedError,
                "DES-encrypted LIT files not supported. " \
                "DRM level: #{lit_file.drm_level}"
        end

        lit_file
      end

      # Close a LIT file (no-op for compatibility)
      #
      # @param _lit_file [Models::LITFile] LIT file to close
      # @return [void]
      def close(_lit_file)
        # No resources to free in the file object itself
        # File handles are managed separately during extraction
        @section_cache.clear
        nil
      end

      # Extract a file from LIT archive (wrapper for extract_file)
      #
      # @param lit_file [Models::LITFile] Parsed LIT file
      # @param file [Models::LITDirectoryEntry] File entry to extract
      # @param output_path [String] Where to write extracted file
      # @return [Integer] Bytes written
      # @raise [ArgumentError] if parameters are invalid
      # @raise [NotImplementedError] if file is encrypted
      # @raise [Errors::DecompressionError] if extraction fails
      def extract(lit_file, file, output_path)
        raise ArgumentError, "Header must not be nil" unless lit_file
        raise ArgumentError, "File must not be nil" unless file
        raise ArgumentError, "Output path must not be nil" unless output_path

        # Check for encryption
        if lit_file.encrypted?
          raise NotImplementedError,
                "Encrypted sections not yet supported. " \
                "DRM level: #{lit_file.drm_level}"
        end

        # Use extract_file with file name
        internal_name = file.respond_to?(:name) ? file.name : file.to_s
        extract_file(lit_file, internal_name, output_path)
      end

      # Extract a file by name from LIT archive
      #
      # @param lit_file [Models::LITFile] Parsed LIT file
      # @param internal_name [String] Internal filename
      # @param output_path [String] Where to write extracted file
      # @return [Integer] Bytes written
      # @raise [Errors::DecompressionError] if extraction fails
      def extract_file(lit_file, internal_name, output_path)
        raise ArgumentError, "LIT file required" unless lit_file
        raise ArgumentError, "Internal name required" unless internal_name
        raise ArgumentError, "Output path required" unless output_path

        # Find directory entry
        entry = lit_file.directory.find(internal_name)
        unless entry
          raise Errors::DecompressionError,
                "File not found: #{internal_name}"
        end

        # Get section data (cached or decompressed)
        section_data = get_section_data(lit_file, entry.section)

        # Extract file from section
        file_data = section_data[entry.offset, entry.size]

        # Write to output
        output_handle = @io_system.open(output_path, Constants::MODE_WRITE)
        begin
          @io_system.write(output_handle, file_data)
        ensure
          @io_system.close(output_handle)
        end

        file_data.bytesize
      end

      # Extract all files from LIT archive
      #
      # @param lit_file [Models::LITFile] Parsed LIT file
      # @param output_dir [String] Directory to extract to
      # @param use_manifest [Boolean] Use manifest for filenames
      # @return [Integer] Number of files extracted
      def extract_all(lit_file, output_dir, use_manifest: true)
        raise ArgumentError, "Header must not be nil" unless lit_file
        raise ArgumentError, "Output directory must not be nil" unless output_dir

        ::FileUtils.mkdir_p(output_dir)

        extracted = 0

        # Extract each directory entry
        lit_file.directory.entries.each do |entry|
          # Skip root entry
          next if entry.root?

          # Determine output filename
          if use_manifest && lit_file.manifest
            mapping = lit_file.manifest.find_by_internal(entry.name)
            filename = mapping ? mapping.original_name : entry.name
          else
            filename = entry.name
          end

          # Create output path
          output_path = ::File.join(output_dir, filename)

          # Create subdirectories if needed
          file_dir = ::File.dirname(output_path)
          ::FileUtils.mkdir_p(file_dir) unless ::File.directory?(file_dir)

          # Extract file
          extract_file(lit_file, entry.name, output_path)
          extracted += 1
        end

        extracted
      end

      # List all files in LIT archive
      #
      # @param lit_file [Models::LITFile] Parsed LIT file
      # @param use_manifest [Boolean] Show original filenames
      # @return [Array<Hash>] File information
      def list_files(lit_file, use_manifest: true)
        raise ArgumentError, "LIT file required" unless lit_file

        lit_file.directory.entries.reject(&:root?).map do |entry|
          info = {
            internal_name: entry.name,
            section: entry.section,
            offset: entry.offset,
            size: entry.size,
          }

          if use_manifest && lit_file.manifest
            mapping = lit_file.manifest.find_by_internal(entry.name)
            if mapping
              info[:original_name] = mapping.original_name
              info[:content_type] = mapping.content_type
            end
          end

          info
        end
      end

      private

      # Get section data (cached or freshly decompressed)
      #
      # @param lit_file [Models::LITFile] Parsed LIT file
      # @param section_id [Integer] Section ID
      # @return [String] Decompressed section data
      def get_section_data(lit_file, section_id)
        # Check cache first
        return @section_cache[section_id] if @section_cache[section_id]

        # Section 0 is uncompressed content
        if section_id.zero?
          data = read_uncompressed_content(lit_file)
        else
          # Get section info
          section = lit_file.sections[section_id - 1]
          raise Errors::DecompressionError, "Section #{section_id} not found" unless section

          # Decompress section
          data = decompress_section(lit_file, section)
        end

        # Cache for future use
        @section_cache[section_id] = data

        data
      end

      # Read uncompressed content from section 0
      def read_uncompressed_content(lit_file)
        filename = lit_file.instance_variable_get(:@filename)
        handle = @io_system.open(filename, Constants::MODE_READ)

        begin
          # Section 0 starts at content_offset
          @io_system.seek(handle, lit_file.content_offset, Constants::SEEK_START)

          # Read until we hit another section or EOF
          # For now, read a reasonable amount
          @io_system.read(handle, 1024 * 1024) # 1MB for section 0
        ensure
          @io_system.close(handle)
        end
      end

      # Decompress a section with transforms
      def decompress_section(lit_file, section)
        lit_file.instance_variable_get(:@filename)

        # Read transform list
        transform_path = Binary::LITStructures::Paths::STORAGE +
          section.name +
          Binary::LITStructures::Paths::TRANSFORM_LIST

        transform_entry = lit_file.directory.find(transform_path)
        unless transform_entry
          raise Errors::DecompressionError,
                "Transform list not found for section: #{section.name}"
        end

        transforms = read_transforms(lit_file, transform_entry)

        # Read content
        content_path = Binary::LITStructures::Paths::STORAGE +
          section.name +
          Binary::LITStructures::Paths::CONTENT

        content_entry = lit_file.directory.find(content_path)
        unless content_entry
          raise Errors::DecompressionError,
                "Content not found for section: #{section.name}"
        end

        data = read_entry_data(lit_file, content_entry)

        # Read control data
        control_path = Binary::LITStructures::Paths::STORAGE +
          section.name +
          Binary::LITStructures::Paths::CONTROL_DATA

        control_entry = lit_file.directory.find(control_path)
        control_data = control_entry ? read_entry_data(lit_file, control_entry) : nil

        # Apply transforms in order
        transforms.each do |transform_guid|
          case transform_guid
          when Binary::LITStructures::GUIDs::DESENCRYPT
            raise NotImplementedError,
                  "DES encryption not supported"
          when Binary::LITStructures::GUIDs::LZXCOMPRESS
            data = decompress_lzx_section(lit_file, section, data, control_data)
          else
            raise Errors::DecompressionError,
                  "Unknown transform GUID: #{transform_guid}"
          end
        end

        data
      end

      # Read transforms from transform list
      def read_transforms(lit_file, entry)
        data = read_entry_data(lit_file, entry)

        transforms = []
        pos = 0

        while pos + 16 <= data.bytesize
          guid_bytes = data[pos, 16]
          guid = format_guid(guid_bytes)
          transforms << guid
          pos += 16
        end

        transforms
      end

      # Format GUID bytes as string
      def format_guid(bytes)
        parts = bytes.unpack("VvvnH12")
        format(
          "{%<part0>08X-%<part1>04X-%<part2>04X-%<part3>04X-%<part4>s}",
          part0: parts[0], part1: parts[1], part2: parts[2],
          part3: parts[3], part4: parts[4].upcase
        )
      end

      # Read entry data from file
      def read_entry_data(lit_file, entry)
        filename = lit_file.instance_variable_get(:@filename)
        handle = @io_system.open(filename, Constants::MODE_READ)

        begin
          @io_system.seek(
            handle,
            lit_file.content_offset + entry.offset,
            Constants::SEEK_START,
          )
          @io_system.read(handle, entry.size)
        ensure
          @io_system.close(handle)
        end
      end

      # Decompress LZX section with ResetTable
      def decompress_lzx_section(lit_file, section, compressed_data, control_data)
        # Parse control data
        unless control_data && control_data.bytesize >= 32
          raise Errors::DecompressionError,
                "Invalid LZX control data"
        end

        control = Binary::LITStructures::LZXControlData.read(control_data)

        unless control.tag == Binary::LITStructures::Tags::LZXC
          raise Errors::DecompressionError,
                "Invalid LZXC tag: #{format('0x%08X', control.tag)}"
        end

        # Calculate window size
        window_size = 15
        size_code = control.window_size_code
        while size_code.positive?
          size_code >>= 1
          window_size += 1
        end

        if window_size < 15 || window_size > 21
          raise Errors::DecompressionError,
                "Invalid LZX window size: #{window_size}"
        end

        # Read reset table
        reset_table_path = Binary::LITStructures::Paths::STORAGE +
          section.name +
          "/Transform/#{Binary::LITStructures::GUIDs::LZXCOMPRESS}/InstanceData/ResetTable"

        reset_entry = lit_file.directory.find(reset_table_path)
        unless reset_entry
          raise Errors::DecompressionError,
                "ResetTable not found for section: #{section.name}"
        end

        reset_data = read_entry_data(lit_file, reset_entry)
        reset_table = parse_reset_table(reset_data)

        # Decompress with reset points
        decompress_with_reset_table(
          compressed_data,
          reset_table,
          window_size,
        )
      end

      # Parse reset table
      def parse_reset_table(data)
        header = Binary::LITStructures::ResetTableHeader.read(data[0, 40])

        unless header.version == 3
          raise Errors::DecompressionError,
                "Unsupported ResetTable version: #{header.version}"
        end

        # Read reset entries (skip first which is always 0)
        entry_offset = header.header_length + 8
        num_entries = header.num_entries

        reset_points = []
        (num_entries - 1).times do |_i|
          break if entry_offset + 8 > data.bytesize

          offset_low = data[entry_offset, 4].unpack1("V")
          offset_high = data[entry_offset + 4, 4].unpack1("V")

          if offset_high != 0
            raise Errors::DecompressionError,
                  "64-bit reset point not supported"
          end

          reset_points << offset_low
          entry_offset += 8
        end

        {
          uncompressed_length: header.uncompressed_length,
          compressed_length: header.compressed_length,
          reset_interval: header.reset_interval,
          reset_points: reset_points,
        }
      end

      # Decompress with reset table
      def decompress_with_reset_table(compressed_data, reset_table, window_size)
        uncompressed = String.new(capacity: reset_table[:uncompressed_length])

        # Create LZX decompressor
        input_handle = System::MemoryHandle.new(compressed_data)
        output_handle = System::MemoryHandle.new("", Constants::MODE_WRITE)

        decompressor = Decompressors::LZX.new(window_size)

        window_bytes = 1 << window_size
        reset_table[:reset_interval]
        reset_points = [0] + reset_table[:reset_points]

        bytes_remaining = reset_table[:uncompressed_length]
        compressed_pos = 0
        0

        # Process each reset block
        reset_points.each_with_index do |reset_point, idx|
          next_reset = reset_points[idx + 1] || compressed_data.bytesize

          compressed_size = next_reset - reset_point
          output_size = [bytes_remaining, window_bytes].min

          if output_size.positive?
            # Decompress this block
            input_chunk = compressed_data[compressed_pos, compressed_size]
            input_handle = System::MemoryHandle.new(input_chunk)
            output_handle = System::MemoryHandle.new("", Constants::MODE_WRITE)

            decompressor.reset if idx.positive?
            decompressor.decompress_chunk(
              input_handle,
              output_handle,
              compressed_size,
              output_size,
            )

            uncompressed << output_handle.data
            compressed_pos += compressed_size
            bytes_remaining -= output_size
          end

          break if bytes_remaining <= 0
        end

        uncompressed
      end
    end
  end
end
