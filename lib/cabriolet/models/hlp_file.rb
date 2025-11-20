# frozen_string_literal: true

module Cabriolet
  module Models
    # QuickHelp topic model
    #
    # Represents a single topic in a QuickHelp help database.
    # Each topic contains formatted text lines with styles and hyperlinks.
    class HLPTopic
      attr_accessor :index, :offset, :size
      attr_accessor :lines, :source_data
      attr_accessor :metadata

      # Initialize a QuickHelp topic
      #
      # @param index [Integer] Topic index in the database
      # @param offset [Integer] Offset of topic data in file
      # @param size [Integer] Size of compressed topic data
      def initialize(index: 0, offset: 0, size: 0)
        @index = index
        @offset = offset
        @size = size
        @lines = []
        @source_data = nil
        @metadata = {}
      end

      # Check if topic has any content
      #
      # @return [Boolean] true if topic has lines
      def empty?
        @lines.empty?
      end

      # Get plain text content (without formatting)
      #
      # @return [String] plain text of all lines
      def plain_text
        @lines.map(&:text).join("\n")
      end

      # Add a line to the topic
      #
      # @param line [HLPLine] line to add
      # @return [void]
      def add_line(line)
        @lines << line
      end
    end

    # QuickHelp topic line model
    #
    # Represents a single line within a topic, including text, styles, and links.
    class HLPLine
      attr_accessor :text, :attributes

      # Initialize a topic line
      #
      # @param text [String] plain text content
      def initialize(text = "")
        @text = text
        @attributes = Array.new(text.length) { TextAttribute.new }
      end

      # Get line length in characters
      #
      # @return [Integer] character count
      def length
        @text.length
      end

      # Apply style to a range of characters
      #
      # @param start_index [Integer] start position (0-based)
      # @param end_index [Integer] end position (0-based, inclusive)
      # @param style [Integer] style flags
      # @return [void]
      def apply_style(start_index, end_index, style)
        (start_index..end_index).each do |i|
          @attributes[i].style = style if i < @attributes.length
        end
      end

      # Apply link to a range of characters
      #
      # @param start_index [Integer] start position (1-based, as per format)
      # @param end_index [Integer] end position (1-based, inclusive)
      # @param link [String] link target (context string or topic index)
      # @return [void]
      def apply_link(start_index, end_index, link)
        # Convert from 1-based to 0-based indexing
        start_idx = start_index - 1
        end_idx = end_index - 1

        (start_idx..end_idx).each do |i|
          @attributes[i].link = link if i >= 0 && i < @attributes.length
        end
      end
    end

    # Text attribute model
    #
    # Represents style and link information for a single character.
    class TextAttribute
      attr_accessor :style, :link

      # Initialize text attribute
      #
      # @param style [Integer] style flags (bold, italic, underline)
      # @param link [String, nil] link target if any
      def initialize(style = 0, link = nil)
        @style = style
        @link = link
      end

      # Check if character is bold
      #
      # @return [Boolean] true if bold
      def bold?
        (@style & Binary::HLPStructures::TextStyle::BOLD) != 0
      end

      # Check if character is italic
      #
      # @return [Boolean] true if italic
      def italic?
        (@style & Binary::HLPStructures::TextStyle::ITALIC) != 0
      end

      # Check if character is underlined
      #
      # @return [Boolean] true if underlined
      def underline?
        (@style & Binary::HLPStructures::TextStyle::UNDERLINE) != 0
      end

      # Check if character has a link
      #
      # @return [Boolean] true if linked
      def linked?
        !@link.nil?
      end
    end

    # Backward compatibility alias
    HLPFile = HLPTopic
  end
end
