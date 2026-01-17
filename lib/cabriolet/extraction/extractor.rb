# frozen_string_literal: true

require "fractor"
require_relative "file_extraction_work"
require_relative "file_extraction_worker"

module Cabriolet
  module Extraction
    # Unified extractor using Fractor for parallel file extraction
    # Single workers: 1 = sequential, N = parallel
    class Extractor
      DEFAULT_WORKERS = 4

      attr_reader :archive, :output_dir, :workers, :stats

      def initialize(archive, output_dir, workers: DEFAULT_WORKERS, **options)
        @archive = archive
        @output_dir = output_dir
        @workers = [workers, 1].max # At least 1 worker
        @preserve_paths = options.fetch(:preserve_paths, true)
        @overwrite = options.fetch(:overwrite, false)
        @stats = { extracted: 0, skipped: 0, failed: 0, bytes: 0 }
      end

      # Extract all files from archive
      #
      # @return [Hash] Extraction statistics
      def extract_all
        FileUtils.mkdir_p(@output_dir)

        # Create work items for all files
        work_items = @archive.files.map do |file|
          FileExtractionWork.new(
            file,
            output_dir: @output_dir,
            preserve_paths: @preserve_paths,
            overwrite: @overwrite,
          )
        end

        # Create supervisor with workers
        supervisor = Fractor::Supervisor.new(
          worker_pools: [
            {
              worker_class: FileExtractionWorker,
              num_workers: @workers,
            },
          ],
        )

        # Add all work items
        supervisor.add_work_items(work_items)

        # Run extraction
        supervisor.run

        # Collect results
        collect_stats(supervisor.results)

        @stats
      end

      # Extract files with progress callback
      #
      # @yield [current, total, file] Progress callback
      # @return [Hash] Extraction statistics
      def extract_with_progress(&block)
        return extract_all unless block

        FileUtils.mkdir_p(@output_dir)

        # For progress tracking, we need to process in batches
        # or use a custom approach since Fractor doesn't have built-in callbacks
        total = @archive.files.count
        current = 0

        # Sequential mode uses simple iteration with progress
        if @workers == 1
          @archive.files.each do |file|
            extract_single_file(file)
            current += 1
            yield(current, total, file)
          end
          return @stats
        end

        # Parallel mode: batch files for progress updates
        batch_size = [@archive.files.count / @workers, 1].max
        batches = @archive.files.each_slice(batch_size).to_a

        batches.each do |batch|
          work_items = batch.map do |file|
            FileExtractionWork.new(
              file,
              output_dir: @output_dir,
              preserve_paths: @preserve_paths,
              overwrite: @overwrite,
            )
          end

          supervisor = Fractor::Supervisor.new(
            worker_pools: [
              {
                worker_class: FileExtractionWorker,
                num_workers: @workers,
              },
            ],
          )

          supervisor.add_work_items(work_items)
          supervisor.run

          batch.each do |file|
            current += 1
            yield(current, total, file)
          end
        end

        @stats
      end

      private

      # Extract a single file (for sequential mode with progress)
      #
      # @param file [Object] File to extract
      # @return [Object] Result from worker
      def extract_single_file(file)
        work = FileExtractionWork.new(
          file,
          output_dir: @output_dir,
          preserve_paths: @preserve_paths,
          overwrite: @overwrite,
        )

        worker = FileExtractionWorker.new
        result = worker.process(work)

        update_stats_from_result(result)

        result
      end

      # Collect statistics from Fractor results
      #
      # @param results [Fractor::Results] Results from supervisor
      def collect_stats(results)
        results.results.each do |result|
          update_stats_from_result(result)
        end
      end

      # Update stats from a single work result
      #
      # @param result [Fractor::WorkResult] Result from worker
      def update_stats_from_result(result)
        if result.success?
          data = result.result
          if data.is_a?(Hash) && data[:status] == :skipped
            @stats[:skipped] += 1
          else
            @stats[:extracted] += 1
            @stats[:bytes] += data[:size] if data.is_a?(Hash) && data[:size]
          end
        else
          @stats[:failed] += 1
        end
      end
    end
  end
end
