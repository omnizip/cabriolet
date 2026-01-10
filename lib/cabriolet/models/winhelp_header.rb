# frozen_string_literal: true

module Cabriolet
  module Models
    # Windows Help (WinHelp) file header model
    #
    # Represents the metadata of a Windows Help file (WinHelp 3.x or 4.x).
    # WinHelp files contain an internal file system with |SYSTEM, |TOPIC,
    # and other internal files.
    class WinHelpHeader
      attr_accessor :version       # :winhelp3 or :winhelp4
      attr_accessor :magic         # Magic number (0x35F3 or 0x3F5F0000)
      attr_accessor :directory_offset
      attr_accessor :free_list_offset
      attr_accessor :file_size
      attr_accessor :filename

      # Internal files in the help file
      # Array of hashes: { filename:, file_size:, starting_block: }
      attr_accessor :internal_files

      # Parsed |SYSTEM file data (if extracted)
      attr_accessor :system_data

      # Initialize WinHelp header
      #
      # @param version [Symbol] :winhelp3 or :winhelp4
      # @param magic [Integer] Magic number
      # @param directory_offset [Integer] Offset to internal file directory
      # @param free_list_offset [Integer] Offset to free list
      # @param file_size [Integer] Total file size
      # @param filename [String, nil] Original filename
      def initialize(
        version: :winhelp3,
        magic: 0,
        directory_offset: 0,
        free_list_offset: 0,
        file_size: 0,
        filename: nil
      )
        @version = version
        @magic = magic
        @directory_offset = directory_offset
        @free_list_offset = free_list_offset
        @file_size = file_size
        @filename = filename

        @internal_files = []
        @system_data = nil
      end

      # Check if header is valid
      #
      # @return [Boolean] true if header appears valid
      def valid?
        case @version
        when :winhelp3
          @magic == 0x35F3
        when :winhelp4
          (@magic & 0xFFFF) == 0x3F5F
        else
          false
        end
      end

      # Check if this is WinHelp 3.x format
      #
      # @return [Boolean] true if WinHelp 3.x
      def winhelp3?
        @version == :winhelp3
      end

      # Check if this is WinHelp 4.x format
      #
      # @return [Boolean] true if WinHelp 4.x
      def winhelp4?
        @version == :winhelp4
      end

      # Get list of internal filenames
      #
      # @return [Array<String>] Internal file names
      def internal_filenames
        @internal_files.map { |f| f[:filename] }
      end

      # Find internal file by name
      #
      # @param name [String] Internal filename (e.g., "|SYSTEM")
      # @return [Hash, nil] File entry or nil if not found
      def find_file(name)
        @internal_files.find { |f| f[:filename] == name }
      end

      # Check if |SYSTEM file exists
      #
      # @return [Boolean] true if |SYSTEM file present
      def has_system_file?
        !find_file("|SYSTEM").nil?
      end

      # Check if |TOPIC file exists
      #
      # @return [Boolean] true if |TOPIC file present
      def has_topic_file?
        !find_file("|TOPIC").nil?
      end

      # Get version string
      #
      # @return [String] Human-readable version
      def version_string
        case @version
        when :winhelp3
          "Windows Help 3.x (16-bit)"
        when :winhelp4
          "Windows Help 4.x (32-bit)"
        else
          "Unknown"
        end
      end

      # Get magic number as hex string
      #
      # @return [String] Hex representation of magic
      def magic_hex
        "0x#{@magic.to_s(16).upcase}"
      end
    end
  end
end
