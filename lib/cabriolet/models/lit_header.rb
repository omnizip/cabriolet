# frozen_string_literal: true

module Cabriolet
  module Models
    # Represents a Microsoft Reader LIT file structure
    #
    # LIT files have a complex structure with:
    # - Primary and secondary headers
    # - Piece table pointing to various data structures
    # - Internal directory with IFCM/AOLL/AOLI chunks
    # - DataSpace sections with transformation layers (compression/encryption)
    # - Manifest mapping internal to original filenames
    class LITFile
      attr_accessor :version, :header_guid, :piece3_guid, :piece4_guid,
                    :content_offset, :timestamp, :language_id, :creator_id,
                    :entry_chunklen, :count_chunklen, :entry_unknown,
                    :count_unknown, :drm_level, :sections, :directory, :manifest

      def initialize
        @version = 0
        @header_guid = ""
        @piece3_guid = ""
        @piece4_guid = ""
        @content_offset = 0
        @timestamp = 0
        @language_id = 0
        @creator_id = 0
        @entry_chunklen = 0
        @count_chunklen = 0
        @entry_unknown = 0
        @count_unknown = 0
        @drm_level = 0
        @sections = []
        @directory = nil
        @manifest = nil
      end

      # Check if the LIT file has DRM encryption
      #
      # @return [Boolean] true if DRM is present
      def encrypted?
        drm_level.positive?
      end

      # Get section by name
      #
      # @param name [String] Section name
      # @return [LITSection, nil] The section or nil if not found
      def section(name)
        sections.find { |s| s.name == name }
      end
    end

    # Represents a section within the LIT file
    #
    # Sections contain compressed/encrypted data with transform layers
    class LITSection
      attr_accessor :name, :transforms, :compressed, :encrypted,
                    :uncompressed_length, :compressed_length,
                    :window_size, :reset_interval, :reset_table

      def initialize
        @name = ""
        @transforms = []
        @compressed = false
        @encrypted = false
        @uncompressed_length = 0
        @compressed_length = 0
        @window_size = 0
        @reset_interval = 0
        @reset_table = []
      end

      # Check if section is compressed
      #
      # @return [Boolean] true if compressed
      def compressed?
        compressed
      end

      # Check if section is encrypted
      #
      # @return [Boolean] true if encrypted
      def encrypted?
        encrypted
      end
    end

    # Represents the internal directory structure
    #
    # Directory contains file entries with encoded integers for efficiency
    class LITDirectory
      attr_accessor :entries, :num_chunks, :entry_chunklen, :count_chunklen

      def initialize
        @entries = []
        @num_chunks = 0
        @entry_chunklen = 0
        @count_chunklen = 0
      end

      # Find entry by name
      #
      # @param name [String] Entry name
      # @return [LITDirectoryEntry, nil] The entry or nil if not found
      def find(name)
        entries.find { |e| e.name == name }
      end

      # Get all entries in a section
      #
      # @param section_id [Integer] Section ID
      # @return [Array<LITDirectoryEntry>] Entries in the section
      def entries_in_section(section_id)
        entries.select { |e| e.section == section_id }
      end
    end

    # Represents a single directory entry
    #
    # Entries use variable-length encoded integers to save space
    class LITDirectoryEntry
      attr_accessor :name, :section, :offset, :size

      def initialize
        @name = ""
        @section = 0
        @offset = 0
        @size = 0
      end

      # Check if this is a root entry
      #
      # @return [Boolean] true if root entry
      def root?
        name == "/" || name == ""
      end

      # Get the directory portion of the name
      #
      # @return [String] Directory path
      def directory
        return "/" if root?

        parts = name.split("/")
        parts[0..-2].join("/")
      end

      # Get the filename portion
      #
      # @return [String] Filename
      def filename
        return "" if root?

        name.split("/").last
      end
    end

    # Represents the manifest file
    #
    # Maps internal filenames to original filenames and content types
    class LITManifest
      attr_accessor :mappings

      def initialize
        @mappings = []
      end

      # Find mapping by internal name
      #
      # @param internal_name [String] Internal filename
      # @return [LITManifestMapping, nil] The mapping or nil
      def find_by_internal(internal_name)
        mappings.find { |m| m.internal_name == internal_name }
      end

      # Find mapping by original name
      #
      # @param original_name [String] Original filename
      # @return [LITManifestMapping, nil] The mapping or nil
      def find_by_original(original_name)
        mappings.find { |m| m.original_name == original_name }
      end

      # Get all HTML files
      #
      # @return [Array<LITManifestMapping>] HTML file mappings
      def html_files
        mappings.select { |m| m.content_type =~ /html/i }
      end

      # Get all CSS files
      #
      # @return [Array<LITManifestMapping>] CSS file mappings
      def css_files
        mappings.select { |m| m.content_type =~ /css/i }
      end

      # Get all image files
      #
      # @return [Array<LITManifestMapping>] Image file mappings
      def image_files
        mappings.select { |m| m.content_type =~ /image/i }
      end
    end

    # Represents a single manifest mapping
    class LITManifestMapping
      attr_accessor :offset, :internal_name, :original_name, :content_type, :group

      def initialize
        @offset = 0
        @internal_name = ""
        @original_name = ""
        @content_type = ""
        @group = 0
      end

      # Check if this is an HTML file
      #
      # @return [Boolean] true if HTML
      def html?
        content_type =~ /html/i
      end

      # Check if this is a CSS file
      #
      # @return [Boolean] true if CSS
      def css?
        content_type =~ /css/i
      end

      # Check if this is an image
      #
      # @return [Boolean] true if image
      def image?
        content_type =~ /image/i
      end
    end
  end
end
