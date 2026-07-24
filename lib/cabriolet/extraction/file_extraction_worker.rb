# frozen_string_literal: true

module Cabriolet
  module Extraction
    # Worker for extracting files using Fractor.
    class FileExtractionWorker < Fractor::Worker
      include FileOperations

      def process(work)
        output_path = build_output_path(work.file.name, work.output_dir, work.preserve_paths)

        if ::File.exist?(output_path) && !work.overwrite
          return skipped_result(work, "File already exists")
        end

        ensure_parent_dir(output_path)

        data = work.file.data
        return skipped_result(work, "No data available") unless data

        write_file(output_path, data)
        preserve_file_attributes(output_path, work.file)

        Fractor::WorkResult.new(
          result: {
            path: output_path,
            size: data.bytesize,
            name: work.file.name,
          },
          work: work,
        )
      rescue StandardError => e
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
