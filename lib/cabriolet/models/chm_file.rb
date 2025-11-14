# frozen_string_literal: true

module Cabriolet
  module Models
    # Represents a file within a CHM archive
    class CHMFile
      attr_accessor :next_file, :section, :offset, :length, :filename

      def initialize
        @next_file = nil
        @section = nil
        @offset = 0
        @length = 0
        @filename = ""
      end

      # Check if this is a system file (starts with ::)
      def system_file?
        filename.start_with?("::")
      end

      # Check if this is an empty file
      def empty?
        length.zero?
      end
    end
  end
end
