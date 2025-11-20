# frozen_string_literal: true

require_relative "file_manager"
require_relative "system/io_system"

module Cabriolet
  # Abstract base class for all format compressors
  #
  # Implements Template Method pattern:
  # - Defines common compression workflow in generate()
  # - Subclasses implement format-specific hooks
  #
  # Provides:
  # - File management via FileManager
  # - Common initialization pattern
  # - Template method for generation workflow
  # - Hook methods for format customization
  # - Helper methods for common operations
  #
  # Subclasses must implement:
  # - build_structure(options) - Create format-specific structure
  # - write_format(output_handle, structure) - Write binary data
  #
  # Subclasses may override:
  # - validate_generation_prerequisites!(options) - Custom validation
  # - post_generation_hook(output_file, structure, bytes) - Cleanup/logging
  #
  # @example Creating a format compressor
  #   class MyFormatCompressor < BaseCompressor
  #     protected
  #
  #     def build_structure(options)
  #       { header: build_header, files: collect_files }
  #     end
  #
  #     def write_format(output_handle, structure)
  #       io_system.write(output_handle, structure[:header].to_binary_s)
  #     end
  #   end
  class BaseCompressor
    attr_reader :io_system, :algorithm_factory, :file_manager

    # Initialize compressor with I/O and algorithm dependencies
    #
    # @param io_system [System::IOSystem, nil] I/O system or nil for default
    # @param algorithm_factory [AlgorithmFactory, nil] Algorithm factory or nil
    def initialize(io_system = nil, algorithm_factory = nil)
      @io_system = io_system || System::IOSystem.new
      @algorithm_factory = algorithm_factory || Cabriolet.algorithm_factory
      @file_manager = FileManager.new
    end

    # Add file from disk to archive
    #
    # @param source_path [String] Path to source file
    # @param archive_path [String, nil] Path in archive (nil = use basename)
    # @param options [Hash] Format-specific options
    # @return [FileEntry] Added entry
    # @raise [ArgumentError] if file doesn't exist
    def add_file(source_path, archive_path = nil, **options)
      @file_manager.add_file(source_path, archive_path, **options)
    end

    # Add file from memory to archive
    #
    # @param data [String] File data
    # @param archive_path [String] Path in archive
    # @param options [Hash] Format-specific options
    # @return [FileEntry] Added entry
    def add_data(data, archive_path, **options)
      @file_manager.add_data(data, archive_path, **options)
    end

    # Generate archive (Template Method)
    #
    # This method defines the compression workflow:
    # 1. Validate prerequisites
    # 2. Build format-specific structure
    # 3. Write to output file
    # 4. Post-generation hook
    # 5. Return bytes written
    #
    # Subclasses customize via hook methods, not by overriding this method.
    #
    # @param output_file [String] Path to output file
    # @param options [Hash] Format-specific options
    # @return [Integer] Bytes written to output file
    # @raise [ArgumentError] if validation fails
    def generate(output_file, **options)
      validate_generation_prerequisites!(options)

      structure = build_structure(options)

      bytes_written = write_to_file(output_file, structure)

      post_generation_hook(output_file, structure, bytes_written)

      bytes_written
    end

    protected

    # Hook: Build format-specific structure
    #
    # Subclasses MUST implement this method to create the archive structure
    # ready for writing. The structure should contain all necessary metadata,
    # compressed data, headers, and calculated offsets.
    #
    # @param options [Hash] Generation options from generate() call
    # @return [Hash] Format structure ready for writing
    # @raise [NotImplementedError] if not implemented by subclass
    def build_structure(options)
      raise NotImplementedError,
            "#{self.class.name} must implement build_structure(options)"
    end

    # Hook: Write format to output handle
    #
    # Subclasses MUST implement this method to write the format-specific
    # binary data to the output handle. Should write headers, directory,
    # and file data according to format specification.
    #
    # @param output_handle [System::FileHandle] Open output handle
    # @param structure [Hash] Format structure from build_structure()
    # @return [Integer] Bytes written
    # @raise [NotImplementedError] if not implemented by subclass
    def write_format(output_handle, structure)
      raise NotImplementedError,
            "#{self.class.name} must implement write_format(output_handle, structure)"
    end

    # Hook: Validate pre-generation requirements
    #
    # Subclasses CAN override this for format-specific validation.
    # Default implementation checks that files have been added.
    #
    # @param options [Hash] Generation options
    # @raise [ArgumentError] if validation fails
    def validate_generation_prerequisites!(_options)
      raise ArgumentError, "No files added to archive" if @file_manager.empty?
    end

    # Hook: Post-generation callback
    #
    # Subclasses CAN override this for cleanup, logging, or additional
    # processing after successful generation.
    #
    # @param output_file [String] Path to generated file
    # @param structure [Hash] Generated structure
    # @param bytes_written [Integer] Bytes written to file
    # @return [void]
    def post_generation_hook(_output_file, _structure, _bytes_written)
      # Default: no-op
      nil
    end

    # Helper: Compress data using specified algorithm
    #
    # Provides unified interface for compression across all formats.
    # Uses algorithm factory for extensibility.
    #
    # @param data [String] Data to compress
    # @param algorithm [Symbol] Algorithm type (:lzss, :mszip, :lzx, :quantum)
    # @param options [Hash] Compression options
    # @option options [Integer] :window_bits Window size in bits
    # @option options [Integer] :mode Algorithm mode
    # @return [String] Compressed data
    def compress_data(data, algorithm:, **options)
      input = System::MemoryHandle.new(data)
      output = System::MemoryHandle.new("", Constants::MODE_WRITE)

      compressor = @algorithm_factory.create(
        algorithm,
        :compressor,
        @io_system,
        input,
        output,
        data.bytesize,
        **options,
      )

      compressor.compress
      output.data
    end

    private

    # Write structure to file
    #
    # Handles file opening/closing and delegates to write_format hook
    #
    # @param output_file [String] Path to output file
    # @param structure [Hash] Format structure
    # @return [Integer] Bytes written
    def write_to_file(output_file, structure)
      output_handle = @io_system.open(output_file, Constants::MODE_WRITE)

      begin
        bytes = write_format(output_handle, structure)
        bytes
      ensure
        @io_system.close(output_handle) if output_handle
      end
    end
  end
end
