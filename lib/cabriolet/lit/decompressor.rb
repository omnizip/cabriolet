# frozen_string_literal: true

module Cabriolet
  module LIT
    # Decompressor is the main interface for LIT file operations
    #
    # LIT files are Microsoft Reader eBook files that use LZX compression.
    #
    # NOTE: This implementation handles non-encrypted LIT files only.
    # DES-encrypted (DRM-protected) LIT files are not supported.
    # For encrypted files, use Microsoft Reader or convert to another format
    # first.
    class Decompressor
      attr_reader :io_system
      attr_accessor :buffer_size

      # Input buffer size for decompression
      DEFAULT_BUFFER_SIZE = 32_768

      # Initialize a new LIT decompressor
      #
      # @param io_system [System::IOSystem, nil] Custom I/O system or nil for
      #   default
      def initialize(io_system = nil)
        @io_system = io_system || System::IOSystem.new
        @buffer_size = DEFAULT_BUFFER_SIZE
      end

      # Open and parse a LIT file
      #
      # @param filename [String] Path to the LIT file
      # @return [Models::LITHeader] Parsed header with file list
      # @raise [Errors::ParseError] if the file is not a valid LIT
      # @raise [NotImplementedError] if the file is DES-encrypted
      def open(filename)
        header = parse_header(filename)
        header.filename = filename

        # Check for encryption
        if header.encrypted?
          raise NotImplementedError,
                "DES-encrypted LIT files not yet supported. " \
                "Use Microsoft Reader or another tool to decrypt first."
        end

        header
      end

      # Close a LIT file (no-op for compatibility)
      #
      # @param _header [Models::LITHeader] Header to close
      # @return [void]
      def close(_header)
        # No resources to free in the header itself
        # File handles are managed separately during extraction
        nil
      end

      # Extract a file from LIT archive
      #
      # @param header [Models::LITHeader] LIT header from open()
      # @param file [Models::LITFile] File entry to extract
      # @param output_path [String] Where to write the decompressed file
      # @return [Integer] Number of bytes written
      # @raise [Errors::DecompressionError] if decompression fails
      # @raise [NotImplementedError] if the file is encrypted
      def extract(header, file, output_path)
        raise ArgumentError, "Header must not be nil" unless header
        raise ArgumentError, "File must not be nil" unless file
        raise ArgumentError, "Output path must not be nil" unless output_path

        if file.encrypted?
          raise NotImplementedError,
                "DES-encrypted files not yet supported. " \
                "Use Microsoft Reader or another tool to decrypt first."
        end

        input_handle = @io_system.open(header.filename, Constants::MODE_READ)
        output_handle = @io_system.open(output_path, Constants::MODE_WRITE)

        begin
          # Seek to file data
          @io_system.seek(input_handle, file.offset, Constants::SEEK_START)

          bytes_written = if file.compressed?
                            # Decompress using LZX
                            decompress_lzx(
                              input_handle, output_handle, file.length
                            )
                          else
                            # Direct copy
                            copy_data(
                              input_handle, output_handle, file.length
                            )
                          end

          bytes_written
        ensure
          @io_system.close(input_handle) if input_handle
          @io_system.close(output_handle) if output_handle
        end
      end

      # Extract all files from LIT archive
      #
      # @param header [Models::LITHeader] LIT header from open()
      # @param output_dir [String] Directory to extract files to
      # @return [Integer] Number of files extracted
      # @raise [Errors::DecompressionError] if extraction fails
      def extract_all(header, output_dir)
        raise ArgumentError, "Header must not be nil" unless header
        raise ArgumentError, "Output dir must not be nil" unless output_dir

        # Create output directory if it doesn't exist
        ::FileUtils.mkdir_p(output_dir)

        extracted = 0
        header.files.each do |file|
          output_path = ::File.join(output_dir, file.filename)

          # Create subdirectories if needed
          file_dir = ::File.dirname(output_path)
          ::FileUtils.mkdir_p(file_dir) unless ::File.directory?(file_dir)

          extract(header, file, output_path)
          extracted += 1
        end

        extracted
      end

      private

      # Parse LIT file header
      #
      # @param filename [String] Path to LIT file
      # @return [Models::LITHeader] Parsed header
      # @raise [Errors::ParseError] if file is not valid LIT
      def parse_header(filename)
        handle = @io_system.open(filename, Constants::MODE_READ)

        begin
          # Read and verify signature
          signature = @io_system.read(handle, 8)
          unless signature.start_with?(Binary::LITStructures::SIGNATURE[0..3])
            raise Errors::ParseError,
                  "Not a valid LIT file: invalid signature"
          end

          # Seek back to start
          @io_system.seek(handle, 0, Constants::SEEK_START)

          # Read header structure
          header_data = @io_system.read(handle, 24)
          lit_header = Binary::LITStructures::LITHeader.read(header_data)

          # Create header model
          header = Models::LITHeader.new
          header.version = lit_header.version
          header.encrypted = lit_header.flags.anybits?(0x01)

          # Parse file entries
          header.files = parse_file_entries(
            handle, lit_header.file_count
          )

          header
        ensure
          @io_system.close(handle) if handle
        end
      end

      # Parse file entries from LIT archive
      #
      # @param handle [System::FileHandle] File handle positioned at file
      #   entries
      # @param file_count [Integer] Number of files to parse
      # @return [Array<Models::LITFile>] List of file entries
      def parse_file_entries(handle, file_count)
        files = []

        file_count.times do
          # Read filename length
          len_data = @io_system.read(handle, 4)
          filename_length = len_data.unpack1("V")

          # Read filename
          filename = @io_system.read(handle, filename_length)

          # Read file metadata
          metadata = @io_system.read(handle, 28)
          offset, _, uncompressed_size, flags =
            metadata.unpack("QQQV")

          # Create file entry
          file = Models::LITFile.new
          file.filename = filename
          file.offset = offset
          file.length = uncompressed_size
          file.compressed = flags.anybits?(Binary::LITStructures::FileFlags::COMPRESSED)
          file.encrypted = flags.anybits?(Binary::LITStructures::FileFlags::ENCRYPTED)

          files << file
        end

        files
      end

      # Decompress data using LZX
      #
      # @param input_handle [System::FileHandle] Input handle
      # @param output_handle [System::FileHandle] Output handle
      # @param expected_size [Integer] Expected output size
      # @return [Integer] Number of bytes written
      def decompress_lzx(input_handle, output_handle, expected_size)
        decompressor = Decompressors::LZX.new(
          @io_system,
          input_handle,
          output_handle,
          @buffer_size,
        )

        decompressor.decompress(expected_size)
      end

      # Copy data directly without decompression
      #
      # @param input_handle [System::FileHandle] Input handle
      # @param output_handle [System::FileHandle] Output handle
      # @param size [Integer] Number of bytes to copy
      # @return [Integer] Number of bytes written
      def copy_data(input_handle, output_handle, size)
        bytes_written = 0
        remaining = size

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
