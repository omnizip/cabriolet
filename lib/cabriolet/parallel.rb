# frozen_string_literal: true

module Cabriolet
  # Parallel extraction for multi-core performance
  module Parallel
    # Parallel extractor for archives
    class Extractor
      DEFAULT_WORKERS = 4

      def initialize(archive, output_dir, workers: DEFAULT_WORKERS, **options)
        @archive = archive
        @output_dir = output_dir
        @workers = [workers, 1].max # At least 1 worker
        @options = options
        @preserve_paths = options.fetch(:preserve_paths, true)
        @overwrite = options.fetch(:overwrite, false)
        @queue = Queue.new
        @stats = { extracted: 0, skipped: 0, failed: 0, bytes: 0 }
        @stats_mutex = Mutex.new
      end

      # Extract all files using parallel workers
      #
      # @return [Hash] Extraction statistics
      #
      # @example
      #   extractor = Cabriolet::Parallel::Extractor.new(cab, 'output/', workers: 8)
      #   stats = extractor.extract_all
      def extract_all
        FileUtils.mkdir_p(@output_dir)

        # Queue all files
        @archive.files.each { |file| @queue << file }

        # Add termination signals
        @workers.times { @queue << :done }

        # Start worker threads
        threads = Array.new(@workers) do |worker_id|
          Thread.new { worker_loop(worker_id) }
        end

        # Wait for all workers to complete
        threads.each(&:join)

        @stats
      end

      # Extract files with progress callback
      #
      # @yield [current, total, file] Progress callback
      # @return [Hash] Extraction statistics
      #
      # @example
      #   extractor.extract_with_progress do |current, total, file|
      #     puts "#{current}/#{total}: #{file.name}"
      #   end
      def extract_with_progress(&block)
        return extract_all unless block

        total = @archive.files.count
        current = 0
        current_mutex = Mutex.new

        FileUtils.mkdir_p(@output_dir)

        # Queue all files
        @archive.files.each { |file| @queue << file }
        @workers.times { @queue << :done }

        # Start worker threads with progress
        threads = Array.new(@workers) do |_worker_id|
          Thread.new do
            loop do
              file = @queue.pop
              break if file == :done

              extract_file(file)

              current_mutex.synchronize do
                current += 1
                yield(current, total, file)
              end
            end
          end
        end

        threads.each(&:join)
        @stats
      end

      private

      def worker_loop(_worker_id)
        loop do
          file = @queue.pop
          break if file == :done

          extract_file(file)
        end
      end

      def extract_file(file)
        output_path = build_output_path(file.name)

        if File.exist?(output_path) && !@overwrite
          update_stats(:skipped)
          return
        end

        begin
          # Create directory (thread-safe)
          FileUtils.mkdir_p(File.dirname(output_path))

          # Extract file data
          data = file.data

          # Write file (one at a time per file)
          File.write(output_path, data, mode: "wb")

          # Preserve timestamps if available
          if file.respond_to?(:datetime) && file.datetime
            File.utime(File.atime(output_path), file.datetime, output_path)
          end

          update_stats(:extracted, data.bytesize)
        rescue StandardError => e
          update_stats(:failed)
          warn "Worker error extracting #{file.name}: #{e.message}"
        end
      end

      def build_output_path(filename)
        if @preserve_paths
          clean_name = filename.gsub("\\", "/")
          File.join(@output_dir, clean_name)
        else
          base_name = File.basename(filename.gsub("\\", "/"))
          File.join(@output_dir, base_name)
        end
      end

      def update_stats(stat_type, bytes = 0)
        @stats_mutex.synchronize do
          @stats[stat_type] += 1
          @stats[:bytes] += bytes if bytes.positive?
        end
      end
    end

    # Parallel batch processor
    class BatchProcessor
      def initialize(workers: Extractor::DEFAULT_WORKERS)
        @workers = workers
        @stats = { total: 0, successful: 0, failed: 0 }
        @stats_mutex = Mutex.new
      end

      # Process multiple archives in parallel
      #
      # @param archive_paths [Array<String>] Paths to archives
      # @param output_base [String] Base output directory
      # @yield [archive_path, stats] Optional callback per archive
      # @return [Hash] Overall statistics
      #
      # @example
      #   processor = Cabriolet::Parallel::BatchProcessor.new(workers: 8)
      #   stats = processor.process_all(Dir.glob('*.cab'), 'output/')
      def process_all(archive_paths, output_base, &block)
        queue = Queue.new
        archive_paths.each { |path| queue << path }
        @workers.times { queue << :done }

        threads = Array.new(@workers) do
          Thread.new { process_loop(queue, output_base, &block) }
        end

        threads.each(&:join)
        @stats
      end

      private

      def process_loop(queue, output_base, &block)
        loop do
          archive_path = queue.pop
          break if archive_path == :done

          process_one(archive_path, output_base, &block)
        end
      end

      def process_one(archive_path, output_base)
        update_stats(:total)

        begin
          archive = Cabriolet::Auto.open(archive_path)
          output_dir = File.join(output_base, File.basename(archive_path, ".*"))

          extractor = Extractor.new(archive, output_dir, workers: 2)
          stats = extractor.extract_all

          update_stats(:successful)

          yield(archive_path, stats) if block_given?
        rescue StandardError => e
          update_stats(:failed)
          warn "Failed to process #{archive_path}: #{e.message}"
        end
      end

      def update_stats(stat_type)
        @stats_mutex.synchronize do
          @stats[stat_type] += 1
        end
      end

      attr_reader :stats
    end

    # Thread pool for custom parallel operations
    class ThreadPool
      def initialize(size: Extractor::DEFAULT_WORKERS)
        @size = size
        @queue = Queue.new
        @threads = []
        @running = false
      end

      # Start the thread pool
      def start
        return if @running

        @running = true
        @threads = Array.new(@size) do
          Thread.new { worker_loop }
        end
      end

      # Submit a task to the pool
      #
      # @yield Task to execute
      def submit(&block)
        start unless @running
        @queue << block
      end

      # Shutdown the thread pool
      #
      # @param wait [Boolean] Wait for pending tasks to complete
      def shutdown(wait: true)
        return unless @running

        if wait
          # Wait for queue to empty
          sleep 0.01 until @queue.empty?
        end

        # Send termination signals
        @size.times { @queue << :shutdown }

        # Wait for threads to finish
        @threads.each(&:join)
        @threads.clear
        @running = false
      end

      # Execute tasks in parallel with automatic cleanup
      #
      # @param items [Array] Items to process
      # @yield [item] Process each item
      # @return [Array] Results from each task
      def map(items)
        start
        results = []
        results_mutex = Mutex.new

        items.each_with_index do |item, index|
          submit do
            result = yield(item)
            results_mutex.synchronize do
              results[index] = result
            end
          end
        end

        shutdown(wait: true)
        results
      end

      private

      def worker_loop
        loop do
          task = @queue.pop
          break if task == :shutdown

          begin
            task.call
          rescue StandardError => e
            warn "Thread pool worker error: #{e.message}"
          end
        end
      end
    end

    class << self
      # Extract archive using parallel workers
      #
      # @param archive [Object] Archive object
      # @param output_dir [String] Output directory
      # @param workers [Integer] Number of parallel workers
      # @return [Hash] Extraction statistics
      def extract(archive, output_dir, workers: Extractor::DEFAULT_WORKERS,
**options)
        extractor = Extractor.new(archive, output_dir, workers: workers,
                                                       **options)
        extractor.extract_all
      end

      # Process multiple archives in parallel
      #
      # @param paths [Array<String>] Archive paths
      # @param output_base [String] Base output directory
      # @param workers [Integer] Number of parallel workers
      # @return [Hash] Processing statistics
      def process_batch(paths, output_base, workers: Extractor::DEFAULT_WORKERS)
        processor = BatchProcessor.new(workers: workers)
        processor.process_all(paths, output_base)
      end
    end
  end
end
