# frozen_string_literal: true

require "cabriolet"

module Cabriolet
  module Plugins
    # Example plugin demonstrating Cabriolet plugin architecture
    #
    # This plugin provides a simple ROT13 "compression" algorithm that
    # rotates each letter by 13 positions in the alphabet. It's designed
    # to demonstrate plugin development concepts, not for actual use.
    #
    # Features demonstrated:
    # - Plugin metadata definition
    # - Algorithm registration (compressor and decompressor)
    # - Lifecycle hooks (activate, deactivate, cleanup)
    # - Dependency specification
    # - Configuration options
    # - Full YARD documentation
    #
    # @example Loading and using the plugin
    #   manager = Cabriolet.plugin_manager
    #   manager.discover_plugins
    #   manager.load_plugin("cabriolet-plugin-example")
    #   manager.activate_plugin("cabriolet-plugin-example")
    #
    #   # Use ROT13 algorithm
    #   factory = Cabriolet.algorithm_factory
    #   compressor = factory.create(:rot13, :compressor, io, input, output, 4096)
    #   compressor.compress
    class ExamplePlugin < Plugin
      # Plugin metadata
      #
      # Provides all required and optional metadata for plugin identification
      # and compatibility checking.
      #
      # @return [Hash] Plugin metadata
      def metadata
        {
          name: "cabriolet-plugin-example",
          version: "1.0.0",
          author: "Cabriolet Team",
          description: "Example plugin demonstrating ROT13 compression algorithm",
          cabriolet_version: "~> 0.1",
          homepage: "https://github.com/omnizip/cabriolet",
          license: "BSD-2-Clause",
          dependencies: [], # No dependencies for this simple example
          tags: ["example", "rot13", "learning"],
          provides: {
            algorithms: [:rot13],
            formats: [],
          },
        }
      end

      # Setup the plugin
      #
      # Registers the ROT13 compressor and decompressor algorithms.
      # Called during plugin load phase.
      #
      # @return [void]
      def setup
        # Register ROT13 compressor
        register_algorithm(:rot13, ROT13Compressor,
                          category: :compressor,
                          priority: 0)

        # Register ROT13 decompressor
        register_algorithm(:rot13, ROT13Decompressor,
                          category: :decompressor,
                          priority: 0)

        puts "ExamplePlugin: Registered ROT13 algorithms" if @verbose
      end

      # Activate the plugin
      #
      # Called when the plugin is activated. Demonstrates activation hooks.
      #
      # @return [void]
      def activate
        puts "ExamplePlugin: Activated - ROT13 algorithms are now available"
        @activated_at = Time.now
      end

      # Deactivate the plugin
      #
      # Called when the plugin is deactivated. Demonstrates deactivation hooks.
      #
      # @return [void]
      def deactivate
        puts "ExamplePlugin: Deactivated"
        @activated_at = nil
      end

      # Cleanup the plugin
      #
      # Called when the plugin is unloaded. Demonstrates cleanup hooks.
      #
      # @return [void]
      def cleanup
        puts "ExamplePlugin: Cleanup complete"
      end

      # ROT13 Compressor
      #
      # Simple ROT13 "compressor" that rotates letters by 13 positions.
      # Note: ROT13 doesn't actually compress data - it's just for demonstration.
      #
      # @example Using ROT13 compressor
      #   io = Cabriolet::System::IOSystem.new
      #   input = io.open_file("input.txt", "rb")
      #   output = io.open_file("output.rot13", "wb")
      #   compressor = ROT13Compressor.new(io, input, output, 4096)
      #   compressor.compress
      class ROT13Compressor < Compressors::Base
        # Compress input using ROT13
        #
        # Reads all input data and applies ROT13 transformation,
        # writing the result to output.
        #
        # @return [Integer] Number of bytes written
        #
        # @example
        #   bytes_written = compressor.compress
        #   puts "Compressed #{bytes_written} bytes"
        def compress
          bytes_written = 0

          # Read and transform data in chunks
          loop do
            chunk = @input.read(@buffer_size)
            break if chunk.nil? || chunk.empty?

            # Apply ROT13 transformation
            transformed = rot13_transform(chunk)
            @output.write(transformed)
            bytes_written += transformed.bytesize
          end

          bytes_written
        end

        private

        # Apply ROT13 transformation to data
        #
        # Rotates each letter by 13 positions in the alphabet,
        # leaving non-letters unchanged.
        #
        # @param data [String] Input data
        # @return [String] Transformed data
        def rot13_transform(data)
          data.tr("A-Za-z", "N-ZA-Mn-za-m")
        end
      end

      # ROT13 Decompressor
      #
      # Simple ROT13 "decompressor" that rotates letters by 13 positions.
      # Since ROT13 is symmetric, decompression is identical to compression.
      #
      # @example Using ROT13 decompressor
      #   io = Cabriolet::System::IOSystem.new
      #   input = io.open_file("input.rot13", "rb")
      #   output = io.open_file("output.txt", "wb")
      #   decompressor = ROT13Decompressor.new(io, input, output, 4096)
      #   decompressor.decompress(1000000)
      class ROT13Decompressor < Decompressors::Base
        # Decompress input using ROT13
        #
        # Reads specified number of bytes and applies ROT13 transformation,
        # writing the result to output. Since ROT13 is symmetric, this is
        # identical to compression.
        #
        # @param bytes [Integer] Maximum number of bytes to decompress
        # @return [Integer] Number of bytes actually decompressed
        #
        # @example
        #   bytes_read = decompressor.decompress(1000000)
        #   puts "Decompressed #{bytes_read} bytes"
        def decompress(bytes)
          bytes_read = 0
          remaining = bytes

          # Read and transform data in chunks
          while remaining > 0
            chunk_size = [@buffer_size, remaining].min
            chunk = @input.read(chunk_size)
            break if chunk.nil? || chunk.empty?

            # Apply ROT13 transformation (same as compression)
            transformed = rot13_transform(chunk)
            @output.write(transformed)

            chunk_bytes = chunk.bytesize
            bytes_read += chunk_bytes
            remaining -= chunk_bytes
          end

          bytes_read
        end

        # Free resources
        #
        # Called when decompressor is done. No resources to free for ROT13.
        #
        # @return [void]
        def free
          # No resources to free
        end

        private

        # Apply ROT13 transformation to data
        #
        # Rotates each letter by 13 positions in the alphabet,
        # leaving non-letters unchanged.
        #
        # @param data [String] Input data
        # @return [String] Transformed data
        def rot13_transform(data)
          data.tr("A-Za-z", "N-ZA-Mn-za-m")
        end
      end
    end
  end
end

# Auto-register the plugin
if defined?(Cabriolet::PluginManager)
  manager = Cabriolet.plugin_manager
  plugin = Cabriolet::Plugins::ExamplePlugin.new(manager)
  manager.register(plugin)
end
