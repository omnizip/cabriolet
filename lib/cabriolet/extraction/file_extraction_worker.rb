# frozen_string_literal: true

require "fileutils"

module Cabriolet
  module Extraction
    # Worker for extracting files using Fractor
    class FileExtractionWorker < Fractor::Worker
      # Process a file extraction work item
      #
      # @param work [FileExtractionWork] Work item to process
      # @return [Fractor::WorkResult] Result of extraction
      def process(work)
        output_path = build_output_path(work)

        # Check if file exists and skip if not overwriting
        if ::File.exist?(output_path) && !work.overwrite
          return skipped_result(work, "File already exists")
        end

        # Create parent directory
        dir = ::File.dirname(output_path)
        FileUtils.mkdir_p(dir) unless ::File.directory?(dir)

        # Get file data
        data = work.file.data
        unless data
          return skipped_result(work, "No data available")
        end

        # Write file data
        ::File.binwrite(output_path, data)

        # Preserve file attributes if available
        preserve_file_attributes(output_path, work.file)

        # Return success result
        Fractor::WorkResult.new(
          result: {
            path: output_path,
            size: data.bytesize,
            name: work.file.name,
          },
          work: work,
        )
      rescue StandardError => e
        # Return error result
        Fractor::WorkResult.new(
          error: {
            message: e.message,
            class: e.class.name,
            backtrace: e.backtrace.first(5),
          },
          work: work,
        )
      end

      private

      # Build the output path for a file
      #
      # @param work [FileExtractionWork] Work item containing file and options
      # @return [String] Full output path
      def build_output_path(work)
        # Normalize path separators (Windows archives use backslashes)
        clean_name = work.file.name.gsub("\\", "/")

        if work.preserve_paths
          ::File.join(work.output_dir, clean_name)
        else
          ::File.join(work.output_dir, ::File.basename(clean_name))
        end
      end

      # Preserve file attributes (timestamps, etc.)
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

      # Create a skipped result
      #
      # @param work [FileExtractionWork] Work item that was skipped
      # @param reason [String] Reason for skipping
      # @return [Fractor::WorkResult] Skipped result
      def skipped_result(work, reason)
        Fractor::WorkResult.new(
          result: {
            status: :skipped,
            name: work.file.name,
            reason: reason,
          },
          work: work,
        )
      end
    end
  end
end
