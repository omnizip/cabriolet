# frozen_string_literal: true

require_relative "folder_data"

module Cabriolet
  module Models
    # Folder represents a compressed data stream within a cabinet
    class Folder
      attr_accessor :comp_type, :num_blocks, :data, :next_folder, :merge_prev,
                    :merge_next

      # Initialize a new folder
      #
      # @param cabinet [Cabinet, nil] Cabinet containing this folder
      # @param offset [Integer] Data offset within cabinet
      def initialize(cabinet = nil, offset = 0)
        @comp_type = Constants::COMP_TYPE_NONE
        @num_blocks = 0
        @data = FolderData.new(cabinet, offset)
        @next_folder = nil
        @merge_prev = nil
        @merge_next = nil
      end

      # Get the primary data cabinet (for backwards compatibility)
      #
      # @return [Cabinet, nil]
      def data_cab
        @data.cabinet
      end

      # Set the primary data cabinet (for backwards compatibility)
      #
      # @param cabinet [Cabinet]
      def data_cab=(cabinet)
        @data.cabinet = cabinet
      end

      # Get the primary data offset (for backwards compatibility)
      #
      # @return [Integer]
      def data_offset
        @data.offset
      end

      # Set the primary data offset (for backwards compatibility)
      #
      # @param offset [Integer]
      def data_offset=(offset)
        @data.offset = offset
      end

      # Get the compression method
      #
      # @return [Integer] One of COMP_TYPE_* constants
      def compression_method
        @comp_type & Constants::COMP_TYPE_MASK
      end

      # Get the compression level (for LZX and Quantum)
      #
      # @return [Integer] Compression level
      def compression_level
        (@comp_type >> 8) & 0x1F
      end

      # Get human-readable compression name
      #
      # @return [String] Name of compression method
      def compression_name
        case compression_method
        when Constants::COMP_TYPE_NONE then "None"
        when Constants::COMP_TYPE_MSZIP then "MSZIP"
        when Constants::COMP_TYPE_QUANTUM then "Quantum"
        when Constants::COMP_TYPE_LZX then "LZX"
        else "Unknown"
        end
      end

      # Check if this folder is uncompressed
      #
      # @return [Boolean]
      def uncompressed?
        compression_method == Constants::COMP_TYPE_NONE
      end

      # Check if this folder needs to be merged with a previous folder
      #
      # @return [Boolean]
      def needs_prev_merge?
        !@merge_prev.nil?
      end

      # Check if this folder needs to be merged with a next folder
      #
      # @return [Boolean]
      def needs_next_merge?
        !@merge_next.nil?
      end
    end
  end
end
