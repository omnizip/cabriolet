# frozen_string_literal: true

module Cabriolet
  module Decompressors
    # Base class for all decompression algorithms
    class Base
      attr_reader :io_system, :input, :output, :buffer_size

      # Initialize a new decompressor
      #
      # @param io_system [System::IOSystem] I/O system for reading/writing
      # @param input [System::FileHandle, System::MemoryHandle] Input handle
      # @param output [System::FileHandle, System::MemoryHandle] Output handle
      # @param buffer_size [Integer] Buffer size for I/O operations
      def initialize(io_system, input, output, buffer_size)
        @io_system = io_system
        @input = input
        @output = output
        @buffer_size = buffer_size
      end

      # Decompress the specified number of bytes
      #
      # @param bytes [Integer] Number of bytes to decompress
      # @return [Integer] Number of bytes decompressed
      # @raise [NotImplementedError] Must be implemented by subclasses
      def decompress(bytes)
        raise NotImplementedError, "#{self.class} must implement #decompress"
      end

      # Free any resources used by the decompressor
      #
      # @return [void]
      def free
        # Override in subclasses if cleanup needed
      end
    end
  end
end
