# frozen_string_literal: true

module Cabriolet
  module LIT
    # Command handler for LIT (Microsoft Reader eBook) format
    #
    # This handler implements the unified command interface for LIT files,
    # wrapping the existing LIT::Decompressor and LIT::Compressor classes.
    # LIT files use LZX compression and may include DRM protection.
    #
    class CommandHandler < Commands::BaseCommandHandler
      # Extract files from LIT archive
      #
      # Extracts all files from the LIT file to the specified output directory.
      # Uses manifest for filename restoration if available.
      #
      # @param file [String] Path to the LIT file
      # @param output_dir [String] Output directory path (default: current directory)
      # @param options [Hash] Additional options
      # @option options [Boolean] :use_manifest Use manifest for filenames (default: true)
      # @return [void]
      def extract(file, output_dir = nil, options = {})
        validate_file_exists(file)

        output_dir ||= "."
        output_dir = ensure_output_dir(output_dir)

        decompressor = Decompressor.new
        lit_file = decompressor.open(file)

        use_manifest = options.fetch(:use_manifest, true)
        count = decompressor.extract_all(lit_file, output_dir,
                                         use_manifest: use_manifest)

        decompressor.close(lit_file)
        puts "Extracted #{count} file(s) to #{output_dir}"
      end

      # Create a new LIT archive
      #
      # Creates a LIT file from HTML source files.
      # Non-encrypted LIT files are created (DRM not supported).
      #
      # @param output [String] Output LIT file path
      # @param files [Array<String>] List of input files to add
      # @param options [Hash] Additional options
      # @option options [Integer] :language_id Language ID (default: 0x409 English)
      # @option options [Integer] :version LIT format version (default: 1)
      # @return [void]
      # @raise [ArgumentError] if no files specified
      def create(output, files = [], options = {})
        raise ArgumentError, "No files specified" if files.empty?

        files.each do |f|
          raise ArgumentError, "File does not exist: #{f}" unless File.exist?(f)
        end

        language_id = options[:language_id] || 0x409
        version = options[:version] || 1

        compressor = Compressor.new
        files.each do |f|
          # Default to adding with compression
          lit_path = "/#{File.basename(f)}"
          compressor.add_file(f, lit_path, compress: true)
        end

        puts "Creating #{output} with #{files.size} file(s) (v#{version}, lang: 0x#{Integer(language_id).to_s(16)})" if verbose?
        bytes = compressor.generate(output, version: version,
                                            language_id: language_id)
        puts "Created #{output} (#{bytes} bytes, #{files.size} files)"
      end

      private

      def decompressor_class
        Decompressor
      end

      # Show the LIT header followed by its files
      def render_listing(session, _file, options)
        display_header(session.archive)
        display_files(session.archive, session.decompressor, options)
      end

      # Show comprehensive information about the LIT structure
      def render_info(session, _file)
        display_lit_info(session.archive)
      end

      # DEAD CODE — unreachable through the command path, both branches.
      #
      # #test calls validate_integrity before this hook, and the Validator reads
      # 4 magic bytes and compares them against the 8-byte "ITOLITLS" signature
      # (validator.rb:104, validator.rb:237), so every LIT file fails and this
      # never runs. The encrypted? branch is doubly unreachable: LIT::Decompressor
      # raises NotImplementedError for DRM files while opening them
      # (lit/decompressor.rb:39). Preserved verbatim pending a Validator fix.
      def render_test_result(session)
        lit_file = session.archive
        if lit_file.encrypted?
          puts "WARNING: LIT file is DRM-encrypted (level: #{lit_file.drm_level})"
          puts "Encryption is not supported by this implementation"
        else
          puts "OK: LIT file structure is valid (#{lit_file.directory.entries.size} files)"
        end
      end

      # Display LIT header information
      #
      # @param lit_file [Models::LITFile] The LIT file object
      # @return [void]
      def display_header(lit_file)
        puts "LIT File: #{File.basename(lit_file.filename || 'unknown')}"
        puts "Version: #{lit_file.version}"
        puts "Language ID: 0x#{Integer(lit_file.language_id).to_s(16).upcase}"
        puts "DRM Protected: #{lit_file.encrypted? ? 'Yes' : 'No'}"
        puts "\nFiles:"
      end

      # Display list of files in LIT
      #
      # @param lit_file [Models::LITFile] The LIT file object
      # @param decompressor [Decompressor] The decompressor instance
      # @param options [Hash] Display options
      # @return [void]
      def display_files(lit_file, decompressor, options)
        use_manifest = options.fetch(:use_manifest, true)
        files = decompressor.list_files(lit_file, use_manifest: use_manifest)

        files.each do |f|
          name = f[:original_name] || f[:internal_name]
          size = f[:size]
          content_type = f[:content_type]

          line = "  #{name} (#{size} bytes)"
          line += " [#{content_type}]" if content_type && use_manifest
          puts line
        end
      end

      # Display comprehensive LIT information
      #
      # @param lit_file [Models::LITFile] The LIT file object
      # @return [void]
      def display_lit_info(lit_file)
        puts "LIT File Information"
        puts "=" * 50

        filename = lit_file.filename
        puts "Filename: #{filename || 'unknown'}"
        puts "Version: #{lit_file.version}"
        puts "Language ID: 0x#{Integer(lit_file.language_id).to_s(16).upcase}"
        puts "Creator ID: #{lit_file.creator_id}"
        if lit_file.timestamp&.positive?
          puts "Timestamp: #{Time.at(lit_file.timestamp)}"
        end

        puts ""
        if lit_file.encrypted?
          puts "DRM Protection:"
          puts "  Status: ENCRYPTED"
          puts "  Level: #{lit_file.drm_level}"
          puts "  WARNING: DRM decryption is not supported"
        else
          puts "DRM Protection: None"
        end

        puts ""
        puts "Sections: #{lit_file.sections.size}"
        lit_file.sections.compact.each_with_index do |section, idx|
          puts "  [#{idx}] #{section.name}"
          puts "      Transforms: #{section.transforms.join(', ')}" if section.transforms.any?
        end

        puts ""
        puts "Files: #{lit_file.directory.entries.size - 1}" # Exclude root entry

        # Display manifest if available
        if lit_file.manifest
          puts ""
          puts "Manifest mappings: #{lit_file.manifest.mappings.size}"
        end
      end
    end
  end
end
