# frozen_string_literal: true

require_relative "chm_section"

module Cabriolet
  module Models
    # Represents a CHM file header and metadata
    class CHMHeader
      attr_accessor :filename, :version, :timestamp, :language, :length, :files, :sysfiles, :sec0, :sec1, :dir_offset,
                    :num_chunks, :chunk_size, :density, :depth, :index_root, :first_pmgl, :last_pmgl, :chunk_cache

      def initialize
        @filename = nil
        @version = 0
        @timestamp = 0
        @language = 0
        @length = 0
        @files = nil
        @sysfiles = nil
        @sec0 = CHMSecUncompressed.new(self)
        @sec1 = CHMSecMSCompressed.new(self)
        @dir_offset = 0
        @num_chunks = 0
        @chunk_size = 0
        @density = 0
        @depth = 0
        @index_root = 0
        @first_pmgl = 0
        @last_pmgl = 0
        @chunk_cache = nil
      end

      # Get all files as an array
      def all_files
        result = []
        file = files
        while file
          result << file
          file = file.next_file
        end
        result
      end

      # Get all system files as an array
      def all_sysfiles
        result = []
        file = sysfiles
        while file
          result << file
          file = file.next_file
        end
        result
      end

      # Find a file by name
      def find_file(filename)
        file = files
        while file
          return file if file.filename == filename

          file = file.next_file
        end
        nil
      end
    end
  end
end
