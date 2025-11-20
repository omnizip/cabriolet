# frozen_string_literal: true

module Cabriolet
  module System
    # MemoryHandle provides in-memory I/O operations using a StringIO-like interface
    class MemoryHandle
      attr_reader :data, :mode

      # Initialize a new memory handle
      #
      # @param data [String] Initial data (for reading) or empty string (for writing)
      # @param mode [Integer] One of MODE_READ, MODE_WRITE, MODE_UPDATE, MODE_APPEND
      def initialize(data = "", mode = Constants::MODE_READ)
        @data = data.dup.force_encoding(Encoding::BINARY)
        @mode = mode
        @pos = mode == Constants::MODE_APPEND ? @data.bytesize : 0
        @closed = false
      end

      # Read bytes from memory
      #
      # @param bytes [Integer, nil] Number of bytes to read (nil = read all remaining)
      # @return [String] Bytes read (binary encoding)
      def read(bytes = nil)
        return "" if @pos >= @data.bytesize

        if bytes.nil?
          # Read all remaining data
          result = @data.byteslice(@pos..-1) || ""
          @pos = @data.bytesize
        else
          result = @data.byteslice(@pos, bytes) || ""
          @pos += result.bytesize
        end
        result
      end

      # Write bytes to memory
      #
      # @param content [String] Data to write
      # @return [Integer] Number of bytes written
      def write(content)
        raise IOError, "Handle is closed" if @closed
        raise IOError, "Handle not opened for writing" if @mode == Constants::MODE_READ

        content = content.dup.force_encoding(Encoding::BINARY)

        if @pos >= @data.bytesize
          # Append to end
          @data << content
        else
          # Overwrite existing data
          before = @data.byteslice(0, @pos) || ""
          after = @data.byteslice((@pos + content.bytesize)..-1) || ""
          @data = before + content + after
        end

        @pos += content.bytesize
        content.bytesize
      end

      # Seek to a position in memory
      #
      # @param offset [Integer] Offset to seek to
      # @param whence [Integer] One of SEEK_START, SEEK_CUR, SEEK_END
      # @return [Integer] New position
      def seek(offset, whence)
        new_pos = case whence
                  when Constants::SEEK_START then offset
                  when Constants::SEEK_CUR then @pos + offset
                  when Constants::SEEK_END then @data.bytesize + offset
                  else
                    raise ArgumentError, "Invalid whence value: #{whence}"
                  end

        @pos = [[new_pos, 0].max, @data.bytesize].min
      end

      # Get current position in memory
      #
      # @return [Integer] Current position
      def tell
        @pos
      end

      # Rewind to the beginning of the handle
      #
      # @return [Integer] New position (0)
      def rewind
        @pos = 0
      end

      # Close the handle
      #
      # @return [void]
      def close
        @closed = true
      end

      # Check if the handle is closed
      #
      # @return [Boolean]
      def closed?
        @closed
      end

      # Get the complete data buffer
      #
      # @return [String] All data in the buffer
      def to_s
        @data
      end

      # Alias for to_s
      alias buffer to_s
    end
  end
end
