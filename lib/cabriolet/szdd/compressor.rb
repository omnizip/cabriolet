# frozen_string_literal: true

module Cabriolet
  module SZDD
    # Compressor creates SZDD compressed files
    #
    # SZDD files wrap LZSS-compressed data with a header containing metadata
    # about the original file. The compressor supports both NORMAL (used by
    # MS-DOS EXPAND.EXE) and QBASIC formats.
    class Compressor
      attr_reader :io_system

      # Initialize a new SZDD compressor
      #
      # @param io_system [System::IOSystem, nil] Custom I/O system or nil for
      #   default
      def initialize(io_system = nil)
        @io_system = io_system || System::IOSystem.new
      end

      # Compress a file to SZDD format
      #
      # @param input_file [String] Path to input file
      # @param output_file [String] Path to output SZDD file
      # @param options [Hash] Compression options
      # @option options [String] :missing_char Last character of original
      #   filename for reconstruction
      # @option options [Symbol] :format Format to use (:normal or :qbasic,
      #   default: :normal)
      # @return [Integer] Bytes written to output file
      # @raise [Errors::CompressionError] if compression fails
      def compress(input_file, output_file, **options)
        format = options.fetch(:format, :normal)
        missing_char = options[:missing_char]

        validate_format(format)
        validate_missing_char(missing_char) if missing_char

        input_handle = @io_system.open(input_file, Constants::MODE_READ)
        output_handle = @io_system.open(output_file, Constants::MODE_WRITE)

        begin
          # Get input size
          input_size = @io_system.seek(input_handle, 0, Constants::SEEK_END)
          @io_system.seek(input_handle, 0, Constants::SEEK_START)

          # Write header
          header_bytes = write_header(
            output_handle,
            format,
            input_size,
            missing_char,
          )

          # Compress data using LZSS
          lzss_mode = if format == :normal
                        Compressors::LZSS::MODE_EXPAND
                      else
                        Compressors::LZSS::MODE_QBASIC
                      end

          compressor = Compressors::LZSS.new(
            @io_system,
            input_handle,
            output_handle,
            2048,
            lzss_mode,
          )

          compressed_bytes = compressor.compress

          header_bytes + compressed_bytes
        ensure
          @io_system.close(input_handle) if input_handle
          @io_system.close(output_handle) if output_handle
        end
      end

      # Compress data from memory to SZDD format
      #
      # @param data [String] Input data to compress
      # @param output_file [String] Path to output SZDD file
      # @param options [Hash] Compression options
      # @option options [String] :missing_char Last character of original
      #   filename
      # @option options [Symbol] :format Format to use (:normal or :qbasic,
      #   default: :normal)
      # @return [Integer] Bytes written to output file
      # @raise [Errors::CompressionError] if compression fails
      def compress_data(data, output_file, **options)
        format = options.fetch(:format, :normal)
        missing_char = options[:missing_char]

        validate_format(format)
        validate_missing_char(missing_char) if missing_char

        input_handle = System::MemoryHandle.new(data)
        output_handle = @io_system.open(output_file, Constants::MODE_WRITE)

        begin
          # Write header
          header_bytes = write_header(
            output_handle,
            format,
            data.bytesize,
            missing_char,
          )

          # Compress data using LZSS
          lzss_mode = if format == :normal
                        Compressors::LZSS::MODE_EXPAND
                      else
                        Compressors::LZSS::MODE_QBASIC
                      end

          compressor = Compressors::LZSS.new(
            @io_system,
            input_handle,
            output_handle,
            2048,
            lzss_mode,
          )

          compressed_bytes = compressor.compress

          header_bytes + compressed_bytes
        ensure
          @io_system.close(output_handle) if output_handle
        end
      end

      private

      # Write SZDD header to output
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param format [Symbol] Format to use (:normal or :qbasic)
      # @param uncompressed_size [Integer] Size of uncompressed data
      # @param missing_char [String, nil] Missing character or nil
      # @return [Integer] Number of bytes written
      def write_header(output_handle, format, uncompressed_size, missing_char)
        if format == :normal
          write_normal_header(output_handle, uncompressed_size, missing_char)
        else
          write_qbasic_header(output_handle, uncompressed_size)
        end
      end

      # Write NORMAL format header
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param uncompressed_size [Integer] Size of uncompressed data
      # @param missing_char [String, nil] Missing character or nil
      # @return [Integer] Number of bytes written (14 bytes)
      def write_normal_header(output_handle, uncompressed_size, missing_char)
        header = Binary::SZDDStructures::NormalHeader.new
        header.signature = Binary::SZDDStructures::SIGNATURE_NORMAL
        header.compression_mode = 0x41 # 'A'
        header.missing_char = missing_char ? missing_char.ord : 0x00
        header.uncompressed_size = uncompressed_size

        header_data = header.to_binary_s
        written = @io_system.write(output_handle, header_data)

        unless written == header_data.bytesize
          raise Errors::CompressionError,
                "Failed to write SZDD header"
        end

        written
      end

      # Write QBASIC format header
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param uncompressed_size [Integer] Size of uncompressed data
      # @return [Integer] Number of bytes written (12 bytes)
      def write_qbasic_header(output_handle, uncompressed_size)
        header = Binary::SZDDStructures::QBasicHeader.new
        header.signature = Binary::SZDDStructures::SIGNATURE_QBASIC
        header.uncompressed_size = uncompressed_size

        header_data = header.to_binary_s
        written = @io_system.write(output_handle, header_data)

        unless written == header_data.bytesize
          raise Errors::CompressionError,
                "Failed to write SZDD header"
        end

        written
      end

      # Validate format parameter
      #
      # @param format [Symbol] Format to validate
      # @raise [ArgumentError] if format is invalid
      def validate_format(format)
        return if %i[normal qbasic].include?(format)

        raise ArgumentError,
              "Format must be :normal or :qbasic, got #{format.inspect}"
      end

      # Validate missing character parameter
      #
      # @param missing_char [String] Missing character to validate
      # @raise [ArgumentError] if missing_char is invalid
      def validate_missing_char(missing_char)
        return if missing_char.is_a?(String) && missing_char.length == 1

        raise ArgumentError,
              "Missing character must be a single character string, got #{missing_char.inspect}"
      end
    end
  end
end
