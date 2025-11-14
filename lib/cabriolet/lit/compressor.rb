# frozen_string_literal: true

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
      attr_reader :io_system
      attr_accessor :files

      # Initialize a new LIT compressor
      #
      # @param io_system [System::IOSystem, nil] Custom I/O system or nil for
      #   default
      def initialize(io_system = nil)
        @io_system = io_system || System::IOSystem.new
        @files = []
      end

      # Add a file to the LIT archive
      #
      # @param source_path [String] Path to the source file
      # @param lit_path [String] Path within the LIT archive
      # @param options [Hash] Options for the file
      # @option options [Boolean] :compress Whether to compress the file
      #   (default: true)
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
      # @option options [Boolean] :encrypt Whether to encrypt (not supported,
      #   raises error)
      # @return [Integer] Bytes written to output file
      # @raise [Errors::CompressionError] if generation fails
      # @raise [NotImplementedError] if encryption is requested
      def generate(output_file, **options)
        version = options.fetch(:version, 1)
        encrypt = options.fetch(:encrypt, false)

        if encrypt
          raise NotImplementedError,
                "DES encryption is not implemented. " \
                "LIT files will be created without encryption."
        end

        raise ArgumentError, "No files added to archive" if @files.empty?

        output_handle = @io_system.open(output_file, Constants::MODE_WRITE)

        begin
          # Prepare file data
          file_data = prepare_files

          # Write header
          header_bytes = write_header(
            output_handle,
            version,
            file_data.size,
          )

          # Write file entries
          entries_bytes = write_file_entries(output_handle, file_data)

          # Write file contents
          content_bytes = write_file_contents(
            output_handle,
            file_data,
          )

          header_bytes + entries_bytes + content_bytes
        ensure
          @io_system.close(output_handle) if output_handle
        end
      end

      private

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

      # Write LIT header
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param version [Integer] LIT format version
      # @param file_count [Integer] Number of files
      # @return [Integer] Number of bytes written
      def write_header(output_handle, version, file_count)
        header = Binary::LITStructures::LITHeader.new
        header.signature = Binary::LITStructures::SIGNATURE
        header.version = version
        header.flags = 0 # Not encrypted
        header.file_count = file_count
        header.header_size = 24 # Size of the header structure

        header_data = header.to_binary_s
        written = @io_system.write(output_handle, header_data)

        unless written == header_data.bytesize
          raise Errors::CompressionError,
                "Failed to write LIT header"
        end

        written
      end

      # Write file entries directory
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param file_data [Array<Hash>] Array of file information
      # @return [Integer] Number of bytes written
      def write_file_entries(output_handle, file_data)
        total_bytes = 0
        current_offset = calculate_header_size(file_data)

        file_data.each do |file_info|
          # Compress or store data
          if file_info[:compress]
            compressed = compress_data(file_info[:data])
            compressed_size = compressed.bytesize
            flags = Binary::LITStructures::FileFlags::COMPRESSED
          else
            compressed = file_info[:data]
            compressed_size = compressed.bytesize
            flags = 0
          end

          # Store compressed data for later writing
          file_info[:compressed_data] = compressed
          file_info[:compressed_size] = compressed_size
          file_info[:offset] = current_offset

          # Write file entry
          entry = Binary::LITStructures::LITFileEntry.new
          entry.filename_length = file_info[:lit_path].bytesize
          entry.filename = file_info[:lit_path]
          entry.offset = current_offset
          entry.compressed_size = compressed_size
          entry.uncompressed_size = file_info[:uncompressed_size]
          entry.flags = flags

          entry_data = entry.to_binary_s
          written = @io_system.write(output_handle, entry_data)
          total_bytes += written

          current_offset += compressed_size
        end

        total_bytes
      end

      # Write file contents
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param file_data [Array<Hash>] Array of file information with
      #   compressed data
      # @return [Integer] Number of bytes written
      def write_file_contents(output_handle, file_data)
        total_bytes = 0

        file_data.each do |file_info|
          written = @io_system.write(
            output_handle,
            file_info[:compressed_data],
          )
          total_bytes += written
        end

        total_bytes
      end

      # Calculate total header size (header + all file entries)
      #
      # @param file_data [Array<Hash>] Array of file information
      # @return [Integer] Total header size in bytes
      def calculate_header_size(file_data)
        # Header: 24 bytes
        header_size = 24

        # File entries: variable size
        file_data.each do |file_info|
          # 4 bytes filename length + filename + 28 bytes metadata
          header_size += 4 + file_info[:lit_path].bytesize + 28
        end

        header_size
      end

      # Compress data using LZX
      #
      # @param data [String] Data to compress
      # @return [String] Compressed data
      def compress_data(data)
        input_handle = System::MemoryHandle.new(data)
        output_handle = System::MemoryHandle.new("", Constants::MODE_WRITE)

        begin
          compressor = Compressors::LZX.new(
            @io_system,
            input_handle,
            output_handle,
            32_768,
          )

          compressor.compress

          output_handle.data

          # Memory handles don't need closing but maintain consistency
        end
      end
    end
  end
end
