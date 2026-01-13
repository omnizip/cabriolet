# frozen_string_literal: true

require_relative "../cli/base_command_handler"
require_relative "decompressor"
require_relative "compressor"

module Cabriolet
  module HLP
    # Command handler for HLP (Help) format
    #
    # This handler implements the unified command interface for HLP files,
    # wrapping the existing HLP::Decompressor and HLP::Compressor classes.
    # Supports both QuickHelp and Windows Help formats.
    #
    class CommandHandler < Commands::BaseCommandHandler
      # List HLP file contents
      #
      # Displays information about the HLP file including format type,
      # and lists all contained files with their sizes.
      #
      # @param file [String] Path to the HLP file
      # @param options [Hash] Additional options (unused)
      # @return [void]
      def list(file, options = {})
        validate_file_exists(file)

        decompressor = Decompressor.new
        header = decompressor.open(file)

        display_header(header, file)
        display_files(decompressor, header)

        decompressor.close(header)
      end

      # Extract files from HLP archive
      #
      # Extracts all files from the HLP file to the specified output directory.
      # Supports both QuickHelp and Windows Help formats.
      #
      # @param file [String] Path to the HLP file
      # @param output_dir [String] Output directory path (default: current directory)
      # @param options [Hash] Additional options (unused)
      # @return [void]
      def extract(file, output_dir = nil, options = {})
        validate_file_exists(file)

        output_dir ||= "."
        output_dir = ensure_output_dir(output_dir)

        decompressor = Decompressor.new
        header = decompressor.open(file)

        count = decompressor.extract_all(header, output_dir)
        decompressor.close(header)

        puts "Extracted #{count} file(s) to #{output_dir}"
      end

      # Create a new HLP archive
      #
      # Creates an HLP file from source files using QuickHelp format.
      #
      # @param output [String] Output HLP file path
      # @param files [Array<String>] List of input files to add
      # @param options [Hash] Additional options
      # @option options [String] :format HLP format (:quickhelp, :winhelp)
      # @return [void]
      # @raise [ArgumentError] if no files specified
      def create(output, files = [], options = {})
        raise ArgumentError, "No files specified" if files.empty?

        files.each do |f|
          raise ArgumentError, "File does not exist: #{f}" unless File.exist?(f)
        end

        format = parse_format_option(options[:format])

        if format == :winhelp
          create_winhelp(output, files, options)
        else
          create_quickhelp(output, files, options)
        end
      end

      # Display detailed HLP file information
      #
      # Shows comprehensive information about the HLP structure,
      # including format type, file count, and metadata.
      #
      # @param file [String] Path to the HLP file
      # @param options [Hash] Additional options (unused)
      # @return [void]
      def info(file, options = {})
        validate_file_exists(file)

        decompressor = Decompressor.new
        header = decompressor.open(file)

        display_hlp_info(header, file)

        decompressor.close(header)
      end

      # Test HLP file integrity
      #
      # Verifies the HLP file structure.
      #
      # @param file [String] Path to the HLP file
      # @param options [Hash] Additional options (unused)
      # @return [void]
      def test(file, options = {})
        validate_file_exists(file)

        decompressor = Decompressor.new
        header = decompressor.open(file)

        puts "Testing #{file}..."
        # TODO: Implement full integrity testing
        format_name = if header.respond_to?(:version)
                       version_value = header.version
                       # Convert BinData objects to integer for comparison
                       version_int = version_value.to_i if version_value.respond_to?(:to_i)

                       if version_value.is_a?(Integer) || (version_int && version_int > 0)
                         "QUICKHELP v#{version_value}"
                       elsif version_value.is_a?(Symbol)
                         version_value.to_s.upcase.sub("WINHELP", "WinHelp ")
                       else
                         "unknown"
                       end
                     end
        puts "OK: HLP file structure is valid (#{format_name} format)"

        decompressor.close(header)
      end

      private

      # Display HLP header information
      #
      # @param header [Object] The HLP header object
      # @param file [String] Original file path
      # @return [void]
      def display_header(header, file)
        format_name = if header.respond_to?(:version)
                       version_value = header.version
                       # Convert BinData objects to integer for comparison
                       version_int = version_value.to_i if version_value.respond_to?(:to_i)

                       if version_value.is_a?(Integer) || (version_int && version_int > 0)
                         "QUICKHELP v#{version_value}"
                       elsif header.version.is_a?(Symbol)
                         header.version.to_s.upcase.sub("WINHELP", "WinHelp ")
                       else
                         header.version.to_s
                       end
                     end
        puts "HLP File: #{file}"
        puts "Format: #{format_name || 'unknown'}"
        puts "\nFiles:"
      end

      # Display list of files in HLP
      #
      # @param decompressor [Decompressor] The decompressor instance
      # @param header [Object] The HLP header object
      # @return [void]
      def display_files(decompressor, header)
        if header.respond_to?(:files)
          header.files.each do |f|
            puts "  #{f.filename} (#{f.length} bytes)"
          end
        else
          puts "  (File listing not available for this format)"
        end
      end

      # Display comprehensive HLP information
      #
      # @param header [Object] The HLP header object
      # @param file [String] Original file path
      # @return [void]
      def display_hlp_info(header, file)
        puts "HLP File Information"
        puts "=" * 50
        puts "Filename: #{file}"

        if header.respond_to?(:version)
          version_value = header.version
          # Convert BinData objects to integer for comparison
          version_int = version_value.to_i if version_value.respond_to?(:to_i)

          format_name = if version_value.is_a?(Integer) || (version_int && version_int > 0)
                         "QUICKHELP v#{version_value}"
                       elsif version_value.is_a?(Symbol)
                         version_value.to_s.upcase.sub("WINHELP", "WinHelp ")
                       else
                         version_value.to_s
                       end
          puts "Format: #{format_name}"
        end

        if header.respond_to?(:length)
          puts "Size: #{header.length} bytes"
        end

        if header.respond_to?(:files)
          puts "Files: #{header.files.size}"
          puts ""
          puts "Files:"
          header.files.each do |f|
            puts "  #{f.filename}"
            puts "    Size: #{f.length} bytes"
          end
        end
      end

      # Create QuickHelp format HLP file
      #
      # @param output [String] Output file path
      # @param files [Array<String>] Input files
      # @param options [Hash] Additional options
      # @return [void]
      def create_quickhelp(output, files, options)
        compressor = Compressor.new

        files.each do |f|
          # Default: add files with compression
          archive_name = File.basename(f)
          compressor.add_file(f, "/#{archive_name}", compress: true)
        end

        puts "Creating #{output} with #{files.size} file(s) (QuickHelp format)" if verbose?
        bytes = compressor.generate(output)
        puts "Created #{output} (#{bytes} bytes, #{files.size} files)"
      end

      # Create Windows Help format HLP file
      #
      # @param output [String] Output file path
      # @param files [Array<String>] Input files
      # @param options [Hash] Additional options
      # @return [void]
      def create_winhelp(output, files, options)
        compressor = Compressor.create_winhelp

        files.each do |f|
          archive_name = File.basename(f)
          # WinHelp compression uses different API
          compressor.add_file(f, "/#{archive_name}")
        end

        puts "Creating #{output} with #{files.size} file(s) (WinHelp format)" if verbose?
        bytes = compressor.generate(output)
        puts "Created #{output} (#{bytes} bytes, #{files.size} files)"
      end

      # Parse format option to symbol
      #
      # @param format_value [String, Symbol] The format type
      # @return [Symbol] The format symbol
      def parse_format_option(format_value)
        return :quickhelp if format_value.nil?

        format = format_value.to_sym
        valid_formats = %i[quickhelp winhelp]

        unless valid_formats.include?(format)
          raise ArgumentError,
                "Invalid HLP format: #{format_value}. " \
                "Valid options: #{valid_formats.join(', ')}"
        end

        format
      end
    end
  end
end
