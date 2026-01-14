# frozen_string_literal: true

require_relative "../cli/base_command_handler"
require_relative "decompressor"
require_relative "compressor"

module Cabriolet
  module KWAJ
    # Command handler for KWAJ compressed format
    #
    # This handler implements the unified command interface for KWAJ files,
    # wrapping the existing KWAJ::Decompressor and KWAJ::Compressor classes.
    #
    class CommandHandler < Commands::BaseCommandHandler
      # List KWAJ file information
      #
      # For KWAJ files, list displays detailed file information
      # rather than a file listing (single file archive).
      #
      # @param file [String] Path to the KWAJ file
      # @param options [Hash] Additional options (unused)
      # @return [void]
      def list(file, _options = {})
        validate_file_exists(file)

        decompressor = Decompressor.new
        header = decompressor.open(file)

        display_kwaj_info(header, file)

        decompressor.close(header)
      end

      # Extract KWAJ compressed file
      #
      # Extracts/decompresses the KWAJ file to its original form.
      # Auto-detects output filename if not specified.
      #
      # @param file [String] Path to the KWAJ file
      # @param output_dir [String] Output directory (not typically used for KWAJ)
      # @param options [Hash] Additional options
      # @option options [String] :output Output file path
      # @return [void]
      def extract(file, output_dir = nil, options = {})
        validate_file_exists(file)

        output = options[:output]

        # Auto-detect output name if not provided
        if output.nil? && output_dir.nil?
          output = auto_output_filename(file)
        end

        # If output_dir is specified, ensure it exists and construct output path
        if output.nil? && output_dir
          output_dir = ensure_output_dir(output_dir)
          base_name = File.basename(file, ".*")
          output = File.join(output_dir, base_name)
        end

        decompressor = Decompressor.new
        header = decompressor.open(file)

        puts "Extracting #{file} -> #{output}" if verbose?
        bytes = decompressor.extract(header, file, output)
        decompressor.close(header)

        puts "Extracted #{file} to #{output} (#{bytes} bytes)"
      end

      # Create KWAJ compressed file
      #
      # Compresses a file using KWAJ compression.
      #
      # @param output [String] Output KWAJ file path
      # @param files [Array<String>] Input file (single file for KWAJ)
      # @param options [Hash] Additional options
      # @option options [String] :compression Compression method (:none, :xor, :szdd, :mszip)
      # @option options [Boolean] :include_length Include uncompressed length
      # @option options [String] :filename Original filename to embed
      # @option options [String] :extra_data Extra data to include
      # @return [void]
      # @raise [ArgumentError] if no file specified or multiple files
      def create(output, files = [], options = {})
        raise ArgumentError, "No file specified" if files.empty?

        if files.size > 1
          raise ArgumentError,
                "KWAJ format supports only one file at a time"
        end

        file = files.first
        unless File.exist?(file)
          raise ArgumentError,
                "File does not exist: #{file}"
        end

        compression = parse_compression_option(options[:compression])
        compress_options = { compression: compression }

        compress_options[:include_length] = true if options[:include_length]
        compress_options[:filename] = options[:filename] if options[:filename]
        if options[:extra_data]
          compress_options[:extra_data] =
            options[:extra_data]
        end

        # Auto-generate output name if not provided
        if output.nil?
          output = "#{file}.kwj"
        end

        compressor = Compressor.new

        puts "Compressing #{file} -> #{output} (#{compression} compression)" if verbose?
        bytes = compressor.compress(file, output, **compress_options)

        puts "Compressed #{file} to #{output} (#{bytes} bytes, #{compression} compression)"
      end

      # Display detailed KWAJ file information
      #
      # @param file [String] Path to the KWAJ file
      # @param options [Hash] Additional options (unused)
      # @return [void]
      def info(file, _options = {})
        validate_file_exists(file)

        decompressor = Decompressor.new
        header = decompressor.open(file)

        display_kwaj_info(header, file)

        decompressor.close(header)
      end

      # Test KWAJ file integrity
      #
      # Verifies the KWAJ file structure.
      #
      # @param file [String] Path to the KWAJ file
      # @param options [Hash] Additional options (unused)
      # @return [void]
      def test(file, _options = {})
        validate_file_exists(file)

        decompressor = Decompressor.new
        header = decompressor.open(file)

        puts "Testing #{file}..."
        # TODO: Implement full integrity testing
        puts "OK: KWAJ file structure is valid"
        puts "Compression: #{header.compression_name}"
        puts "Data offset: #{header.data_offset} bytes"
        puts "Uncompressed size: #{header.length || 'unknown'} bytes"

        decompressor.close(header)
      end

      private

      # Display KWAJ file information
      #
      # @param header [Header] The KWAJ header object
      # @param file [String] Original file path
      # @return [void]
      def display_kwaj_info(header, file)
        puts "KWAJ File Information"
        puts "=" * 50
        puts "Filename: #{file}"
        puts "Compression: #{header.compression_name}"
        puts "Data offset: #{header.data_offset} bytes"
        puts "Uncompressed size: #{header.length || 'unknown'} bytes"
        puts "Original filename: #{header.filename}" if header.filename
        if header.extra && !header.extra.empty?
          puts "Extra data: #{header.extra_length} bytes"
          puts "  #{header.extra}"
        end
      end

      # Auto-detect output filename from KWAJ header
      #
      # @param file [String] Original file path
      # @return [String] Detected output filename
      def auto_output_filename(file)
        decompressor = Decompressor.new
        header = decompressor.open(file)
        output = decompressor.auto_output_filename(file, header)
        decompressor.close(header)
        output
      end

      # Parse compression option to symbol
      #
      # @param compression_value [String, Symbol] The compression type
      # @return [Symbol] The compression symbol
      def parse_compression_option(compression_value)
        return :szdd if compression_value.nil?

        compression = compression_value.to_sym
        valid_compressions = %i[none xor szdd mszip]

        unless valid_compressions.include?(compression)
          raise ArgumentError,
                "Invalid compression: #{compression_value}. " \
                "Valid options: #{valid_compressions.join(', ')}"
        end

        compression
      end
    end
  end
end
