# frozen_string_literal: true

module Cabriolet
  # Streaming API for memory-efficient processing of large archives
  module Streaming
    # Stream-based archive parser
    class StreamParser
      DEFAULT_CHUNK_SIZE = 65_536 # 64KB chunks

      def initialize(path, chunk_size: DEFAULT_CHUNK_SIZE)
        @path = path
        @chunk_size = chunk_size
        @format = FormatDetector.detect(path)
        raise UnsupportedFormatError, "Unable to detect format" unless @format
      end

      # Iterate over files without loading entire archive into memory
      #
      # @yield [file] Yields each file object
      # @yieldparam file [Object] File object from the archive
      # @return [Enumerator] if no block given
      #
      # @example
      #   parser = Cabriolet::Streaming::StreamParser.new('huge.cab')
      #   parser.each_file do |file|
      #     # Process one file at a time
      #     puts "#{file.name}: #{file.size} bytes"
      #     # File data loaded on-demand via file.data
      #   end
      def each_file(&)
        return enum_for(:each_file) unless block_given?

        case @format
        when :cab
          stream_cab_files(&)
        when :chm
          stream_chm_files(&)
        else
          # Fallback to standard parsing for unsupported streaming formats
          archive = Cabriolet::Auto.open(@path)
          archive.files.each(&)
        end
      end

      # Stream file data in chunks
      #
      # @param file [Object] File object from archive
      # @yield [chunk] Yields data chunks
      # @yieldparam chunk [String] Binary data chunk
      # @return [Enumerator] if no block given
      #
      # @example
      #   parser.stream_file_data(file) do |chunk|
      #     output.write(chunk)
      #   end
      def stream_file_data(file, &)
        return enum_for(:stream_file_data, file) unless block_given?

        if file.respond_to?(:stream_data)
          file.stream_data(chunk_size: @chunk_size, &)
        else
          # Fallback: load entire file and yield in chunks
          data = file.data
          offset = 0
          while offset < data.bytesize
            chunk = data.byteslice(offset, @chunk_size)
            yield chunk
            offset += @chunk_size
          end
        end
      end

      # Extract files using streaming to minimize memory usage
      #
      # @param output_dir [String] Directory to extract to
      # @param options [Hash] Extraction options
      # @return [Hash] Extraction statistics
      def extract_streaming(output_dir, **_options)
        FileUtils.mkdir_p(output_dir)
        stats = { extracted: 0, bytes: 0, failed: 0 }

        each_file do |file|
          output_path = File.join(output_dir, file.name.gsub("\\", "/"))
          FileUtils.mkdir_p(File.dirname(output_path))

          File.open(output_path, "wb") do |out|
            stream_file_data(file) do |chunk|
              out.write(chunk)
            end
          end

          stats[:extracted] += 1
          stats[:bytes] += file.size if file.respond_to?(:size)
        rescue StandardError => e
          stats[:failed] += 1
          warn "Failed to extract #{file.name}: #{e.message}"
        end

        stats
      end

      private

      def stream_cab_files
        # Use lazy enumeration for CAB files
        parser = Cabriolet::CAB::Parser.new
        cabinet = parser.parse(@path)

        # Wrap files in lazy enumerator
        cabinet.files.lazy.each do |file|
          yield LazyFile.new(file, @chunk_size)
        end
      end

      def stream_chm_files
        parser = Cabriolet::CHM::Parser.new
        chm = parser.parse(@path)

        chm.files.lazy.each do |file|
          yield LazyFile.new(file, @chunk_size)
        end
      end
    end

    # Wrapper for lazy file data loading
    class LazyFile
      def initialize(file, chunk_size)
        @file = file
        @chunk_size = chunk_size
        @data_loaded = false
      end

      def name
        @file.name
      end

      def size
        @file.size
      end

      def attributes
        @file.attributes if @file.respond_to?(:attributes)
      end

      def date
        @file.date if @file.respond_to?(:date)
      end

      def time
        @file.time if @file.respond_to?(:time)
      end

      # Load data only when accessed
      def data
        @data ||= @file.data
      end

      # Stream data in chunks
      def stream_data(chunk_size: @chunk_size)
        full_data = data
        offset = 0

        while offset < full_data.bytesize
          chunk = full_data.byteslice(offset, chunk_size)
          yield chunk
          offset += chunk_size
        end
      end

      def method_missing(method, ...)
        @file.send(method, ...)
      end

      def respond_to_missing?(method, include_private = false)
        @file.respond_to?(method, include_private)
      end
    end

    # Stream processor for batch operations
    class BatchProcessor
      def initialize(chunk_size: StreamParser::DEFAULT_CHUNK_SIZE)
        @chunk_size = chunk_size
        @stats = { processed: 0, failed: 0, bytes: 0 }
      end

      # Process multiple archives in streaming mode
      #
      # @param paths [Array<String>] Array of archive paths
      # @yield [file, archive_path] Yields each file with its archive path
      # @return [Hash] Processing statistics
      def process_archives(paths, &block)
        paths.each do |path|
          process_archive(path, &block)
        end

        @stats
      end

      # Process single archive in streaming mode
      #
      # @param path [String] Archive path
      # @yield [file] Yields each file
      def process_archive(path)
        parser = StreamParser.new(path, chunk_size: @chunk_size)

        parser.each_file do |file|
          yield file, path
          @stats[:processed] += 1
          @stats[:bytes] += file.size if file.respond_to?(:size)
        rescue StandardError => e
          @stats[:failed] += 1
          warn "Error processing #{file.name} from #{path}: #{e.message}"
        end
      rescue StandardError => e
        warn "Error processing archive #{path}: #{e.message}"
      end

      attr_reader :stats
    end
  end
end
