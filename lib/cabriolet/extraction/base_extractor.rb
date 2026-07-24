# frozen_string_literal: true

module Cabriolet
  module Extraction
    # BaseExtractor provides common extraction functionality for all extractors.
    class BaseExtractor
      include FileOperations

      def initialize(output_dir, preserve_paths: true, overwrite: false)
        @output_dir = output_dir
        @preserve_paths = preserve_paths
        @overwrite = overwrite
      end

      protected

      def extract_file(file)
        output_path = build_output_path(file.name, @output_dir, @preserve_paths)

        return nil if ::File.exist?(output_path) && !@overwrite

        ensure_parent_dir(output_path)

        data = file.data
        return nil unless data

        write_file(output_path, data)
        preserve_file_attributes(output_path, file)

        output_path
      rescue StandardError => e
        warn "Failed to extract #{file.name}: #{e.message}"
        nil
      end
    end
  end
end
