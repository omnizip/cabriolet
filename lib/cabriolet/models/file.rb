# frozen_string_literal: true

require "time"

module Cabriolet
  module Models
    # File represents a file within a cabinet
    class File
      attr_accessor :filename, :length, :offset, :folder, :folder_index, :attribs, :time_h, :time_m, :time_s, :date_d,
                    :date_m, :date_y, :next_file

      # Initialize a new file
      def initialize
        @filename = nil
        @length = 0
        @offset = 0
        @folder = nil
        @folder_index = 0
        @attribs = 0
        @time_h = 0
        @time_m = 0
        @time_s = 0
        @date_d = 1
        @date_m = 1
        @date_y = 1980
        @next_file = nil
      end

      # Parse date and time from CAB format
      #
      # @param date_bits [Integer] 16-bit date value
      # @param time_bits [Integer] 16-bit time value
      # @return [void]
      def parse_datetime(date_bits, time_bits)
        @time_h = (time_bits >> 11) & 0x1F
        @time_m = (time_bits >> 5) & 0x3F
        @time_s = (time_bits & 0x1F) << 1

        @date_d = date_bits & 0x1F
        @date_m = (date_bits >> 5) & 0x0F
        @date_y = ((date_bits >> 9) & 0x7F) + 1980
      end

      # Get the file's modification time as a Time object
      #
      # @return [Time, nil] Modification time or nil if invalid
      def modification_time
        Time.new(@date_y, @date_m, @date_d, @time_h, @time_m, @time_s)
      rescue ::ArgumentError
        nil
      end

      # Check if filename is UTF-8 encoded
      #
      # @return [Boolean]
      def utf8_filename?
        @attribs.anybits?(Constants::ATTRIB_UTF_NAME)
      end

      # Check if file is read-only
      #
      # @return [Boolean]
      def readonly?
        @attribs.anybits?(Constants::ATTRIB_READONLY)
      end

      # Check if file is hidden
      #
      # @return [Boolean]
      def hidden?
        @attribs.anybits?(Constants::ATTRIB_HIDDEN)
      end

      # Check if file is a system file
      #
      # @return [Boolean]
      def system?
        @attribs.anybits?(Constants::ATTRIB_SYSTEM)
      end

      # Check if file is archived
      #
      # @return [Boolean]
      def archived?
        @attribs.anybits?(Constants::ATTRIB_ARCH)
      end

      # Check if file is executable
      #
      # @return [Boolean]
      def executable?
        @attribs.anybits?(Constants::ATTRIB_EXEC)
      end

      # Check if this file is continued from a previous cabinet
      #
      # @return [Boolean]
      def continued_from_prev?
        @folder_index == Constants::FOLDER_CONTINUED_FROM_PREV ||
          @folder_index == Constants::FOLDER_CONTINUED_PREV_AND_NEXT
      end

      # Check if this file is continued to a next cabinet
      #
      # @return [Boolean]
      def continued_to_next?
        @folder_index == Constants::FOLDER_CONTINUED_TO_NEXT ||
          @folder_index == Constants::FOLDER_CONTINUED_PREV_AND_NEXT
      end

      # Get a human-readable representation of the file
      #
      # @return [String]
      def to_s
        "#{@filename} (#{@length} bytes)"
      end
    end
  end
end
