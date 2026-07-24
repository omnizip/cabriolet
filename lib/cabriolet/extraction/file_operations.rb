# frozen_string_literal: true

require "fileutils"

module Cabriolet
  module Extraction
    # Shared file operations used by both BaseExtractor and FileExtractionWorker.
    # Eliminates duplication of path normalization and attribute preservation.
    module FileOperations
      # Build the output path for a file, handling path preservation and cleaning.
      #
      # @param filename [String] Original filename from archive (may have backslashes)
      # @param output_dir [String] Base output directory
      # @param preserve_paths [Boolean] Whether to preserve directory structure
      # @return [String] Full output path
      def build_output_path(filename, output_dir, preserve_paths)
        clean_name = normalize_filename(filename)

        if preserve_paths
          ::File.join(output_dir, clean_name)
        else
          ::File.join(output_dir, ::File.basename(clean_name))
        end
      end

      # Normalize path separators (Windows archives use backslashes).
      #
      # @param filename [String] Filename to normalize
      # @return [String] Normalized filename with forward slashes
      def normalize_filename(filename)
        filename.gsub("\\", "/")
      end

      # Ensure the parent directory for a path exists.
      #
      # @param path [String] File path
      def ensure_parent_dir(path)
        dir = ::File.dirname(path)
        FileUtils.mkdir_p(dir) unless ::File.directory?(dir)
      end

      # Write binary data to a file path.
      #
      # @param path [String] Output file path
      # @param data [String] Binary data to write
      def write_file(path, data)
        ::File.binwrite(path, data)
      end

      # Preserve file attributes (timestamps) from the archive file object.
      #
      # @param path [String] Path to extracted file on disk
      # @param file [Object] File object from archive (must provide #datetime)
      def preserve_file_attributes(path, file)
        datetime = file.datetime
        ::File.utime(::File.atime(path), datetime, path) if datetime
      end
    end
  end
end
