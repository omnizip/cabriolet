# frozen_string_literal: true

module Cabriolet
  module KWAJ
    # Decompressor is the main interface for KWAJ file operations
    #
    # KWAJ files support multiple compression methods:
    # - NONE: Direct copy
    # - XOR: XOR with 0xFF then copy
    # - SZDD: LZSS compression
    # - LZH: LZSS with Huffman (not fully implemented)
    # - MSZIP: DEFLATE compression
    class Decompressor
      attr_reader :io_system, :parser
      attr_accessor :buffer_size

      # Input buffer size for decompression
      DEFAULT_BUFFER_SIZE = 2048

      # Initialize a new KWAJ decompressor
      #
      # @param io_system [System::IOSystem, nil] Custom I/O system or nil for
      #   default
      def initialize(io_system = nil)
        @io_system = io_system || System::IOSystem.new
        @parser = Parser.new(@io_system)
        @buffer_size = DEFAULT_BUFFER_SIZE
      end

      # Open and parse a KWAJ file
      #
      # @param filename [String] Path to the KWAJ file
      # @return [Models::KWAJHeader] Parsed header
      # @raise [Errors::ParseError] if the file is not a valid KWAJ
      def open(filename)
        @parser.parse(filename)
      end

      # Close a KWAJ file (no-op for compatibility)
      #
      # @param _header [Models::KWAJHeader] Header to close
      # @return [void]
      def close(_header)
        # No resources to free in the header itself
        # File handles are managed separately during extraction
        nil
      end

      # Extract a KWAJ file to output
      #
      # @param header [Models::KWAJHeader] KWAJ header from open()
      # @param filename [String] Input filename
      # @param output_path [String] Where to write the decompressed file
      # @return [Integer] Number of bytes written
      # @raise [Errors::DecompressionError] if decompression fails
      def extract(header, filename, output_path)
        raise ArgumentError, "Header must not be nil" unless header
        raise ArgumentError, "Output path must not be nil" unless output_path

        input_handle = @io_system.open(filename, Constants::MODE_READ)
        output_handle = @io_system.open(output_path, Constants::MODE_WRITE)

        begin
          # Seek to compressed data start
          @io_system.seek(
            input_handle, header.data_offset, Constants::SEEK_START
          )

          # Decompress based on compression type
          bytes_written = decompress_data(
            header, input_handle, output_handle
          )

          # Verify decompressed size if known
          if header.length && bytes_written != header.length
            warn "[Cabriolet] WARNING: decompressed #{bytes_written} bytes, " \
                 "expected #{header.length} bytes"
          end

          bytes_written
        ensure
          @io_system.close(input_handle) if input_handle
          @io_system.close(output_handle) if output_handle
        end
      end

      # One-shot decompression from input file to output file
      #
      # @param input_path [String] Path to compressed KWAJ file
      # @param output_path [String, nil] Path to output file, or nil to
      #   auto-detect
      # @return [Integer] Number of bytes written
      # @raise [Errors::ParseError] if input is not valid KWAJ
      # @raise [Errors::DecompressionError] if decompression fails
      def decompress(input_path, output_path = nil)
        # Parse header
        header = open(input_path)

        # Auto-detect output filename if not provided
        output_path ||= auto_output_filename(input_path, header)

        # Extract
        bytes_written = extract(header, input_path, output_path)

        # Close (no-op but kept for API consistency)
        close(header)

        bytes_written
      end

      # Generate output filename from input filename and header
      #
      # @param input_path [String] Input file path
      # @param header [Models::KWAJHeader] KWAJ header
      # @return [String] Suggested output filename
      def auto_output_filename(input_path, header)
        # Use embedded filename if available
        if header.filename && !header.filename.empty?
          dir = ::File.dirname(input_path)
          return ::File.join(dir, header.filename)
        end

        # Fall back to removing extension
        base = ::File.basename(input_path, ".*")
        dir = ::File.dirname(input_path)
        ::File.join(dir, base)
      end

      private

      # Decompress data based on compression type
      #
      # @param header [Models::KWAJHeader] KWAJ header
      # @param input_handle [System::FileHandle] Input handle
      # @param output_handle [System::FileHandle] Output handle
      # @return [Integer] Number of bytes written
      # @raise [Errors::DecompressionError] if decompression fails
      def decompress_data(header, input_handle, output_handle)
        case header.comp_type
        when Constants::KWAJ_COMP_NONE
          decompress_none(input_handle, output_handle)
        when Constants::KWAJ_COMP_XOR
          decompress_xor(input_handle, output_handle)
        when Constants::KWAJ_COMP_SZDD
          decompress_szdd(input_handle, output_handle)
        when Constants::KWAJ_COMP_LZH
          decompress_lzh(input_handle, output_handle)
        when Constants::KWAJ_COMP_MSZIP
          decompress_mszip(input_handle, output_handle)
        else
          raise Errors::DecompressionError,
                "Unsupported compression type: #{header.comp_type}"
        end
      end

      # Decompress NONE type (direct copy)
      #
      # @param input_handle [System::FileHandle] Input handle
      # @param output_handle [System::FileHandle] Output handle
      # @return [Integer] Number of bytes written
      def decompress_none(input_handle, output_handle)
        bytes_written = 0
        loop do
          data = @io_system.read(input_handle, @buffer_size)
          break if data.empty?

          written = @io_system.write(output_handle, data)
          bytes_written += written
        end
        bytes_written
      end

      # Decompress XOR type (XOR with 0xFF then copy)
      #
      # @param input_handle [System::FileHandle] Input handle
      # @param output_handle [System::FileHandle] Output handle
      # @return [Integer] Number of bytes written
      def decompress_xor(input_handle, output_handle)
        bytes_written = 0
        loop do
          data = @io_system.read(input_handle, @buffer_size)
          break if data.empty?

          # XOR each byte with 0xFF
          xored = data.bytes.map { |b| b ^ 0xFF }.pack("C*")

          written = @io_system.write(output_handle, xored)
          bytes_written += written
        end
        bytes_written
      end

      # Decompress SZDD type (LZSS)
      #
      # @param input_handle [System::FileHandle] Input handle
      # @param output_handle [System::FileHandle] Output handle
      # @return [Integer] Number of bytes written
      def decompress_szdd(input_handle, output_handle)
        decompressor = Decompressors::LZSS.new(
          @io_system,
          input_handle,
          output_handle,
          @buffer_size,
          Decompressors::LZSS::MODE_QBASIC,
        )
        decompressor.decompress(0)
      end

      # Decompress LZH type (LZSS with Huffman)
      #
      # @param input_handle [System::FileHandle] Input handle
      # @param output_handle [System::FileHandle] Output handle
      # @return [Integer] Number of bytes written
      # @raise [Errors::DecompressionError] LZH not yet implemented
      def decompress_lzh(_input_handle, _output_handle)
        raise Errors::DecompressionError,
              "LZH compression type is not yet implemented. " \
              "This requires custom Huffman tree implementation."
      end

      # Decompress MSZIP type (DEFLATE)
      #
      # @param input_handle [System::FileHandle] Input handle
      # @param output_handle [System::FileHandle] Output handle
      # @return [Integer] Number of bytes written
      def decompress_mszip(input_handle, output_handle)
        decompressor = Decompressors::MSZIP.new(
          @io_system,
          input_handle,
          output_handle,
          @buffer_size,
        )
        decompressor.decompress(0)
      end
    end
  end
end
