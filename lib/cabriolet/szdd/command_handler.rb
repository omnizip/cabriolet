# frozen_string_literal: true

require_relative "../cli/base_command_handler"
require_relative "decompressor"
require_relative "compressor"

module Cabriolet
  module SZDD
    # Command handler for SZDD (LZSS-compressed) format
    #
    # This handler implements the unified command interface for SZDD files,
    # wrapping the existing SZDD::Decompressor and SZDD::Compressor classes.
    #
    class CommandHandler < Commands::BaseCommandHandler
      # List SZDD file information
      #
      # For SZDD files, list displays detailed file information
      # rather than a file listing (single file archive).
      #
      # @param file [String] Path to the SZDD file
      # @param options [Hash] Additional options (unused)
      # @return [void]
      def list(file, _options = {})
        validate_file_exists(file)

        decompressor = Decompressor.new
        header = decompressor.open(file)

        display_szdd_info(header, file)

        decompressor.close(header)
      end

      # Extract SZDD compressed file
      #
      # Expands the SZDD file to its original form.
      # Auto-detects output filename if not specified.
      #
      # @param file [String] Path to the SZDD file
      # @param output [String, nil] Output file path (or directory, for single-file extraction)
      # @param options [Hash] Additional options
      # @option options [String] :output Output file path
      # @return [void]
      def extract(file, output = nil, options = {})
        validate_file_exists(file)

        # Use output file from options if specified, otherwise use positional argument
        output ||= options[:output]

        # Auto-detect output name if not provided
        output ||= auto_output_filename(file)

        decompressor = Decompressor.new
        header = decompressor.open(file)

        puts "Expanding #{file} -> #{output}" if verbose?
        bytes = decompressor.extract(header, output)
        decompressor.close(header)

        puts "Expanded #{file} to #{output} (#{bytes} bytes)"
      end

      # Create SZDD compressed file
      #
      # Compresses a file using SZDD (LZSS) compression.
      #
      # @param output [String] Output SZDD file path
      # @param files [Array<String>] Input file (single file for SZDD)
      # @param options [Hash] Additional options
      # @option options [String] :missing_char Missing character for filename
      # @option options [String] :szdd_format SZDD format (:normal, :qbasic)
      # @return [void]
      # @raise [ArgumentError] if no file specified or multiple files
      def create(output, files = [], options = {})
        raise ArgumentError, "No file specified" if files.empty?

        if files.size > 1
          raise ArgumentError,
                "SZDD format supports only one file at a time"
        end

        file = files.first
        unless File.exist?(file)
          raise ArgumentError,
                "File does not exist: #{file}"
        end

        format = parse_format_option(options[:szdd_format])
        compress_options = { format: format }
        if options[:missing_char]
          compress_options[:missing_char] =
            options[:missing_char]
        end

        # Auto-generate output name if not provided
        if output.nil?
          output = auto_generate_output(file)
        end

        compressor = Compressor.new

        puts "Compressing #{file} -> #{output}" if verbose?
        bytes = compressor.compress(file, output, **compress_options)

        puts "Compressed #{file} to #{output} (#{bytes} bytes)"
      end

      # Display detailed SZDD file information
      #
      # @param file [String] Path to the SZDD file
      # @param options [Hash] Additional options (unused)
      # @return [void]
      def info(file, _options = {})
        validate_file_exists(file)

        decompressor = Decompressor.new
        header = decompressor.open(file)

        display_szdd_info(header, file)

        decompressor.close(header)
      end

      # Test SZDD file integrity
      #
      # Verifies the SZDD file structure.
      #
      # @param file [String] Path to the SZDD file
      # @param options [Hash] Additional options (unused)
      # @return [void]
      def test(file, _options = {})
        validate_file_exists(file)

        decompressor = Decompressor.new
        header = decompressor.open(file)

        puts "Testing #{file}..."
        # TODO: Implement full integrity testing
        puts "OK: SZDD file structure is valid"
        puts "Format: #{header.format.to_s.upcase}"
        puts "Uncompressed size: #{header.length} bytes"

        decompressor.close(header)
      end

      private

      # Display SZDD file information
      #
      # @param header [Header] The SZDD header object
      # @param file [String] Original file path
      # @return [void]
      def display_szdd_info(header, file)
        puts "SZDD File Information"
        puts "=" * 50
        puts "Filename: #{file}"
        puts "Format: #{header.format.to_s.upcase}"
        puts "Uncompressed size: #{header.length} bytes"
        if header.missing_char
          puts "Missing character: '#{header.missing_char}'"
          puts "Suggested filename: #{header.suggested_filename(File.basename(file))}"
        end
      end

      # Auto-detect output filename from SZDD header
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

      # Auto-generate output filename for SZDD
      #
      # SZDD convention: file.txt -> file.tx_
      #
      # @param file [String] Original file path
      # @return [String] Generated output filename
      def auto_generate_output(file)
        # Replace extension last character with underscore
        # file.txt -> file.tx_
        ext = File.extname(file)
        if ext.length == 2 # Single char extension like .c
          base = File.basename(file, ext)
          output = "#{base}#{ext[0]}_"
        else
          # For no extension or multi-char extension, just append _
          output = "#{file}_"
        end
        output
      end

      # Parse format option to symbol
      #
      # @param format_value [String, Symbol] The format type
      # @return [Symbol] The format symbol
      def parse_format_option(format_value)
        return :normal if format_value.nil?

        format = format_value.to_sym
        valid_formats = %i[normal qbasic]

        unless valid_formats.include?(format)
          raise ArgumentError,
                "Invalid SZDD format: #{format_value}. " \
                "Valid options: #{valid_formats.join(', ')}"
        end

        format
      end
    end
  end
end
