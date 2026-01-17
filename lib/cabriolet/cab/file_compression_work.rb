# frozen_string_literal: true

require "fractor"

module Cabriolet
  module CAB
    # Work item for compressing a single file in a CAB archive
    class FileCompressionWork < Fractor::Work
      # Initialize work item for file compression
      #
      # @param source_path [String] Path to source file
      # @param compression_method [Symbol] Compression method to use
      # @param block_size [Integer] Maximum block size
      # @param io_system [System::IOSystem] I/O system
      # @param algorithm_factory [AlgorithmFactory] Algorithm factory
      def initialize(source_path:, compression_method:, block_size:, io_system:, algorithm_factory:)
        super({
          source_path: source_path,
          compression_method: compression_method,
          block_size: block_size,
          io_system: io_system,
          algorithm_factory: algorithm_factory,
        })
      end

      def source_path
        input[:source_path]
      end

      def compression_method
        input[:compression_method]
      end

      def block_size
        input[:block_size]
      end

      def io_system
        input[:io_system]
      end

      def algorithm_factory
        input[:algorithm_factory]
      end

      def id
        source_path
      end
    end
  end
end
