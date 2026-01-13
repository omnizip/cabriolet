# frozen_string_literal: true

require_relative "file_handle"
require_relative "memory_handle"

module Cabriolet
  module System
    # IOSystem provides an abstraction layer for file I/O operations,
    # enabling dependency injection and custom I/O implementations.
    #
    # This allows for:
    # - Testing with mock I/O
    # - In-memory operations
    # - Custom I/O sources (network, etc.)
    class IOSystem
      # Open a file for reading, writing, or updating
      #
      # @param filename [String] Path to the file
      # @param mode [Integer] One of MODE_READ, MODE_WRITE, MODE_UPDATE, MODE_APPEND
      # @return [FileHandle] Handle for performing I/O operations
      # @raise [IOError] if the file cannot be opened
      def open(filename, mode)
        FileHandle.new(filename, mode)
      end

      # Close a file handle
      #
      # @param handle [FileHandle, MemoryHandle] Handle to close
      # @return [void]
      def close(handle)
        handle.close
      end

      # Read bytes from a handle
      #
      # @param handle [FileHandle, MemoryHandle] Handle to read from
      # @param bytes [Integer] Number of bytes to read
      # @return [String] Bytes read (may be fewer than requested at EOF)
      def read(handle, bytes)
        handle.read(bytes)
      end

      # Write bytes to a handle
      #
      # @param handle [FileHandle, MemoryHandle] Handle to write to
      # @param data [String] Data to write
      # @return [Integer] Number of bytes written
      def write(handle, data)
        handle.write(data)
      end

      # Seek to a position in a handle
      #
      # @param handle [FileHandle, MemoryHandle] Handle to seek in
      # @param offset [Integer] Offset to seek to
      # @param whence [Integer] One of SEEK_START, SEEK_CUR, SEEK_END
      # @return [Integer] New position
      def seek(handle, offset, whence)
        handle.seek(offset, whence)
      end

      # Get current position in a handle
      #
      # @param handle [FileHandle, MemoryHandle] Handle to query
      # @return [Integer] Current position
      def tell(handle)
        handle.tell
      end

      # Copy bytes from source to destination
      #
      # @param src [String] Source bytes
      # @param dest [String] Destination buffer
      # @param bytes [Integer] Number of bytes to copy
      # @return [void]
      def copy(src, dest, bytes)
        dest.replace(src.byteslice(0, bytes))
      end

      # Output a message (for debugging/logging)
      #
      # @param handle [FileHandle, MemoryHandle, nil] Handle associated with message
      # @param message [String] Message to output
      # @return [void]
      def message(_handle, message)
        warn "[Cabriolet] #{message}" if Cabriolet.verbose
      end
    end
  end
end
