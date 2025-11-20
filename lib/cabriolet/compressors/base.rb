# frozen_string_literal: true

module Cabriolet
  module Compressors
    # Base class for all compression algorithms
    #
    # Provides common interface and functionality for compressors.
    # Each compressor implementation must override the compress method.
    class Base
      attr_reader :io_system, :input, :output, :buffer_size

      # Initialize base compressor
      #
      # @param io_system [System::IOSystem] I/O system for reading/writing
      # @param input [System::FileHandle, System::MemoryHandle] Input handle
      # @param output [System::FileHandle, System::MemoryHandle] Output handle
      # @param buffer_size [Integer] Buffer size for I/O operations
      def initialize(io_system, input, output, buffer_size, **_kwargs)
        @io_system = io_system
        @input = input
        @output = output
        @buffer_size = buffer_size
      end

      # Compress the input data
      #
      # @return [Integer] Number of bytes written
      # @raise [NotImplementedError] Must be implemented by subclasses
      def compress
        raise NotImplementedError, "#{self.class} must implement #compress"
      end
    end
  end
end
