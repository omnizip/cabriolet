# frozen_string_literal: true

module Cabriolet
  module SZDD
    # Decompressor is the main interface for SZDD file operations
    #
    # SZDD files use LZSS compression and are decompressed using the
    # Decompressors::LZSS class with appropriate mode settings.
    class Decompressor
      attr_reader :io_system, :parser
      attr_accessor :buffer_size

      # Input buffer size for decompression
      DEFAULT_BUFFER_SIZE = 2048

      # Initialize a new SZDD decompressor
      #
      # @param io_system [System::IOSystem, nil] Custom I/O system or nil for
      #   default
      # @param algorithm_factory [AlgorithmFactory, nil] Custom algorithm factory or nil for default
      def initialize(io_system = nil, algorithm_factory = nil)
        @io_system = io_system || System::IOSystem.new
        @algorithm_factory = algorithm_factory || Cabriolet.algorithm_factory
        @parser = Parser.new(@io_system)
        @buffer_size = DEFAULT_BUFFER_SIZE
      end

      # Open and parse an SZDD file
      #
      # @param filename [String] Path to the SZDD file
      # @return [Models::SZDDHeader] Parsed header with file handle
      # @raise [Errors::ParseError] if the file is not a valid SZDD
      def open(filename)
        header = @parser.parse(filename)
        header.filename = filename
        header
      end

      # Close an SZDD file (no-op for compatibility)
      #
      # @param _header [Models::SZDDHeader] Header to close
      # @return [void]
      def close(_header)
        # No resources to free in the header itself
        # File handles are managed separately during extraction
        nil
      end

      # Extract an SZDD file to output
      #
      # @param header [Models::SZDDHeader] SZDD header from open()
      # @param output_path [String] Where to write the decompressed file
      # @return [Integer] Number of bytes written
      # @raise [Errors::DecompressionError] if decompression fails
      def extract(header, output_path)
        raise ArgumentError, "Header must not be nil" unless header
        raise ArgumentError, "Output path must not be nil" unless output_path

        input_handle = @io_system.open(header.filename, Constants::MODE_READ)
        output_handle = @io_system.open(output_path, Constants::MODE_WRITE)

        begin
          # Seek to compressed data start
          data_offset = @parser.data_offset(header.format)
          @io_system.seek(input_handle, data_offset, Constants::SEEK_START)

          # Determine LZSS mode based on format
          lzss_mode = if header.normal_format?
                        Decompressors::LZSS::MODE_EXPAND
                      else
                        Decompressors::LZSS::MODE_QBASIC
                      end

          # Create LZSS decompressor
          decompressor = @algorithm_factory.create(
            :lzss,
            :decompressor,
            @io_system,
            input_handle,
            output_handle,
            @buffer_size,
            mode: lzss_mode
          )

          # Decompress (SZDD reads until EOF, no compressed size stored)
          bytes_written = decompressor.decompress(nil)

          # Verify decompressed size matches expected
          if bytes_written != header.length && Cabriolet.verbose && Cabriolet.verbose
            warn "[Cabriolet] WARNING; decompressed #{bytes_written} bytes, " \
                 "expected #{header.length} bytes"
          end

          bytes_written
        ensure
          @io_system.close(input_handle) if input_handle
          @io_system.close(output_handle) if output_handle
        end
      end

      # Extract SZDD file to memory
      #
      # @param header [Models::SZDDHeader] SZDD header from open()
      # @return [String] Decompressed data
      # @raise [Errors::DecompressionError] if decompression fails
      def extract_to_memory(header)
        raise ArgumentError, "Header must not be nil" unless header

        input_handle = @io_system.open(header.filename, Constants::MODE_READ)
        output_handle = System::MemoryHandle.new("", Constants::MODE_WRITE)

        begin
          # Seek to compressed data start
          data_offset = @parser.data_offset(header.format)
          @io_system.seek(input_handle, data_offset, Constants::SEEK_START)

          # Determine LZSS mode based on format
          lzss_mode = if header.normal_format?
                        Decompressors::LZSS::MODE_EXPAND
                      else
                        Decompressors::LZSS::MODE_QBASIC
                      end

          # Create LZSS decompressor
          decompressor = @algorithm_factory.create(
            :lzss,
            :decompressor,
            @io_system,
            input_handle,
            output_handle,
            @buffer_size,
            mode: lzss_mode
          )

          # Decompress (SZDD reads until EOF, no compressed size stored)
          decompressor.decompress(nil)

          # Return the decompressed data
          output_handle.data
        ensure
          @io_system.close(input_handle) if input_handle
        end
      end

      # One-shot decompression from input file to output file
      #
      # This method combines open(), extract(), and close() for convenience.
      # Similar to MS-DOS EXPAND.EXE behavior.
      #
      # @param input_path [String] Path to compressed SZDD file
      # @param output_path [String, nil] Path to output file, or nil to
      #   auto-detect
      # @return [Integer] Number of bytes written
      # @raise [Errors::ParseError] if input is not valid SZDD
      # @raise [Errors::DecompressionError] if decompression fails
      def decompress(input_path, output_path = nil)
        # Parse header
        header = self.open(input_path)

        # Auto-detect output filename if not provided
        output_path ||= auto_output_filename(input_path, header)

        # Extract
        bytes_written = extract(header, output_path)

        # Close (no-op but kept for API consistency)
        close(header)

        bytes_written
      end

      # Generate output filename from input filename and header
      #
      # @param input_path [String] Input file path
      # @param header [Models::SZDDHeader] SZDD header
      # @return [String] Suggested output filename
      def auto_output_filename(input_path, header)
        # Get base filename without directory
        base = ::File.basename(input_path)

        # Use header's suggested filename method
        suggested = header.suggested_filename(base)

        # Combine with original directory
        dir = ::File.dirname(input_path)
        ::File.join(dir, suggested)
      end
    end
  end
end
