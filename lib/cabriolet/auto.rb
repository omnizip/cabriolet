# frozen_string_literal: true

require_relative "format_detector"

module Cabriolet
  # Auto-detection and extraction module
  module Auto
    class << self
      # Open and parse an archive with automatic format detection
      #
      # @param path [String] Path to the archive file
      # @param options [Hash] Options to pass to the parser
      # @return [Object] Parsed archive object
      # @raise [UnsupportedFormatError] if format cannot be detected or is unsupported
      #
      # @example
      #   archive = Cabriolet::Auto.open('unknown.archive')
      #   archive.files.each { |f| puts f.name }
      def open(path, **options)
        format = FormatDetector.detect(path)
        unless format
          raise UnsupportedFormatError,
                "Unable to detect format for: #{path}"
        end

        parser_class = FormatDetector.format_to_parser(format)
        unless parser_class
          raise UnsupportedFormatError,
                "No parser available for format: #{format}"
        end

        parser_class.new(**options).parse(path)
      end

      # Detect format and extract all files automatically
      #
      # @param archive_path [String] Path to the archive
      # @param output_dir [String] Directory to extract to
      # @param options [Hash] Extraction options
      # @option options [Boolean] :preserve_paths (true) Preserve directory structure
      # @option options [Boolean] :overwrite (false) Overwrite existing files
      # @option options [Boolean] :parallel (false) Use parallel extraction
      # @option options [Integer] :workers (4) Number of parallel workers
      # @return [Hash] Extraction statistics
      #
      # @example
      #   Cabriolet::Auto.extract('archive.cab', 'output/')
      #   Cabriolet::Auto.extract('file.chm', 'docs/', parallel: true, workers: 8)
      def extract(archive_path, output_dir, **options)
        archive = open(archive_path)

        extractor = if options[:parallel]
                      ParallelExtractor.new(archive, output_dir, **options)
                    else
                      SimpleExtractor.new(archive, output_dir, **options)
                    end

        extractor.extract_all
      end

      # Detect format only without parsing
      #
      # @param path [String] Path to the file
      # @return [Symbol, nil] Detected format symbol or nil
      #
      # @example
      #   format = Cabriolet::Auto.detect_format('file.cab')
      #   # => :cab
      def detect_format(path)
        FormatDetector.detect(path)
      end

      # Get information about an archive without full extraction
      #
      # @param path [String] Path to the archive
      # @return [Hash] Archive information
      #
      # @example
      #   info = Cabriolet::Auto.info('archive.cab')
      #   # => { format: :cab, file_count: 145, total_size: 52428800, ... }
      def info(path)
        archive = open(path)
        format = detect_format(path)

        {
          format: format,
          path: path,
          file_count: archive.files.count,
          total_size: archive.files.sum { |f| f.size || 0 },
          compressed_size: File.size(path),
          compression_ratio: calculate_compression_ratio(archive, path),
          files: archive.files.map { |f| file_info(f) },
        }
      end

      private

      def calculate_compression_ratio(archive, path)
        total_uncompressed = archive.files.sum { |f| f.size || 0 }
        compressed = File.size(path)

        return 0 if total_uncompressed.zero?

        ((compressed.to_f / total_uncompressed) * 100).round(2)
      end

      def file_info(file)
        {
          name: file.name,
          size: file.size,
          compressed_size: file.respond_to?(:compressed_size) ? file.compressed_size : nil,
          attributes: file.respond_to?(:attributes) ? file.attributes : nil,
          date: file.respond_to?(:date) ? file.date : nil,
          time: file.respond_to?(:time) ? file.time : nil,
        }
      end
    end

    # Simple sequential extractor
    class SimpleExtractor
      def initialize(archive, output_dir, **options)
        @archive = archive
        @output_dir = output_dir
        @options = options
        @preserve_paths = options.fetch(:preserve_paths, true)
        @overwrite = options.fetch(:overwrite, false)
        @stats = { extracted: 0, skipped: 0, failed: 0, bytes: 0 }
      end

      def extract_all
        FileUtils.mkdir_p(@output_dir)

        @archive.files.each do |file|
          extract_file(file)
        end

        @stats
      end

      private

      def extract_file(file)
        output_path = build_output_path(file.name)

        if File.exist?(output_path) && !@overwrite
          @stats[:skipped] += 1
          return
        end

        FileUtils.mkdir_p(File.dirname(output_path))
        File.write(output_path, file.data, mode: "wb")

        @stats[:extracted] += 1
        @stats[:bytes] += file.data.bytesize
      rescue StandardError => e
        @stats[:failed] += 1
        warn "Failed to extract #{file.name}: #{e.message}"
      end

      def build_output_path(filename)
        if @preserve_paths
          # Keep directory structure
          clean_name = filename.gsub("\\", "/")
          File.join(@output_dir, clean_name)
        else
          # Flatten to output directory
          base_name = File.basename(filename.gsub("\\", "/"))
          File.join(@output_dir, base_name)
        end
      end
    end
  end
end
