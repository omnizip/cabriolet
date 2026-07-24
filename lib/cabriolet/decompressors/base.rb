# frozen_string_literal: true

module Cabriolet
  module Decompressors
    # Base class for all decompression algorithms
    class Base
      attr_reader :io_system, :input, :output, :buffer_size

      def initialize(io_system, input, output, buffer_size, **_kwargs)
        @io_system = io_system
        @input = input
        @output = output
        @buffer_size = buffer_size
      end

      def decompress(bytes)
        raise NotImplementedError, "#{self.class} must implement #decompress"
      end

      # Decompress with a specific output handle, then restore the previous output.
      # Used by callers that need to redirect decompression output temporarily.
      #
      # @param temporary_output [System::FileHandle, System::MemoryHandle] Output to decompress into
      # @return [Integer] Bytes decompressed
      def decompress_to(temporary_output, bytes)
        original_output = @output
        @output = temporary_output
        decompress(bytes)
      ensure
        @output = original_output
      end

      # Yield with a temporarily swapped output handle, restoring the original on exit.
      #
      # @param temporary_output [System::FileHandle, System::MemoryHandle] Temporary output
      # @yield Block to execute with the temporary output active
      def with_output(temporary_output)
        original_output = @output
        @output = temporary_output
        yield
      ensure
        @output = original_output
      end

      def free
        # Override in subclasses if cleanup needed
      end
    end
  end
end
