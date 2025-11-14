# frozen_string_literal: true

module Cabriolet
  module HLP
    # Decompressor is the main interface for HLP file operations
    #
    # HLP files use LZSS compression with MODE_MSHELP and contain an internal
    # file system. Files are decompressed using the Decompressors::LZSS class.
    #
    # NOTE: This implementation is based on the knowledge that HLP files use
    # LZSS compression with MODE_MSHELP, but cannot be fully validated due to
    # lack of test fixtures and incomplete libmspack implementation.
    class Decompressor
      attr_reader :io_system, :parser
      attr_accessor :buffer_size

      # Input buffer size for decompression
      DEFAULT_BUFFER_SIZE = 2048

      # Initialize a new HLP decompressor
      #
      # @param io_system [System::IOSystem, nil] Custom I/O system or nil for
      #   default
      def initialize(io_system = nil)
        @io_system = io_system || System::IOSystem.new
        @parser = Parser.new(@io_system)
        @buffer_size = DEFAULT_BUFFER_SIZE
      end

      # Open and parse an HLP file
      #
      # @param filename [String] Path to the HLP file
      # @return [Models::HLPHeader] Parsed header with file list
      # @raise [Errors::ParseError] if the file is not a valid HLP
      def open(filename)
        header = @parser.parse(filename)
        header.filename = filename
        header
      end

      # Close an HLP file (no-op for compatibility)
      #
      # @param _header [Models::HLPHeader] Header to close
      # @return [void]
      def close(_header)
        # No resources to free in the header itself
        # File handles are managed separately during extraction
        nil
      end

      # Extract a file from HLP archive
      #
      # @param header [Models::HLPHeader] HLP header from open()
      # @param hlp_file [Models::HLPFile] File to extract from archive
      # @param output_path [String] Where to write the extracted file
      # @return [Integer] Number of bytes written
      # @raise [Errors::DecompressionError] if extraction fails
      def extract_file(header, hlp_file, output_path)
        raise ArgumentError, "Header must not be nil" unless header
        raise ArgumentError, "HLP file must not be nil" unless hlp_file
        raise ArgumentError, "Output path must not be nil" unless output_path

        input_handle = @io_system.open(header.filename, Constants::MODE_READ)
        output_handle = @io_system.open(output_path, Constants::MODE_WRITE)

        begin
          # Seek to file data
          @io_system.seek(input_handle, hlp_file.offset,
                          Constants::SEEK_START)

          bytes_written = if hlp_file.compressed?
                            decompress_file(input_handle, output_handle,
                                            hlp_file)
                          else
                            copy_file(input_handle, output_handle, hlp_file)
                          end

          # Verify size if expected
          if bytes_written != hlp_file.length && Cabriolet.verbose
            warn "[Cabriolet] WARNING: extracted #{bytes_written} bytes, " \
                 "expected #{hlp_file.length} bytes"
          end

          bytes_written
        ensure
          @io_system.close(input_handle) if input_handle
          @io_system.close(output_handle) if output_handle
        end
      end

      # Extract a file to memory
      #
      # @param header [Models::HLPHeader] HLP header from open()
      # @param hlp_file [Models::HLPFile] File to extract
      # @return [String] Extracted data
      # @raise [Errors::DecompressionError] if extraction fails
      def extract_file_to_memory(header, hlp_file)
        raise ArgumentError, "Header must not be nil" unless header
        raise ArgumentError, "HLP file must not be nil" unless hlp_file

        input_handle = @io_system.open(header.filename, Constants::MODE_READ)
        output_handle = System::MemoryHandle.new("", Constants::MODE_WRITE)

        begin
          # Seek to file data
          @io_system.seek(input_handle, hlp_file.offset,
                          Constants::SEEK_START)

          if hlp_file.compressed?
            decompress_file(input_handle, output_handle, hlp_file)
          else
            copy_file(input_handle, output_handle, hlp_file)
          end

          output_handle.data
        ensure
          @io_system.close(input_handle) if input_handle
        end
      end

      # Extract all files from HLP archive
      #
      # @param header [Models::HLPHeader] HLP header from open()
      # @param output_dir [String] Directory to extract files to
      # @return [Integer] Number of files extracted
      # @raise [Errors::DecompressionError] if extraction fails
      def extract_all(header, output_dir)
        raise ArgumentError, "Header must not be nil" unless header
        raise ArgumentError, "Output directory must not be nil" unless
          output_dir

        # Create output directory if needed
        FileUtils.mkdir_p(output_dir)

        extracted = 0
        header.files.each do |hlp_file|
          output_path = ::File.join(output_dir, hlp_file.filename)

          # Create subdirectories if needed
          output_subdir = ::File.dirname(output_path)
          FileUtils.mkdir_p(output_subdir)

          extract_file(header, hlp_file, output_path)
          extracted += 1
        end

        extracted
      end

      private

      # Decompress a file using LZSS MODE_MSHELP
      #
      # @param input_handle [System::FileHandle] Input file handle
      # @param output_handle [System::FileHandle, System::MemoryHandle]
      #   Output handle
      # @param hlp_file [Models::HLPFile] File metadata
      # @return [Integer] Number of bytes written
      def decompress_file(input_handle, output_handle, hlp_file)
        # Create LZSS decompressor with MODE_MSHELP
        decompressor = Decompressors::LZSS.new(
          @io_system,
          input_handle,
          output_handle,
          @buffer_size,
          Decompressors::LZSS::MODE_MSHELP,
        )

        # Decompress
        decompressor.decompress(hlp_file.compressed_length)
      end

      # Copy uncompressed file data
      #
      # @param input_handle [System::FileHandle] Input file handle
      # @param output_handle [System::FileHandle, System::MemoryHandle]
      #   Output handle
      # @param hlp_file [Models::HLPFile] File metadata
      # @return [Integer] Number of bytes written
      def copy_file(input_handle, output_handle, hlp_file)
        bytes_written = 0
        remaining = hlp_file.length

        while remaining.positive?
          chunk_size = [remaining, @buffer_size].min
          data = @io_system.read(input_handle, chunk_size)
          break if data.empty?

          written = @io_system.write(output_handle, data)
          bytes_written += written
          remaining -= written
        end

        bytes_written
      end
    end
  end
end
