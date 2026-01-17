# frozen_string_literal: true

module Cabriolet
  # FormatBase provides common functionality for all format-specific compressors
  # and decompressors, reducing code duplication and establishing consistent patterns.
  class FormatBase
    # Initialize a format handler with common dependencies
    #
    # @param io_system [System::IOSystem, nil] I/O system for file operations
    # @param algorithm_factory [AlgorithmFactory, nil] Factory for compression algorithms
    def initialize(io_system = nil, algorithm_factory = nil)
      @io_system = io_system || System::IOSystem.new
      @algorithm_factory = algorithm_factory || Cabriolet.algorithm_factory
    end

    protected

    # Execute a block with file handles, automatically closing them after completion
    #
    # @param input_path [String] Path to input file
    # @param output_path [String, nil] Path to output file (optional)
    # @yield [Array<System::FileHandle>] File handles for input and output
    # @return [Object] Return value of the block
    def with_file_handles(input_path, output_path = nil)
      input_handle = @io_system.open(input_path, Constants::MODE_READ)
      output_handle = if output_path
                        @io_system.open(output_path,
                                        Constants::MODE_WRITE)
                      end

      begin
        yield [input_handle, output_handle].compact
      ensure
        @io_system.close(input_handle) if input_handle
        @io_system.close(output_handle) if output_handle
      end
    end

    # Create a compressor using the algorithm factory
    #
    # @param algorithm [Symbol] Compression algorithm type
    # @param input [System::FileHandle, System::MemoryHandle] Input handle
    # @param output [System::FileHandle, System::MemoryHandle] Output handle
    # @param size [Integer] Data size
    # @param options [Hash] Additional options for the compressor
    # @return [Object] Compressor instance
    def create_compressor(algorithm, input, output, size, **options)
      @algorithm_factory.create(
        algorithm,
        :compressor,
        @io_system,
        input,
        output,
        size,
        **options,
      )
    end

    # Create a decompressor using the algorithm factory
    #
    # @param algorithm [Symbol] Compression algorithm type
    # @param input [System::FileHandle, System::MemoryHandle] Input handle
    # @param output [System::FileHandle, System::MemoryHandle] Output handle
    # @param size [Integer] Data size
    # @param options [Hash] Additional options for the decompressor
    # @return [Object] Decompressor instance
    def create_decompressor(algorithm, input, output, size, **options)
      @algorithm_factory.create(
        algorithm,
        :decompressor,
        @io_system,
        input,
        output,
        size,
        **options,
      )
    end
  end
end
