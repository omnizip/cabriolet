# frozen_string_literal: true

module Cabriolet
  module Models
    # Cabinet represents a CAB file or cabinet set
    class Cabinet
      attr_accessor :filename, :base_offset, :length, :set_id, :set_index, :flags, :header_resv, :prevname, :nextname,
                    :previnfo, :nextinfo, :folders, :files, :next_cabinet, :prev_cabinet, :next
      attr_reader :blocks_offset, :block_resv

      # Initialize a new cabinet
      #
      # @param filename [String] Path to the cabinet file
      def initialize(filename = nil)
        @filename = filename
        @base_offset = 0
        @length = 0
        @set_id = 0
        @set_index = 0
        @flags = 0
        @header_resv = 0
        @prevname = nil
        @nextname = nil
        @previnfo = nil
        @nextinfo = nil
        @folders = []
        @files = []
        @next_cabinet = nil
        @prev_cabinet = nil
        @next = nil
        @blocks_offset = 0
        @block_resv = 0
      end

      # Check if this cabinet has a predecessor
      #
      # @return [Boolean]
      def has_prev?
        @flags.anybits?(Constants::FLAG_PREV_CABINET)
      end

      # Check if this cabinet has a successor
      #
      # @return [Boolean]
      def has_next?
        @flags.anybits?(Constants::FLAG_NEXT_CABINET)
      end

      # Check if this cabinet has reserved space
      #
      # @return [Boolean]
      def has_reserve?
        @flags.anybits?(Constants::FLAG_RESERVE_PRESENT)
      end

      # Set the blocks offset and reserved space
      #
      # @param offset [Integer] Offset to data blocks
      # @param resv [Integer] Reserved bytes per block
      # @return [void]
      def set_blocks_info(offset, resv)
        @blocks_offset = offset
        @block_resv = resv
      end

      # Get total number of files
      #
      # @return [Integer]
      def file_count
        @files.size
      end

      # Get total number of folders
      #
      # @return [Integer]
      def folder_count
        @folders.size
      end
    end
  end
end
