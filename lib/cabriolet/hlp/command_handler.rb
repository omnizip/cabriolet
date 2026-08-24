# frozen_string_literal: true

module Cabriolet
  module HLP
    # Command handler for HLP (Help) format
    #
    # This handler implements the unified command interface for HLP files,
    # wrapping the existing HLP::Decompressor and HLP::Compressor classes.
    # Supports both QuickHelp and Windows Help formats.
    #
    class CommandHandler < Commands::BaseCommandHandler
      # Extract files from HLP archive
      #
      # Extracts all files from the HLP file to the specified output directory.
      # Supports both QuickHelp and Windows Help formats.
      #
      # @param file [String] Path to the HLP file
      # @param output_dir [String] Output directory path (default: current directory)
      # @param options [Hash] Additional options (unused)
      # @return [void]
      def extract(file, output_dir = nil, _options = {})
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

      private

      def decompressor_class
        Decompressor
      end

      # Show the HLP header followed by its files
      def render_listing(session, file, _options)
        header = session.archive
        display_header(header, file)
        display_files(header)
      end

      # Show comprehensive information about the HLP structure
      def render_info(session, file)
        display_hlp_info(session.archive, file)
      end

      def render_test_result(session)
        header = session.archive
        format_name = begin
          version_value = header.version
          # Convert BinData objects to integer for comparison
          version_int = Integer(version_value, exception: false)

          if version_value.is_a?(Integer) || version_int&.positive?
            "QUICKHELP v#{version_value}"
          elsif version_value.is_a?(Symbol)
            version_value.to_s.upcase.sub("WINHELP", "WinHelp ")
          else
            "unknown"
          end
        end
        puts "OK: HLP file structure is valid (#{format_name} format)"
      end

      # Display HLP header information
      #
      # @param header [Object] The HLP header object
      # @param file [String] Original file path
      # @return [void]
      def display_header(header, file)
        format_name = begin
          version_value = header.version
          # Convert BinData objects to integer for comparison
          version_int = Integer(version_value, exception: false)

          if version_value.is_a?(Integer) || version_int&.positive?
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
      # @param header [Object] The HLP header object
      # @return [void]
      def display_files(header)
        if header.files
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

        if header.version
          version_value = header.version
          # Convert BinData objects to integer for comparison
          version_int = Integer(version_value, exception: false)

          format_name = if version_value.is_a?(Integer) || version_int&.positive?
                          "QUICKHELP v#{version_value}"
                        elsif version_value.is_a?(Symbol)
                          version_value.to_s.upcase.sub("WINHELP", "WinHelp ")
                        else
                          version_value.to_s
                        end
          puts "Format: #{format_name}"
        end

        if header.length
          puts "Size: #{header.length} bytes"
        end

        if header.files
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
      def create_quickhelp(output, files, _options)
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
      def create_winhelp(output, files, _options)
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

        # Map :hlp to default :quickhelp format
        format = :quickhelp if format == :hlp

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
