# frozen_string_literal: true

module Cabriolet
  module Models
    # FolderData represents a data location span for a folder
    # Folders may span multiple cabinets, so they have a chain of FolderData
    class FolderData
      attr_accessor :next_data, :cabinet, :offset

      # Initialize a new FolderData
      #
      # @param cabinet [Cabinet] Cabinet containing this data
      # @param offset [Integer] Offset within cabinet file to data blocks
      def initialize(cabinet, offset)
        @cabinet = cabinet
        @offset = offset
        @next_data = nil
      end
    end
  end
end
