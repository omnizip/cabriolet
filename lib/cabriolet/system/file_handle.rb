# frozen_string_literal: true

module Cabriolet
  module System
    # FileHandle provides file I/O operations using the Ruby File class
    class FileHandle
      attr_reader :filename, :mode

      # Initialize a new file handle
      #
      # @param filename [String] Path to the file
      # @param mode [Integer] One of MODE_READ, MODE_WRITE, MODE_UPDATE, MODE_APPEND
      # @raise [IOError] if the file cannot be opened
      def initialize(filename, mode)
        @filename = filename
        @mode = mode
        @file = open_file(mode)
      end

      # Read bytes from the file
      #
      # @param bytes [Integer] Number of bytes to read
      # @return [String] Bytes read (binary encoding)
      def read(bytes)
        @file.read(bytes) || ""
      end

      # Write bytes to the file
      #
      # @param data [String] Data to write
      # @return [Integer] Number of bytes written
      def write(data)
        @file.write(data)
      end

      # Seek to a position in the file
      #
      # @param offset [Integer] Offset to seek to
      # @param whence [Integer] One of SEEK_START, SEEK_CUR, SEEK_END
      # @return [Integer] New position
      def seek(offset, whence)
        io_whence = case whence
                    when Constants::SEEK_START then ::IO::SEEK_SET
                    when Constants::SEEK_CUR then ::IO::SEEK_CUR
                    when Constants::SEEK_END then ::IO::SEEK_END
                    else
                      raise ArgumentError, "Invalid whence value: #{whence}"
                    end
        @file.seek(offset, io_whence)
        @file.pos
      end

      # Get current position in the file
      #
      # @return [Integer] Current position
      def tell
        @file.pos
      end

      # Get the size of the file
      #
      # @return [Integer] File size in bytes
      def size
        @file.size
      end

      # Flush the file buffer
      #
      # @return [void]
      def flush
        @file.flush unless @file.closed?
      end

      # Close the file
      #
      # @return [void]
      def close
        @file.flush unless @file.closed?
        @file.close unless @file.closed?
      end

      # Check if the file is closed
      #
      # @return [Boolean]
      def closed?
        @file.closed?
      end

      private

      def open_file(mode)
        file_mode = case mode
                    when Constants::MODE_READ then "rb"
                    when Constants::MODE_WRITE then "wb"
                    when Constants::MODE_UPDATE then "r+b"
                    when Constants::MODE_APPEND then "ab"
                    else
                      raise ArgumentError, "Invalid mode: #{mode}"
                    end

        ::File.open(@filename, file_mode)
      rescue Errno::ENOENT, Errno::EACCES => e
        raise IOError, "Cannot open file #{@filename}: #{e.message}"
      end
    end
  end
end
