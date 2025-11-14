# frozen_string_literal: true

module Cabriolet
  module HLP
    # Compressor creates HLP (Windows Help) compressed archives
    #
    # HLP files contain an internal file system where files can be compressed
    # using LZSS MODE_MSHELP compression. The compressor builds the archive
    # structure and compresses files as needed.
    #
    # NOTE: This implementation is based on the knowledge that HLP files use
    # LZSS compression with MODE_MSHELP, but cannot be fully validated due to
    # lack of test fixtures and incomplete libmspack implementation.
    class Compressor
      attr_reader :io_system

      # Default buffer size for I/O operations
      DEFAULT_BUFFER_SIZE = 2048

      # Initialize a new HLP compressor
      #
      # @param io_system [System::IOSystem, nil] Custom I/O system or nil for
      #   default
      def initialize(io_system = nil)
        @io_system = io_system || System::IOSystem.new
        @files = []
      end

      # Add a file to the HLP archive
      #
      # @param source_path [String] Path to source file
      # @param hlp_path [String] Path within HLP archive
      # @param compress [Boolean] Whether to compress the file
      # @return [void]
      def add_file(source_path, hlp_path, compress: true)
        @files << {
          source: source_path,
          hlp_path: hlp_path,
          compress: compress,
        }
      end

      # Add data from memory to the HLP archive
      #
      # @param data [String] Data to add
      # @param hlp_path [String] Path within HLP archive
      # @param compress [Boolean] Whether to compress the data
      # @return [void]
      def add_data(data, hlp_path, compress: true)
        @files << {
          data: data,
          hlp_path: hlp_path,
          compress: compress,
        }
      end

      # Generate HLP archive
      #
      # @param output_file [String] Path to output HLP file
      # @param options [Hash] Compression options
      # @option options [Integer] :version HLP format version (default: 1)
      # @return [Integer] Bytes written to output file
      # @raise [Errors::CompressionError] if compression fails
      def generate(output_file, **options)
        version = options.fetch(:version, 1)

        output_handle = @io_system.open(output_file, Constants::MODE_WRITE)

        begin
          # Compress all files and collect metadata
          compressed_files = compress_all_files

          # Calculate directory size first
          directory_size = calculate_directory_size(compressed_files)

          # Calculate offsets
          header_size = 18 # Header structure size
          directory_offset = header_size
          data_offset = header_size + directory_size

          # Assign file offsets
          current_offset = data_offset
          compressed_files.each do |file_info|
            file_info[:offset] = current_offset
            current_offset += file_info[:compressed_data].bytesize
          end

          # Write header
          header_bytes = write_header(
            output_handle,
            version,
            compressed_files.size,
            directory_offset,
          )

          # Write directory
          directory_bytes = write_directory(output_handle, compressed_files)

          # Write file data
          data_bytes = write_file_data(output_handle, compressed_files)

          header_bytes + directory_bytes + data_bytes
        ensure
          @io_system.close(output_handle) if output_handle
        end
      end

      private

      # Compress all files and collect metadata
      #
      # @return [Array<Hash>] Array of file information hashes
      def compress_all_files
        @files.map do |file_spec|
          compress_file_spec(file_spec)
        end
      end

      # Compress a single file specification
      #
      # @param file_spec [Hash] File specification
      # @return [Hash] File information with compressed data
      def compress_file_spec(file_spec)
        # Get source data
        data = file_spec[:data] || read_file_data(file_spec[:source])

        # Compress if requested
        compressed_data = if file_spec[:compress]
                            compress_data_lzss(data)
                          else
                            data
                          end

        {
          hlp_path: file_spec[:hlp_path],
          uncompressed_size: data.bytesize,
          compressed_data: compressed_data,
          compressed: file_spec[:compress],
        }
      end

      # Read file data from disk
      #
      # @param filename [String] Path to file
      # @return [String] File contents
      def read_file_data(filename)
        handle = @io_system.open(filename, Constants::MODE_READ)
        begin
          data = +""
          loop do
            chunk = @io_system.read(handle, DEFAULT_BUFFER_SIZE)
            break if chunk.empty?

            data << chunk
          end
          data
        ensure
          @io_system.close(handle)
        end
      end

      # Compress data using LZSS MODE_MSHELP
      #
      # @param data [String] Data to compress
      # @return [String] Compressed data
      def compress_data_lzss(data)
        input_handle = System::MemoryHandle.new(data)
        output_handle = System::MemoryHandle.new("", Constants::MODE_WRITE)

        compressor = Compressors::LZSS.new(
          @io_system,
          input_handle,
          output_handle,
          DEFAULT_BUFFER_SIZE,
          Compressors::LZSS::MODE_MSHELP,
        )

        compressor.compress
        output_handle.data
      end

      # Calculate directory size
      #
      # @param compressed_files [Array<Hash>] Compressed file information
      # @return [Integer] Directory size in bytes
      def calculate_directory_size(compressed_files)
        size = 0
        compressed_files.each do |file_info|
          # 4 bytes for filename length
          # N bytes for filename
          # 4 + 4 + 4 + 1 = 13 bytes for file metadata
          size += 4 + file_info[:hlp_path].bytesize + 13
        end
        size
      end

      # Write HLP header
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param version [Integer] Format version
      # @param file_count [Integer] Number of files
      # @param directory_offset [Integer] Offset to directory
      # @return [Integer] Number of bytes written
      def write_header(output_handle, version, file_count, directory_offset)
        header = Binary::HLPStructures::Header.new
        header.signature = Binary::HLPStructures::SIGNATURE
        header.version = version
        header.file_count = file_count
        header.directory_offset = directory_offset

        header_data = header.to_binary_s
        written = @io_system.write(output_handle, header_data)

        unless written == header_data.bytesize
          raise Errors::CompressionError,
                "Failed to write HLP header"
        end

        written
      end

      # Write file directory
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param compressed_files [Array<Hash>] Compressed file information
      # @return [Integer] Number of bytes written
      def write_directory(output_handle, compressed_files)
        bytes_written = 0

        compressed_files.each do |file_info|
          # Write filename length
          filename = file_info[:hlp_path].b
          length_data = [filename.bytesize].pack("V")
          bytes_written += @io_system.write(output_handle, length_data)

          # Write filename
          bytes_written += @io_system.write(output_handle, filename)

          # Write file metadata
          metadata = [
            file_info[:offset],
            file_info[:uncompressed_size],
            file_info[:compressed_data].bytesize,
            file_info[:compressed] ? 1 : 0,
          ].pack("V3C")
          bytes_written += @io_system.write(output_handle, metadata)
        end

        bytes_written
      end

      # Write file data
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param compressed_files [Array<Hash>] Compressed file information
      # @return [Integer] Number of bytes written
      def write_file_data(output_handle, compressed_files)
        bytes_written = 0

        compressed_files.each do |file_info|
          written = @io_system.write(
            output_handle,
            file_info[:compressed_data],
          )
          bytes_written += written
        end

        bytes_written
      end
    end
  end
end
