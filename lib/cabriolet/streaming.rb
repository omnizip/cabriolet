# frozen_string_literal: true

module Cabriolet
  # Streaming API for memory-efficient processing of large archives
  module Streaming
    # Stream-based archive parser
    class StreamParser
      DEFAULT_CHUNK_SIZE = 65_536 # 64KB chunks

      # Registry of format → streaming method. New formats register here
      # instead of adding case/when branches (Open/Closed Principle).
      STREAM_METHODS = {
        cab: :stream_cab_files,
        chm: :stream_chm_files,
      }.freeze

      @registered_methods = {}

      class << self
        # Register a streaming method for a format at runtime.
        #
        # @param format [Symbol] Format identifier
        # @param method_name [Symbol] Method name on StreamParser instances
        def register_stream_method(format, method_name)
          @registered_methods[format] = method_name
        end

        # Get the streaming method for a format (runtime registry first, then built-in).
        def stream_method_for(format)
          @registered_methods[format] || STREAM_METHODS[format]
        end
      end

      def initialize(path, chunk_size: DEFAULT_CHUNK_SIZE)
        @path = path
        @chunk_size = chunk_size
        @format = FormatDetector.detect(path)
        raise UnsupportedFormatError, "Unable to detect format" unless @format
      end

      # Iterate over files without loading entire archive into memory.
      # Dispatches to the format-specific streaming method via a registry.
      #
      # @yield [file] Yields each file object
      # @return [Enumerator] if no block given
      def each_file(&)
        return enum_for(:each_file) unless block_given?

        method_name = stream_method_for(@format)
        if method_name
          method(method_name).call(&)
        else
          archive = Cabriolet.open(@path)
          archive.files.each(&)
        end
      end

      private

      # Look up the streaming method for a format.
      def stream_method_for(format)
        self.class.stream_method_for(format)
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

        if file.is_a?(LazyFile)
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
          stats[:bytes] += file.size
        rescue StandardError => e
          stats[:failed] += 1
          warn "Failed to extract #{file.name}: #{e.message}"
        end

        stats
      end

      # Stream files from a CAB archive.
      def stream_cab_files
        # Use lazy enumeration for CAB files
        parser = Cabriolet::CAB::Parser.new(Cabriolet::System::IOSystem.new)
        cabinet = parser.parse(@path)

        # Wrap files in lazy enumerator
        cabinet.files.lazy.each do |file|
          yield LazyFile.new(file, @chunk_size)
        end
      end

      # Stream files from a CHM archive.
      def stream_chm_files
        parser = Cabriolet::CHM::Parser.new(Cabriolet::System::IOSystem.new)
        chm = parser.parse(@path)

        chm.files.lazy.each do |file|
          yield LazyFile.new(file, @chunk_size)
        end
      end
    end

    # Wrapper for lazy file data loading
    #
    # Delegates the file interface explicitly — no method_missing, so
    # callers get clear NoMethodError feedback for unsupported operations.
    class LazyFile
      def initialize(file, chunk_size)
        @file = file
        @chunk_size = chunk_size
      end

      def name
        @file.name
      end

      def size
        @file.size
      end

      def attributes
        @file.attributes
      end

      def date
        @file.date
      end

      def time
        @file.time
      end

      def data
        @data ||= @file.data
      end

      def stream_data(chunk_size: @chunk_size)
        full_data = data
        offset = 0

        while offset < full_data.bytesize
          chunk = full_data.byteslice(offset, chunk_size)
          yield chunk
          offset += chunk_size
        end
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
      def process_archives(paths, &)
        paths.each do |path|
          process_archive(path, &)
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
          @stats[:bytes] += file.size
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
