# frozen_string_literal: true

module Cabriolet
  module Collections
    # FileCollection manages a collection of files for compression
    # Provides unified interface for adding files and preparing them for compression
    class FileCollection
      include Enumerable

      # Initialize a new file collection
      #
      # @param format_options [Hash] Options specific to the archive format
      def initialize(format_options = {})
        @files = []
        @format_options = format_options
      end

      # Add a file to the collection
      #
      # @param source_path [String] Path to the source file
      # @param archive_path [String, nil] Path within the archive (defaults to basename)
      # @param options [Hash] Additional options for this file
      # @return [self] Returns self for chaining
      #
      # @example
      #   collection.add("README.md", "docs/README.md")
      #   collection.add("data.txt") # Uses basename
      def add(source_path, archive_path = nil, **options)
        validate_source(source_path)

        @files << {
          source: source_path,
          archive: archive_path || ::File.basename(source_path),
          options: options,
        }

        self
      end

      # Add multiple files at once
      #
      # @param files [Array<Hash>] Array of file hashes with :source, :archive, :options keys
      # @return [self] Returns self for chaining
      def add_all(files)
        files.each do |file|
          add(file[:source], file[:archive], **file.fetch(:options, {}))
        end
        self
      end

      # Iterate over files in the collection
      #
      # @yield [file_entry] Yields each file entry hash
      # @return [Enumerator] If no block given
      def each(&)
        @files.each(&)
      end

      # Get the number of files in the collection
      #
      # @return [Integer] Number of files
      def size
        @files.size
      end

      # Check if collection is empty
      #
      # @return [Boolean] True if no files
      def empty?
        @files.empty?
      end

      # Clear all files from the collection
      #
      # @return [self] Returns self for chaining
      def clear
        @files.clear
        self
      end

      # Prepare files for compression by reading metadata
      #
      # @return [Array<Hash>] Array of prepared file info hashes
      def prepare_for_compression
        @files.map do |file_entry|
          prepare_file_info(file_entry)
        end
      end

      # Get total uncompressed size of all files
      #
      # @return [Integer] Total size in bytes
      def total_size
        @files.sum { |f| ::File.size(f[:source]) }
      end

      # Group files by directory for archive organization
      #
      # @return [Hash] Hash with directory paths as keys and file arrays as values
      def by_directory
        @files.group_by do |file|
          ::File.dirname(file[:archive])
        end
      end

      # Find files by pattern in archive path
      #
      # @param pattern [String, Regexp] Pattern to match
      # @return [Array<Hash>] Matching file entries
      def find_by_pattern(pattern)
        @files.select do |file|
          if pattern.is_a?(Regexp)
            file[:archive] =~ pattern
          else
            file[:archive].include?(pattern)
          end
        end
      end

      private

      # Validate that source file exists and is accessible
      #
      # @param path [String] Path to validate
      # @raise [ArgumentError] if file doesn't exist or isn't a regular file
      def validate_source(path)
        unless ::File.exist?(path)
          raise ArgumentError, "File does not exist: #{path}"
        end

        unless ::File.file?(path)
          raise ArgumentError, "Not a regular file: #{path}"
        end
      end

      # Prepare file information for compression
      #
      # @param file_entry [Hash] Original file entry
      # @return [Hash] Prepared file info with metadata
      def prepare_file_info(file_entry)
        stat = ::File.stat(file_entry[:source])

        {
          source_path: file_entry[:source],
          archive_path: file_entry[:archive],
          size: stat.size,
          mtime: stat.mtime,
          atime: stat.atime,
          attributes: calculate_attributes(stat),
          options: file_entry[:options],
        }
      end

      # Calculate file attributes for archive format
      #
      # @param stat [File::Stat] File stat object
      # @return [Integer] Attribute flags
      def calculate_attributes(stat)
        attribs = Constants::ATTRIB_ARCH

        # Set read-only flag if not writable
        attribs |= Constants::ATTRIB_READONLY unless stat.writable?

        # Set hidden flag if hidden (Unix dotfiles)
        basename = ::File.basename(@files.first[:source])
        attribs |= Constants::ATTRIB_HIDDEN if basename.start_with?(".")

        # Set system flag for system files
        attribs |= Constants::ATTRIB_SYSTEM if stat.socket? || stat.symlink?

        attribs
      end
    end
  end
end
