# frozen_string_literal: true

module Cabriolet
  module CAB
    # Worker for compressing files in a CAB archive
    class FileCompressionWorker < Fractor::Worker
      # Process a file compression work item
      #
      # @param work [FileCompressionWork] Work item to process
      # @return [Fractor::WorkResult] Result with compressed blocks
      def process(work)
        # Read source file
        file_data = ::File.binread(work.source_path)
        file_size = file_data.bytesize

        # Split into blocks and compress
        blocks = []
        offset = 0

        while offset < file_size
          remaining = file_size - offset
          chunk_size = [work.block_size, remaining].min
          chunk = file_data[offset, chunk_size]

          # Compress chunk
          compressed_chunk = compress_chunk(chunk, work)

          blocks << {
            uncompressed_size: chunk.bytesize,
            compressed_size: compressed_chunk.bytesize,
            data: compressed_chunk,
          }

          offset += chunk_size
        end

        # Return success result
        Fractor::WorkResult.new(
          result: {
            source_path: work.source_path,
            blocks: blocks,
            total_uncompressed: file_size,
            total_compressed: blocks.sum { |b| b[:compressed_size] },
          },
          work: work,
        )
      rescue StandardError => e
        # Return error result
        Fractor::WorkResult.new(
          error: {
            message: e.message,
            class: e.class.name,
            source_path: work.source_path,
          },
          work: work,
        )
      end

      private

      # Compress a single chunk of data
      #
      # @param chunk [String] Data chunk to compress
      # @param work [FileCompressionWork] Work item with compression settings
      # @return [String] Compressed data
      def compress_chunk(chunk, work)
        input_handle = System::MemoryHandle.new(chunk)
        output_handle = System::MemoryHandle.new("", Constants::MODE_WRITE)

        begin
          compressor = work.algorithm_factory.create(
            work.compression_method,
            :compressor,
            work.io_system,
            input_handle,
            output_handle,
            chunk.bytesize,
          )

          compressor.compress

          output_handle.data

          # Memory handles don't need closing
        end
      end
    end
  end
end
