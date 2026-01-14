# frozen_string_literal: true

module Cabriolet
  module Models
    # QuickHelp database header model
    #
    # Represents the metadata of a QuickHelp help database (.HLP file).
    # HLP files contain topics, context strings, and optional compression
    # (keyword dictionary and Huffman coding).
    class HLPHeader
      attr_accessor :magic, :version, :attributes, :control_character,
                    :topic_count, :context_count, :display_width, :predefined_ctx_count, :database_name, :topic_index_offset, :context_strings_offset, :context_map_offset, :keywords_offset, :huffman_tree_offset, :topic_text_offset, :database_size, :filename, :keywords, :huffman_tree

      # Topics and context data
      attr_accessor :topics, :contexts, :context_map

      # Initialize QuickHelp database header
      #
      # @param magic [String] Magic number (should be 0x4C 0x4E)
      # @param version [Integer] Format version (should be 2)
      # @param attributes [Integer] Attribute flags
      # @param control_character [Integer] Control character (usually ':' or 0xFF)
      # @param topic_count [Integer] Number of topics
      # @param context_count [Integer] Number of context strings
      # @param display_width [Integer] Display width in characters
      # @param database_name [String] Database name for external links
      def initialize(
        magic: nil,
        version: 2,
        attributes: 0,
        control_character: 0x3A,
        topic_count: 0,
        context_count: 0,
        display_width: 80,
        predefined_ctx_count: 0,
        database_name: "",
        topic_index_offset: 0,
        context_strings_offset: 0,
        context_map_offset: 0,
        keywords_offset: 0,
        huffman_tree_offset: 0,
        topic_text_offset: 0,
        database_size: 0,
        filename: nil
      )
        @magic = magic || Binary::HLPStructures::SIGNATURE
        @version = version
        @attributes = attributes
        @control_character = control_character
        @topic_count = topic_count
        @context_count = context_count
        @display_width = display_width
        @predefined_ctx_count = predefined_ctx_count
        @database_name = database_name
        @topic_index_offset = topic_index_offset
        @context_strings_offset = context_strings_offset
        @context_map_offset = context_map_offset
        @keywords_offset = keywords_offset
        @huffman_tree_offset = huffman_tree_offset
        @topic_text_offset = topic_text_offset
        @database_size = database_size
        @filename = filename

        # Collections
        @topics = []
        @contexts = []
        @context_map = []
        @keywords = []
        @huffman_tree = nil
      end

      # Check if header is valid
      #
      # @return [Boolean] true if header appears valid
      def valid?
        @magic == Binary::HLPStructures::SIGNATURE &&
          @version == 2 &&
          @topic_count >= 0 &&
          @context_count >= 0
      end

      # Check if case-sensitive context strings
      #
      # @return [Boolean] true if case-sensitive
      def case_sensitive?
        @attributes.anybits?(Binary::HLPStructures::Attributes::CASE_SENSITIVE)
      end

      # Check if database is locked (cannot be decoded by HELPMAKE)
      #
      # @return [Boolean] true if locked
      def locked?
        @attributes.anybits?(Binary::HLPStructures::Attributes::LOCKED)
      end

      # Check if keyword compression is used
      #
      # @return [Boolean] true if keywords present
      def has_keywords?
        @keywords_offset.positive? && !@keywords.empty?
      end

      # Check if Huffman compression is used
      #
      # @return [Boolean] true if Huffman tree present
      def has_huffman?
        @huffman_tree_offset.positive? && !@huffman_tree.nil?
      end

      # Get control character as string
      #
      # @return [String] control character
      def control_char
        @control_character.chr(Encoding::ASCII)
      end

      # Get database name without null padding
      #
      # @return [String] trimmed database name
      def db_name
        @database_name.split("\x00").first || ""
      end
    end
  end
end
