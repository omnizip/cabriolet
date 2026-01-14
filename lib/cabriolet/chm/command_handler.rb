# frozen_string_literal: true

require_relative "../cli/base_command_handler"
require_relative "decompressor"
require_relative "compressor"

module Cabriolet
  module CHM
    # Command handler for CHM (Compiled HTML Help) format
    #
    # This handler implements the unified command interface for CHM files,
    # wrapping the existing CHM::Decompressor and CHM::Compressor classes.
    #
    class CommandHandler < Commands::BaseCommandHandler
      # List CHM file contents
      #
      # Displays information about the CHM file including version,
      # language, and lists all contained files with their sizes.
      #
      # @param file [String] Path to the CHM file
      # @param options [Hash] Additional options (unused)
      # @return [void]
      def list(file, _options = {})
        validate_file_exists(file)

        decompressor = Decompressor.new
        chm = decompressor.open(file)

        display_header(chm)
        display_files(chm.all_files)

        decompressor.close
      end

      # Extract files from CHM archive
      #
      # Extracts all non-system files from the CHM file to the
      # specified output directory.
      #
      # @param file [String] Path to the CHM file
      # @param output_dir [String] Output directory path (default: current directory)
      # @param options [Hash] Additional options (unused)
      # @return [void]
      def extract(file, output_dir = nil, _options = {})
        validate_file_exists(file)

        output_dir ||= "."
        output_dir = ensure_output_dir(output_dir)

        decompressor = Decompressor.new
        chm = decompressor.open(file)

        count = 0
        chm.all_files.each do |f|
          next if f.system_file?

          output_path = File.join(output_dir, f.filename)
          output_subdir = File.dirname(output_path)
          FileUtils.mkdir_p(output_subdir)

          puts "Extracting: #{f.filename}" if verbose?
          decompressor.extract(f, output_path)
          count += 1
        end

        decompressor.close
        puts "Extracted #{count} file(s) to #{output_dir}"
      end

      # Create a new CHM archive
      #
      # Creates a CHM file from HTML source files.
      #
      # @param output [String] Output CHM file path
      # @param files [Array<String>] List of input HTML files
      # @param options [Hash] Additional options
      # @option options [Integer] :window_bits LZX window size (15-21, default: 16)
      # @return [void]
      # @raise [ArgumentError] if no files specified
      def create(output, files = [], options = {})
        raise ArgumentError, "No files specified" if files.empty?

        files.each do |f|
          raise ArgumentError, "File does not exist: #{f}" unless File.exist?(f)
        end

        window_bits = options[:window_bits] || 16

        compressor = Compressor.new
        files.each do |f|
          # Default to compressed section for .html, uncompressed for images
          section = f.end_with?(".html", ".htm") ? :compressed : :uncompressed
          compressor.add_file(f, "/#{File.basename(f)}", section: section)
        end

        puts "Creating #{output} with #{files.size} file(s) (window_bits: #{window_bits})" if verbose?
        bytes = compressor.generate(output, window_bits: window_bits)
        puts "Created #{output} (#{bytes} bytes, #{files.size} files)"
      end

      # Display detailed CHM file information
      #
      # Shows comprehensive information about the CHM structure,
      # including directory, sections, and files.
      #
      # @param file [String] Path to the CHM file
      # @param options [Hash] Additional options (unused)
      # @return [void]
      def info(file, _options = {})
        validate_file_exists(file)

        decompressor = Decompressor.new
        chm = decompressor.open(file)

        display_chm_info(chm)

        decompressor.close
      end

      # Test CHM file integrity
      #
      # Verifies the CHM file structure.
      #
      # @param file [String] Path to the CHM file
      # @param options [Hash] Additional options (unused)
      # @return [void]
      def test(file, _options = {})
        validate_file_exists(file)

        decompressor = Decompressor.new
        chm = decompressor.open(file)

        puts "Testing #{chm.filename}..."
        puts "OK: CHM file structure is valid (#{chm.all_files.size} files)"
        puts "Note: Full integrity validation not yet implemented"

        decompressor.close
      end

      private

      # Display CHM header information
      #
      # @param chm [CHMFile] The CHM file object
      # @return [void]
      def display_header(chm)
        puts "CHM File: #{chm.filename}"
        puts "Version: #{chm.version}"
        puts "Language: #{chm.language}"
        puts "Chunks: #{chm.num_chunks}, Chunk Size: #{chm.chunk_size}"
        puts "\nFiles:"
      end

      # Display list of files in CHM
      #
      # @param files [Array<CHMFile>] Array of file objects
      # @return [void]
      def display_files(files)
        files.each do |f|
          section_name = f.section.id.zero? ? "Uncompressed" : "MSCompressed"
          puts "  #{f.filename} (#{f.length} bytes, #{section_name})"
        end
      end

      # Display comprehensive CHM information
      #
      # @param chm [CHMFile] The CHM file object
      # @return [void]
      def display_chm_info(chm)
        puts "CHM File Information"
        puts "=" * 50
        puts "Filename: #{chm.filename}"
        puts "Version: #{chm.version}"
        puts "Language ID: #{chm.language}"
        puts "Timestamp: #{chm.timestamp}"
        puts "Size: #{chm.length} bytes"
        puts ""
        puts "Directory:"
        puts "  Offset: #{chm.dir_offset}"
        puts "  Chunks: #{chm.num_chunks}"
        puts "  Chunk Size: #{chm.chunk_size}"
        puts "  First PMGL: #{chm.first_pmgl}"
        puts "  Last PMGL: #{chm.last_pmgl}"
        puts ""
        puts "Sections:"
        puts "  Section 0 (Uncompressed): offset #{chm.sec0.offset}"
        puts "  Section 1 (MSCompressed): LZX compression"
        puts ""

        regular_files = chm.all_files
        system_files = chm.all_sysfiles

        puts "Files: #{regular_files.length} regular, #{system_files.length} system"
        puts ""
        display_regular_files(regular_files)
        display_system_files(system_files) if system_files.any?
      end

      # Display regular files
      #
      # @param files [Array<CHMFile>] Array of regular file objects
      # @return [void]
      def display_regular_files(files)
        puts "Regular Files:"
        files.each do |f|
          section_name = f.section.id.zero? ? "Sec0" : "Sec1"
          puts "  #{f.filename}"
          puts "    Size: #{f.length} bytes (#{section_name})"
        end
      end

      # Display system files
      #
      # @param files [Array<CHMFile>] Array of system file objects
      # @return [void]
      def display_system_files(files)
        puts ""
        puts "System Files:"
        files.each do |f|
          section_name = f.section.id.zero? ? "Sec0" : "Sec1"
          puts "  #{f.filename}"
          puts "    Size: #{f.length} bytes (#{section_name})"
        end
      end
    end
  end
end
