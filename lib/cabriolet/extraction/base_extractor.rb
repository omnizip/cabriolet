# frozen_string_literal: true

require "fileutils"

module Cabriolet
  module Extraction
    # BaseExtractor provides common extraction functionality for all extractors
    # Reduces code duplication between SimpleExtractor and Parallel::Extractor
    class BaseExtractor
      # Initialize the base extractor
      #
      # @param output_dir [String] Directory to extract files to
      # @param preserve_paths [Boolean] Whether to preserve directory structure
      # @param overwrite [Boolean] Whether to overwrite existing files
      def initialize(output_dir, preserve_paths: true, overwrite: false)
        @output_dir = output_dir
        @preserve_paths = preserve_paths
        @overwrite = overwrite
      end

      protected

      # Build the output path for a file, handling path preservation and cleaning
      #
      # @param filename [String] Original filename from archive (may have backslashes)
      # @return [String] Full output path for the file
      def build_output_path(filename)
        # Normalize path separators (Windows archives use backslashes)
        clean_name = filename.gsub("\\", "/")

        if @preserve_paths
          # Keep directory structure
          ::File.join(@output_dir, clean_name)
        else
          # Flatten to output directory (just basename)
          ::File.join(@output_dir, ::File.basename(clean_name))
        end
      end

      # Extract a single file to disk
      #
      # @param file [Object] File object from archive (must respond to :name and :data)
      # @yield [path, data] Optional block for custom handling instead of default write
      # @return [String, nil] Output path if successful, nil if skipped or failed
      def extract_file(file)
        output_path = build_output_path(file.name)

        # Check if file exists and skip if not overwriting
        if ::File.exist?(output_path) && !@overwrite
          return nil
        end

        # Create parent directory
        dir = ::File.dirname(output_path)
        FileUtils.mkdir_p(dir) unless ::File.directory?(dir)

        # Get file data
        data = file.data
        return nil unless data

        # Write file data
        ::File.binwrite(output_path, data)

        # Preserve file attributes if available
        preserve_file_attributes(output_path, file)

        output_path
      rescue StandardError => e
        warn "Failed to extract #{file.name}: #{e.message}"
        nil
      end

      # Preserve file attributes (timestamps, etc.) if available on the file object
      #
      # @param path [String] Path to extracted file
      # @param file [Object] File object from archive
      def preserve_file_attributes(path, file)
        # Try various timestamp attributes that different formats use
        if file.respond_to?(:datetime) && file.datetime
          ::File.utime(::File.atime(path), file.datetime, path)
        elsif file.respond_to?(:mtime) && file.mtime
          atime = file.respond_to?(:atime) ? file.atime : ::File.atime(path)
          ::File.utime(atime, file.mtime, path)
        end
      end
    end
  end
end
