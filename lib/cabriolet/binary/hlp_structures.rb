# frozen_string_literal: true

require "bindata"

module Cabriolet
  module Binary
    # HLP (Windows Help / QuickHelp) file format binary structures
    #
    # Based on the QuickHelp binary format specification from DosHelp project.
    # HLP files store help databases with topics, compression, and hyperlinks.
    #
    # Format overview:
    # - Signature (2 bytes): 0x4C 0x4E ("LN")
    # - File Header (68 bytes)
    # - Topic Index (variable)
    # - Context Strings (variable)
    # - Context Map (variable)
    # - Keywords (optional, variable)
    # - Huffman Tree (optional, variable)
    # - Topic Texts (variable, compressed)
    module HLPStructures
      # QuickHelp file signature: 0x4C, 0x4E ("LN")
      SIGNATURE = "\x4C\x4E".b.freeze unless defined?(SIGNATURE)

      # File attributes flags
      module Attributes
        CASE_SENSITIVE = 0x01 unless defined?(CASE_SENSITIVE)
        LOCKED = 0x02 unless defined?(LOCKED)
      end

      # Control bytes for keyword compression
      module ControlBytes
        # Dictionary entry with optional space (0x10-0x17)
        DICT_ENTRY_MIN = 0x10 unless defined?(DICT_ENTRY_MIN)
        DICT_ENTRY_MAX = 0x17 unless defined?(DICT_ENTRY_MAX)

        # Run of spaces (0x18)
        SPACE_RUN = 0x18 unless defined?(SPACE_RUN)

        # Run of bytes (0x19)
        BYTE_RUN = 0x19 unless defined?(BYTE_RUN)

        # Escape byte (0x1A)
        ESCAPE = 0x1A unless defined?(ESCAPE)
      end

      # Text style flags for topic lines
      module TextStyle
        NONE = 0x00 unless defined?(NONE)
        BOLD = 0x01 unless defined?(BOLD)
        ITALIC = 0x02 unless defined?(ITALIC)
        UNDERLINE = 0x04 unless defined?(UNDERLINE)
      end

      # QuickHelp file header (70 bytes total: 2 byte signature + 68 byte header)
      #
      # Structure:
      # - 2 bytes: signature (0x4C 0x4E)
      # - 2 bytes: version (always 2)
      # - 2 bytes: attributes (bit flags)
      # - 1 byte: control character (usually ':' or 0xFF)
      # - 1 byte: padding
      # - 2 bytes: topic count
      # - 2 bytes: context count
      # - 1 byte: display width
      # - 1 byte: padding
      # - 2 bytes: predefined context count
      # - 14 bytes: database name (null-terminated, null-padded)
      # - 4 bytes: reserved
      # - 4 bytes: topic index offset
      # - 4 bytes: context strings offset
      # - 4 bytes: context map offset
      # - 4 bytes: keywords offset (0 if not used)
      # - 4 bytes: huffman tree offset (0 if not used)
      # - 4 bytes: topic text offset
      # - 4 bytes: reserved
      # - 4 bytes: reserved
      # - 4 bytes: database size
      class FileHeader < BinData::Record
        endian :little

        string :signature, length: 2
        uint16 :version
        uint16 :attributes
        uint8  :control_character
        uint8  :padding1
        uint16 :topic_count
        uint16 :context_count
        uint8  :display_width
        uint8  :padding2
        uint16 :predefined_ctx_count
        string :database_name, length: 14
        uint32 :reserved1
        uint32 :topic_index_offset
        uint32 :context_strings_offset
        uint32 :context_map_offset
        uint32 :keywords_offset
        uint32 :huffman_tree_offset
        uint32 :topic_text_offset
        uint32 :reserved2
        uint32 :reserved3
        uint32 :database_size
      end

      # Topic index entry (4 bytes per topic)
      #
      # Array of (topic_count + 1) DWORDs that specify offsets of topic texts.
      # The last entry indicates the end of the last topic.
      class TopicOffset < BinData::Record
        endian :little
        uint32 :offset
      end

      # Context map entry (2 bytes per context)
      #
      # Maps context strings to topic indices.
      class ContextMapEntry < BinData::Record
        endian :little
        uint16 :topic_index
      end

      # Huffman tree node (2 bytes per node)
      #
      # Leaf node: bit 15 set, bits 0-7 contain symbol
      # Internal node: bit 15 clear, node_value/2 is left child index, i+1 is right child
      class HuffmanNode < BinData::Record
        endian :little
        int16 :node_value

        # Check if this is a leaf node
        def leaf?
          node_value < 0
        end

        # Get symbol for leaf node
        def symbol
          return nil unless leaf?
          node_value & 0xFF
        end

        # Get left child index for internal node
        def left_child_index
          return nil if leaf?
          node_value / 2
        end
      end

      # Topic compressed header (2 bytes)
      #
      # Appears at the start of each compressed topic text.
      class TopicHeader < BinData::Record
        endian :little
        uint16 :decompressed_length
      end

      # Windows Help (WinHelp) 3.x file header (28 bytes)
      #
      # Structure:
      # - 2 bytes: Magic number (0x35F3)
      # - 2 bytes: Unknown/version
      # - 4 bytes: Directory offset
      # - 4 bytes: Free list offset
      # - 4 bytes: File size
      # - 12 bytes: Reserved/padding
      class WinHelp3Header < BinData::Record
        endian :little

        uint16 :magic           # 0x35F3
        uint16 :unknown
        uint32 :directory_offset
        uint32 :free_list_offset
        uint32 :file_size
        string :reserved, length: 12
      end

      # Windows Help (WinHelp) 4.x file header (32 bytes)
      #
      # Structure:
      # - 4 bytes: Magic number (0x3F5F0000 or similar)
      # - 4 bytes: Directory offset
      # - 4 bytes: Free list offset
      # - 4 bytes: File size
      # - 16 bytes: Reserved/unknown
      class WinHelp4Header < BinData::Record
        endian :little

        uint32 :magic           # 0x3F5F0000 or similar
        uint32 :directory_offset
        uint32 :free_list_offset
        uint32 :file_size
        string :reserved, length: 16
      end

      # WinHelp internal file directory entry
      #
      # Variable size structure:
      # - 4 bytes: File size
      # - 2 bytes: Starting block number
      # - Variable: File name (null-terminated, aligned)
      class WinHelpDirectoryEntry < BinData::Record
        endian :little

        uint32 :file_size
        uint16 :starting_block
        stringz :filename
      end
    end
  end
end
