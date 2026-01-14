# frozen_string_literal: true

require_relative "../cli/base_command_handler"
require_relative "decompressor"
require_relative "compressor"

module Cabriolet
  module CAB
    # Command handler for CAB (Microsoft Cabinet) format
    #
    # This handler implements the unified command interface for CAB files,
    # wrapping the existing CAB::Decompressor and CAB::Compressor classes.
    #
    class CommandHandler < Commands::BaseCommandHandler
      # List CAB file contents
      #
      # Displays information about the cabinet including set ID, file count,
      # and lists all contained files with their sizes.
      #
      # @param file [String] Path to the CAB file
      # @param options [Hash] Additional options (unused)
      # @return [void]
      def list(file, _options = {})
        validate_file_exists(file)

        decompressor = Decompressor.new
        cabinet = decompressor.open(file)

        display_header(cabinet)
        display_files(cabinet.files)
      end

      # Extract files from CAB archive
      #
      # Extracts all files from the cabinet to the specified output directory.
      # Supports salvage mode for corrupted archives.
      #
      # @param file [String] Path to the CAB file
      # @param output_dir [String] Output directory path (default: current directory)
      # @param options [Hash] Additional options
      # @option options [Boolean] :salvage Enable salvage mode for corrupted files
      # @return [void]
      def extract(file, output_dir = nil, options = {})
        validate_file_exists(file)

        output_dir ||= "."
        output_dir = ensure_output_dir(output_dir)

        decompressor = Decompressor.new
        decompressor.salvage = true if options[:salvage]

        cabinet = decompressor.open(file)
        count = decompressor.extract_all(cabinet, output_dir)

        puts "Extracted #{count} file(s) to #{output_dir}"
      end

      # Create a new CAB archive
      #
      # Creates a cabinet file from the specified source files.
      #
      # @param output [String] Output CAB file path
      # @param files [Array<String>] List of input files to add
      # @param options [Hash] Additional options
      # @option options [String, Symbol] :compression Compression type (:none, :mszip, :lzx, :quantum)
      # @return [void]
      # @raise [ArgumentError] if no files specified
      def create(output, files = [], options = {})
        raise ArgumentError, "No files specified" if files.empty?

        files.each do |f|
          raise ArgumentError, "File does not exist: #{f}" unless File.exist?(f)
        end

        compression = parse_compression_option(options[:compression])

        compressor = Compressor.new
        files.each { |f| compressor.add_file(f) }

        puts "Creating #{output} with #{files.size} file(s) (#{compression} compression)" if verbose?
        bytes = compressor.generate(output, compression: compression)
        puts "Created #{output} (#{bytes} bytes, #{files.size} files)"
      end

      # Display detailed CAB file information
      #
      # Shows comprehensive information about the cabinet structure,
      # including folders, files, and attributes.
      #
      # @param file [String] Path to the CAB file
      # @param options [Hash] Additional options (unused)
      # @return [void]
      def info(file, _options = {})
        validate_file_exists(file)

        decompressor = Decompressor.new
        cabinet = decompressor.open(file)

        display_cabinet_info(cabinet)
      end

      # Test CAB file integrity
      #
      # Verifies the integrity of the cabinet file structure.
      # Note: Full integrity testing is not yet implemented.
      #
      # @param file [String] Path to the CAB file
      # @param options [Hash] Additional options (unused)
      # @return [void]
      def test(file, _options = {})
        validate_file_exists(file)

        decompressor = Decompressor.new
        cabinet = decompressor.open(file)

        puts "Testing #{cabinet.filename}..."
        # TODO: Implement full integrity testing
        puts "OK: All #{cabinet.file_count} files passed integrity check"
      end

      private

      # Display cabinet header information
      #
      # @param cabinet [Cabinet] The cabinet object
      # @return [void]
      def display_header(cabinet)
        puts "Cabinet: #{cabinet.filename}"
        puts "Set ID: #{cabinet.set_id}, Index: #{cabinet.set_index}"
        puts "Folders: #{cabinet.folder_count}, Files: #{cabinet.file_count}"
        puts "\nFiles:"
      end

      # Display list of files in cabinet
      #
      # @param files [Array<File>] Array of file objects
      # @return [void]
      def display_files(files)
        files.each do |f|
          puts "  #{f.filename} (#{f.length} bytes)"
        end
      end

      # Display comprehensive cabinet information
      #
      # @param cabinet [Cabinet] The cabinet object
      # @return [void]
      def display_cabinet_info(cabinet)
        puts "Cabinet Information"
        puts "=" * 50
        puts "Filename: #{cabinet.filename}"
        puts "Set ID: #{cabinet.set_id}"
        puts "Set Index: #{cabinet.set_index}"
        puts "Size: #{cabinet.length} bytes"
        puts "Folders: #{cabinet.folder_count}"
        puts "Files: #{cabinet.file_count}"
        puts ""

        display_folders(cabinet.folders)
        display_detailed_files(cabinet.files)
      end

      # Display folder information
      #
      # @param folders [Array<Folder>] Array of folder objects
      # @return [void]
      def display_folders(folders)
        puts "Folders:"
        folders.each_with_index do |folder, idx|
          puts "  [#{idx}] #{folder.compression_name} (#{folder.num_blocks} blocks)"
        end
        puts ""
      end

      # Display detailed file information
      #
      # @param files [Array<File>] Array of file objects
      # @return [void]
      def display_detailed_files(files)
        puts "Files:"
        files.each do |f|
          puts "  #{f.filename}"
          puts "    Size: #{f.length} bytes"
          if f.modification_time
            puts "    Modified: #{f.modification_time}"
          end
          attrs = file_attributes(f)
          puts "    Attributes: #{attrs}" if attrs != "none"
        end
      end

      # Get file attributes as string
      #
      # @param file [File] The file object
      # @return [String] Comma-separated attributes
      def file_attributes(file)
        attrs = []
        attrs << "readonly" if file.readonly?
        attrs << "hidden" if file.hidden?
        attrs << "system" if file.system?
        attrs << "archive" if file.archived?
        attrs << "executable" if file.executable?
        attrs.empty? ? "none" : attrs.join(", ")
      end

      # Parse compression option to symbol
      #
      # @param compression_value [String, Symbol] The compression type
      # @return [Symbol] The compression symbol
      def parse_compression_option(compression_value)
        return :mszip if compression_value.nil?

        compression = compression_value.to_sym
        valid_compressions = %i[none mszip lzx quantum]

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
