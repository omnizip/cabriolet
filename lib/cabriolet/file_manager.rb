# frozen_string_literal: true

require_relative "file_entry"

module Cabriolet
  # Manages collection of files for archive creation
  #
  # Single responsibility: File list management and enumeration.
  # Provides unified interface for adding files from disk or memory,
  # and supports standard Ruby enumeration patterns.
  #
  # @example Basic usage
  #   manager = FileManager.new
  #   manager.add_file("/path/to/file.txt", "docs/file.txt")
  #   manager.add_data("Hello", "greeting.txt")
  #   manager.each { |entry| puts entry.archive_path }
  class FileManager
    include Enumerable

    # Initialize empty file manager
    def initialize
      @entries = []
    end

    # Add file from disk
    #
    # @param source_path [String] Path to source file
    # @param archive_path [String, nil] Path in archive (nil = use basename)
    # @param options [Hash] Format-specific options
    # @return [FileEntry] Added entry
    # @raise [ArgumentError] if file doesn't exist
    def add_file(source_path, archive_path = nil, **options)
      archive_path ||= File.basename(source_path)

      entry = FileEntry.new(
        source: source_path,
        archive_path: archive_path,
        **options,
      )

      @entries << entry
      entry
    end

    # Add file from memory
    #
    # @param data [String] File data
    # @param archive_path [String] Path in archive
    # @param options [Hash] Format-specific options
    # @return [FileEntry] Added entry
    def add_data(data, archive_path, **options)
      entry = FileEntry.new(
        data: data,
        archive_path: archive_path,
        **options,
      )

      @entries << entry
      entry
    end

    # Enumerate entries (Enumerable interface)
    #
    # @yield [FileEntry] Each file entry
    def each(&)
      @entries.each(&)
    end

    # Check if empty
    #
    # @return [Boolean] true if no files added
    def empty?
      @entries.empty?
    end

    # Get count of entries
    #
    # @return [Integer] Number of entries
    def size
      @entries.size
    end
    alias count size

    # Get entry by index
    #
    # @param index [Integer] Entry index
    # @return [FileEntry, nil] Entry or nil if out of bounds
    def [](index)
      @entries[index]
    end

    # Get all entries
    #
    # @return [Array<FileEntry>] Copy of entries array
    def all
      @entries.dup
    end

    # Clear all entries
    #
    # @return [self]
    def clear
      @entries.clear
      self
    end

    # Calculate total size of all files
    #
    # @return [Integer] Total size in bytes
    def total_size
      @entries.sum(&:size)
    end

    # Get files from disk
    #
    # @return [Array<FileEntry>] Disk-based entries
    def disk_files
      @entries.select(&:from_disk?)
    end

    # Get files from memory
    #
    # @return [Array<FileEntry>] Memory-based entries
    def memory_files
      @entries.select(&:from_memory?)
    end

    # Find entry by archive path
    #
    # @param path [String] Archive path to find
    # @return [FileEntry, nil] Entry or nil if not found
    def find_by_path(path)
      @entries.find { |entry| entry.archive_path == path }
    end

    # Check if archive path exists
    #
    # @param path [String] Archive path to check
    # @return [Boolean] true if path exists
    def path_exists?(path)
      !find_by_path(path).nil?
    end
  end
end
