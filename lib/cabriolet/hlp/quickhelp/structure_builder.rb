# frozen_string_literal: true

require_relative "topic_compressor"
require_relative "offset_calculator"

module Cabriolet
  module HLP
    module QuickHelp
      # Builds complete QuickHelp structure from file data
      class StructureBuilder
        attr_reader :version, :database_name, :control_char, :case_sensitive

        # Initialize structure builder
        #
        # @param version [Integer] QuickHelp format version
        # @param database_name [String] Database name for external links
        # @param control_char [Integer] Control character
        # @param case_sensitive [Boolean] Case-sensitive contexts
        def initialize(version: 2, database_name: "", control_char: 0x3A,
case_sensitive: false)
          @version = version
          @database_name = database_name
          @control_char = control_char
          @case_sensitive = case_sensitive
        end

        # Build complete QuickHelp structure from topics
        #
        # @param topics [Array<Hash>] Topic data with :text, :context, :compress keys
        # @return [Hash] Complete QuickHelp structure
        def build(topics)
          structure = {}

          # Compress topics
          structure[:topics] = compress_topics(topics)

          # Build context data
          structure[:contexts] = topics.map { |t| t[:context] }
          structure[:context_map] = topics.map.with_index { |_t, i| i }

          # Calculate offsets
          structure[:offsets] = OffsetCalculator.calculate(
            topics: structure[:topics],
            contexts: structure[:contexts],
            context_map: structure[:context_map],
          )

          # Build header
          structure[:header] = build_header(structure)

          structure
        end

        private

        # Compress all topics
        #
        # @param topics [Array<Hash>] Topic data
        # @return [Array<Hash>] Compressed topics
        def compress_topics(topics)
          topics.map do |topic|
            if topic[:compress]
              TopicCompressor.compress_topic(topic[:text])
            else
              TopicCompressor.store_uncompressed(topic[:text])
            end
          end
        end

        # Build file header
        #
        # @param structure [Hash] QuickHelp structure
        # @return [Hash] Header information
        def build_header(structure)
          attributes = 0
          attributes |= Binary::HLPStructures::Attributes::CASE_SENSITIVE if @case_sensitive

          {
            version: @version,
            attributes: attributes,
            control_character: @control_char,
            topic_count: structure[:topics].size,
            context_count: structure[:contexts].size,
            display_width: 80,
            predefined_ctx_count: 0,
            database_name: @database_name.ljust(14, "\x00")[0, 14],
            offsets: structure[:offsets],
          }
        end
      end
    end
  end
end
