# frozen_string_literal: true

module Cabriolet
  # Represents a file to be added to an archive
  #
  # Single responsibility: Encapsulate file metadata and data access.
  # Supports both disk files and memory data, providing unified interface
  # for file operations across all format compressors.
  #
  # @example Adding a disk file
  #   entry = FileEntry.new(
  #     source: "/path/to/file.txt",
  #     archive_path: "docs/file.txt"
  #   )
  #
  # @example Adding memory data
  #   entry = FileEntry.new(
  #     data: "Hello, World!",
  #     archive_path: "greeting.txt"
  #   )
  class FileEntry
    attr_reader :source_path, :archive_path, :data, :options

    # Initialize a file entry
    #
    # @param source [String, nil] Path to source file on disk
    # @param data [String, nil] File data in memory
    # @param archive_path [String] Path within the archive
    # @param options [Hash] Format-specific options
    # @raise [ArgumentError] if validation fails
    def initialize(archive_path:, source: nil, data: nil, **options)
      @source_path = source
      @data = data
      @archive_path = archive_path
      @options = options

      validate!
    end

    # Check if file data is from disk
    #
    # @return [Boolean] true if file is on disk
    def from_disk?
      !@source_path.nil?
    end

    # Check if file data is in memory
    #
    # @return [Boolean] true if data is in memory
    def from_memory?
      !@data.nil?
    end

    # Read file data (from disk or memory)
    #
    # @return [String] File contents
    def read_data
      return @data if from_memory?

      File.binread(@source_path)
    end

    # Get file size
    #
    # @return [Integer] File size in bytes
    def size
      return @data.bytesize if from_memory?

      File.size(@source_path)
    end

    # Get file stat (disk files only)
    #
    # @return [File::Stat, nil] File stat or nil for memory files
    def stat
      return nil if from_memory?

      File.stat(@source_path)
    end

    # Get modification time
    #
    # @return [Time] Modification time (current time for memory files)
    def mtime
      return Time.now if from_memory?

      stat&.mtime || Time.now
    end

    # Get file attributes
    #
    # @return [Integer] File attributes flags
    def attributes
      return @options[:attributes] if @options[:attributes]
      return Constants::ATTRIB_ARCH if from_memory?

      calculate_disk_attributes
    end

    # Get compression flag from options
    #
    # @return [Boolean] Whether to compress this file
    def compress?
      @options.fetch(:compress, true)
    end

    private

    # Validate entry parameters
    #
    # @raise [ArgumentError] if invalid
    def validate!
      if @source_path.nil? && @data.nil?
        raise ArgumentError,
              "Must provide either source or data"
      end

      if @source_path && @data
        raise ArgumentError,
              "Cannot provide both source and data"
      end

      if @source_path
        unless File.exist?(@source_path)
          raise ArgumentError,
                "File not found: #{@source_path}"
        end

        unless File.file?(@source_path)
          raise ArgumentError,
                "Not a file: #{@source_path}"
        end
      end

      raise ArgumentError, "Archive path required" if @archive_path.nil?
    end

    # Calculate attributes from disk file stat
    #
    # @return [Integer] Attribute flags
    def calculate_disk_attributes
      file_stat = stat
      return Constants::ATTRIB_ARCH unless file_stat

      attribs = Constants::ATTRIB_ARCH

      # Read-only flag
      attribs |= Constants::ATTRIB_READONLY unless file_stat.writable?

      # Executable flag (Unix systems)
      attribs |= Constants::ATTRIB_EXEC if file_stat.executable?

      attribs
    end
  end
end
