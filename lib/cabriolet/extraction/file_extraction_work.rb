# frozen_string_literal: true

require "fractor"

module Cabriolet
  module Extraction
    # Work item for file extraction using Fractor
    class FileExtractionWork < Fractor::Work
      # Initialize work item for extracting a single file
      #
      # @param file [Object] File object from archive (responds to :name, :data)
      # @param output_dir [String] Output directory path
      # @param preserve_paths [Boolean] Whether to preserve directory structure
      # @param overwrite [Boolean] Whether to overwrite existing files
      def initialize(file, output_dir:, preserve_paths: true, overwrite: false)
        super({
          file: file,
          output_dir: output_dir,
          preserve_paths: preserve_paths,
          overwrite: overwrite,
        })
      end

      # The file object to extract
      #
      # @return [Object] File from archive
      def file
        input[:file]
      end

      # Output directory for extraction
      #
      # @return [String] Directory path
      def output_dir
        input[:output_dir]
      end

      # Whether to preserve directory structure
      #
      # @return [Boolean]
      def preserve_paths
        input[:preserve_paths]
      end

      # Whether to overwrite existing files
      #
      # @return [Boolean]
      def overwrite
        input[:overwrite]
      end

      # Unique identifier for this work item (filename based)
      #
      # @return [String] Unique identifier
      def id
        file.name
      end
    end
  end
end
