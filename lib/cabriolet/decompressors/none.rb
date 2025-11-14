# frozen_string_literal: true

module Cabriolet
  module Decompressors
    # None handles uncompressed data (no compression)
    class None < Base
      # Decompress (copy) the specified number of bytes
      #
      # @param bytes [Integer] Number of bytes to copy
      # @return [Integer] Number of bytes copied
      def decompress(bytes)
        total_copied = 0

        while total_copied < bytes
          chunk_size = [bytes - total_copied, @buffer_size].min
          data = @io_system.read(@input, chunk_size)
          break if data.empty?

          @io_system.write(@output, data)
          total_copied += data.bytesize
        end

        total_copied
      end
    end
  end
end
