# frozen_string_literal: true

require "cabriolet"

module Cabriolet
  module Plugins
    # Advanced plugin example demonstrating BZip2 compression
    #
    # This plugin provides a stub implementation of BZip2 compression to
    # demonstrate advanced plugin features including:
    # - Configuration options
    # - Format-specific registration
    # - Error handling and validation
    # - Block size configuration
    # - Compression level settings
    # - Progress reporting
    #
    # Note: This is a stub implementation for demonstration purposes.
    # A production BZip2 implementation would require the full algorithm.
    #
    # @example Loading and configuring the plugin
    #   manager = Cabriolet.plugin_manager
    #   manager.load_plugin("cabriolet-plugin-bzip2")
    #   manager.activate_plugin("cabriolet-plugin-bzip2")
    #
    #   # Use BZip2 with configuration
    #   factory = Cabriolet.algorithm_factory
    #   compressor = factory.create(:bzip2, :compressor,
    #                               io, input, output, 4096,
    #                               block_size: 9, level: 9)
    class BZip2Plugin < Plugin
      # Default configuration values
      DEFAULT_BLOCK_SIZE = 9   # 900KB blocks
      DEFAULT_LEVEL = 9        # Maximum compression
      MIN_BLOCK_SIZE = 1       # 100KB
      MAX_BLOCK_SIZE = 9       # 900KB
      MIN_LEVEL = 1            # Fast compression
      MAX_LEVEL = 9            # Best compression

      # Plugin metadata
      #
      # @return [Hash] Plugin metadata with all details
      def metadata
        {
          name: "cabriolet-plugin-bzip2",
          version: "1.0.0",
          author: "Cabriolet Team",
          description: "BZip2 compression algorithm plugin (stub implementation)",
          cabriolet_version: "~> 0.1",
          homepage: "https://github.com/omnizip/cabriolet",
          license: "BSD-2-Clause",
          dependencies: [],
          tags: ["compression", "bzip2", "algorithm", "advanced"],
          provides: {
            algorithms: [:bzip2],
            formats: [:bz2],
          },
        }
      end

      # Setup the plugin
      #
      # Registers BZip2 compressor and decompressor with proper
      # configuration support.
      #
      # @return [void]
      def setup
        # Register BZip2 compressor with higher priority
        register_algorithm(:bzip2, BZip2Compressor,
                          category: :compressor,
                          priority: 10)

        # Register BZip2 decompressor
        register_algorithm(:bzip2, BZip2Decompressor,
                          category: :decompressor,
                          priority: 10)

        @config = load_configuration
        puts "BZip2Plugin: Registered with block_size=#{@config[:block_size]}, " \
             "level=#{@config[:level]}" if @verbose
      end

      # Activate the plugin
      #
      # @return [void]
      def activate
        puts "BZip2Plugin: Activated - BZip2 compression is now available"
        validate_configuration
        @activated_at = Time.now
        @compression_stats = { files: 0, bytes_in: 0, bytes_out: 0 }
      end

      # Deactivate the plugin
      #
      # @return [void]
      def deactivate
        puts "BZip2Plugin: Deactivated"
        report_statistics if @compression_stats
        @activated_at = nil
      end

      # Cleanup the plugin
      #
      # @return [void]
      def cleanup
        puts "BZip2Plugin: Cleanup complete"
        @config = nil
        @compression_stats = nil
      end

      private

      # Load configuration from environment or defaults
      #
      # @return [Hash] Configuration hash
      def load_configuration
        {
          block_size: ENV.fetch("BZIP2_BLOCK_SIZE", DEFAULT_BLOCK_SIZE).to_i,
          level: ENV.fetch("BZIP2_LEVEL", DEFAULT_LEVEL).to_i,
        }
      end

      # Validate configuration values
      #
      # @raise [PluginError] If configuration is invalid
      #
      # @return [void]
      def validate_configuration
        block_size = @config[:block_size]
        level = @config[:level]

        unless (MIN_BLOCK_SIZE..MAX_BLOCK_SIZE).cover?(block_size)
          raise PluginError,
                "Invalid block_size: #{block_size}. " \
                "Must be between #{MIN_BLOCK_SIZE} and #{MAX_BLOCK_SIZE}"
        end

        unless (MIN_LEVEL..MAX_LEVEL).cover?(level)
          raise PluginError,
                "Invalid level: #{level}. " \
                "Must be between #{MIN_LEVEL} and #{MAX_LEVEL}"
        end
      end

      # Report compression statistics
      #
      # @return [void]
      def report_statistics
        return unless @compression_stats[:files] > 0

        ratio = if @compression_stats[:bytes_in] > 0
                  ((@compression_stats[:bytes_out].to_f /
                    @compression_stats[:bytes_in]) * 100).round(2)
                else
                  0.0
                end

        puts "BZip2Plugin Statistics:"
        puts "  Files compressed: #{@compression_stats[:files]}"
        puts "  Bytes in: #{@compression_stats[:bytes_in]}"
        puts "  Bytes out: #{@compression_stats[:bytes_out]}"
        puts "  Compression ratio: #{ratio}%"
      end

      # BZip2 Compressor (Stub Implementation)
      #
      # Demonstrates advanced compressor features including:
      # - Configuration options (block size, level)
      # - Progress reporting
      # - Error handling
      # - Statistics tracking
      #
      # Note: This is a stub that doesn't implement actual BZip2 compression.
      # It demonstrates the structure and API for a real implementation.
      #
      # @example Using BZip2 compressor with options
      #   compressor = BZip2Compressor.new(io, input, output, 4096,
      #                                    block_size: 9, level: 9,
      #                                    progress: ->(pct) { puts "#{pct}%" })
      #   bytes = compressor.compress
      class BZip2Compressor < Compressors::Base
        # BZip2 magic header
        MAGIC = "BZ"

        # Initialize BZip2 compressor
        #
        # @param io_system [System::IOSystem] I/O system
        # @param input [System::Handle] Input handle
        # @param output [System::Handle] Output handle
        # @param buffer_size [Integer] Buffer size
        # @param kwargs [Hash] Options
        # @option kwargs [Integer] :block_size Block size (1-9, default 9)
        # @option kwargs [Integer] :level Compression level (1-9, default 9)
        # @option kwargs [Proc] :progress Progress callback
        def initialize(io_system, input, output, buffer_size, **kwargs)
          super
          @block_size = kwargs.fetch(:block_size, DEFAULT_BLOCK_SIZE)
          @level = kwargs.fetch(:level, DEFAULT_LEVEL)
          @progress = kwargs[:progress]

          validate_options!
        end

        # Compress input using BZip2
        #
        # @return [Integer] Number of bytes written
        #
        # @raise [CompressionError] If compression fails
        #
        # @example
        #   bytes = compressor.compress
        #   puts "Compressed to #{bytes} bytes"
        def compress
          validate_state!

          # Write BZip2 header
          write_header

          bytes_written = 4 # Magic + version + block_size
          bytes_read = 0
          total_size = estimate_input_size

          # Process input in blocks
          loop do
            block = @input.read(@buffer_size)
            break if block.nil? || block.empty?

            bytes_read += block.bytesize

            # Stub: In real implementation, would call BZip2 algorithm
            compressed = compress_block(block)
            @output.write(compressed)
            bytes_written += compressed.bytesize

            # Report progress
            report_progress(bytes_read, total_size) if @progress
          end

          # Write end-of-stream marker
          write_eos_marker
          bytes_written += 10 # EOS marker size

          bytes_written
        rescue StandardError => e
          raise CompressionError,
                "BZip2 compression failed: #{e.message}"
        end

        private

        # Validate configuration options
        #
        # @raise [ArgumentError] If options invalid
        #
        # @return [void]
        def validate_options!
          unless (MIN_BLOCK_SIZE..MAX_BLOCK_SIZE).cover?(@block_size)
            raise ArgumentError,
                  "block_size must be between #{MIN_BLOCK_SIZE} " \
                  "and #{MAX_BLOCK_SIZE}"
          end

          unless (MIN_LEVEL..MAX_LEVEL).cover?(@level)
            raise ArgumentError,
                  "level must be between #{MIN_LEVEL} and #{MAX_LEVEL}"
          end
        end

        # Validate compressor state
        #
        # @raise [CompressionError] If state invalid
        #
        # @return [void]
        def validate_state!
          raise CompressionError, "Input handle is closed" if @input.closed?
          raise CompressionError, "Output handle is closed" if @output.closed?
        end

        # Write BZip2 header
        #
        # Format: "BZ" + 'h' + block_size_digit
        #
        # @return [void]
        def write_header
          header = "#{MAGIC}h#{@block_size}"
          @output.write(header)
        end

        # Compress a single block (stub)
        #
        # @param block [String] Block data
        # @return [String] Compressed block
        def compress_block(block)
          # Stub: Real implementation would use BZip2 algorithm
          # For now, just return the block with a marker
          "\x31\x41\x59\x26\x53\x59" + block # BZip2 block header + data
        end

        # Write end-of-stream marker
        #
        # @return [void]
        def write_eos_marker
          # BZip2 EOS marker
          @output.write("\x17\x72\x45\x38\x50\x90" + "\x00" * 4)
        end

        # Estimate input size for progress reporting
        #
        # @return [Integer] Estimated size
        def estimate_input_size
          pos = @input.tell
          @input.seek(0, IO::SEEK_END)
          size = @input.tell
          @input.seek(pos)
          size
        rescue StandardError
          0 # Unknown size
        end

        # Report compression progress
        #
        # @param current [Integer] Current bytes processed
        # @param total [Integer] Total bytes to process
        #
        # @return [void]
        def report_progress(current, total)
          return if total.zero?

          percentage = ((current.to_f / total) * 100).round(2)
          @progress.call(percentage)
        end
      end

      # BZip2 Decompressor (Stub Implementation)
      #
      # Demonstrates advanced decompressor features including:
      # - Header validation
      # - Error detection
      # - Progress reporting
      # - Resource management
      #
      # @example Using BZip2 decompressor
      #   decompressor = BZip2Decompressor.new(io, input, output, 4096,
      #                                        progress: ->(pct) { puts "#{pct}%" })
      #   bytes = decompressor.decompress(1000000)
      class BZip2Decompressor < Decompressors::Base
        # Initialize BZip2 decompressor
        #
        # @param io_system [System::IOSystem] I/O system
        # @param input [System::Handle] Input handle
        # @param output [System::Handle] Output handle
        # @param buffer_size [Integer] Buffer size
        # @param kwargs [Hash] Options
        # @option kwargs [Proc] :progress Progress callback
        def initialize(io_system, input, output, buffer_size, **kwargs)
          super
          @progress = kwargs[:progress]
          @header_read = false
          @block_size = nil
        end

        # Decompress BZip2 data
        #
        # @param bytes [Integer] Maximum bytes to decompress
        # @return [Integer] Bytes actually decompressed
        #
        # @raise [DecompressionError] If decompression fails
        #
        # @example
        #   bytes = decompressor.decompress(1000000)
        def decompress(bytes)
          validate_state!

          # Read and validate header on first call
          read_and_validate_header unless @header_read

          bytes_decompressed = 0
          remaining = bytes

          # Process compressed blocks
          while remaining > 0
            block = read_compressed_block
            break if block.nil? # End of stream

            # Stub: In real implementation, would decompress block
            decompressed = decompress_block(block)
            break if decompressed.nil?

            # Write decompressed data
            to_write = [decompressed.bytesize, remaining].min
            @output.write(decompressed[0, to_write])
            bytes_decompressed += to_write
            remaining -= to_write

            # Report progress
            report_progress(bytes_decompressed, bytes) if @progress
          end

          bytes_decompressed
        rescue StandardError => e
          raise DecompressionError,
                "BZip2 decompression failed: #{e.message}"
        end

        # Free decompressor resources
        #
        # @return [void]
        def free
          @header_read = false
          @block_size = nil
        end

        private

        # Validate decompressor state
        #
        # @raise [DecompressionError] If state invalid
        #
        # @return [void]
        def validate_state!
          raise DecompressionError, "Input closed" if @input.closed?
          raise DecompressionError, "Output closed" if @output.closed?
        end

        # Read and validate BZip2 header
        #
        # @raise [DecompressionError] If header invalid
        #
        # @return [void]
        def read_and_validate_header
          header = @input.read(4)
          raise DecompressionError, "Truncated header" if header.nil? || header.size < 4

          # Validate magic
          magic = header[0, 2]
          unless magic == "BZ"
            raise DecompressionError,
                  "Invalid BZip2 magic: expected 'BZ', got '#{magic}'"
          end

          # Validate version
          version = header[2]
          unless version == "h"
            raise DecompressionError,
                  "Unsupported BZip2 version: '#{version}'"
          end

          # Read block size
          @block_size = header[3].to_i
          unless (MIN_BLOCK_SIZE..MAX_BLOCK_SIZE).cover?(@block_size)
            raise DecompressionError,
                  "Invalid block size: #{@block_size}"
          end

          @header_read = true
        end

        # Read next compressed block
        #
        # @return [String, nil] Compressed block or nil if end of stream
        def read_compressed_block
          # Read block header
          block_header = @input.read(6)
          return nil if block_header.nil? || block_header.size < 6

          # Check for EOS marker
          if block_header[0, 6] == "\x17\x72\x45\x38\x50\x90"
            return nil
          end

          # Stub: Read block data (in real implementation, parse block structure)
          block_data = @input.read(@buffer_size)
          block_header + block_data
        end

        # Decompress a single block (stub)
        #
        # @param block [String] Compressed block
        # @return [String, nil] Decompressed data
        def decompress_block(block)
          # Stub: Real implementation would use BZip2 algorithm
          # Skip block header and return data
          block[6..-1] if block && block.size > 6
        end

        # Report decompression progress
        #
        # @param current [Integer] Current bytes decompressed
        # @param total [Integer] Total bytes to decompress
        #
        # @return [void]
        def report_progress(current, total)
          return if total.zero?

          percentage = ((current.to_f / total) * 100).round(2)
          @progress.call(percentage)
        end
      end
    end
  end
end

# Auto-register the plugin
if defined?(Cabriolet::PluginManager)
  manager = Cabriolet.plugin_manager
  plugin = Cabriolet::Plugins::BZip2Plugin.new(manager)
  manager.register(plugin)
end
