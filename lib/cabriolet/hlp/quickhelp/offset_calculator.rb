# frozen_string_literal: true

module Cabriolet
  module HLP
    module QuickHelp
      # Calculates file offsets for QuickHelp structure
      class OffsetCalculator
        # Calculate all offsets in the file
        #
        # @param topics [Array<Hash>] Compressed topics
        # @param contexts [Array<String>] Context strings
        # @param context_map [Array<Integer>] Context topic indices
        # @return [Hash] Calculated offsets
        def self.calculate(topics:, contexts:, context_map:)
          offsets = {}

          # Start after file header (70 bytes = 2 signature + 68 header)
          current_offset = 70

          # Topic index: (topic_count + 1) * 4 bytes
          offsets[:topic_index] = current_offset
          topic_count = topics.size
          current_offset += (topic_count + 1) * 4

          # Context strings: sum of string lengths + null terminators
          offsets[:context_strings] = current_offset
          contexts.each do |ctx|
            current_offset += ctx.bytesize + 1 # +1 for null terminator
          end

          # Context map: context_count * 2 bytes
          offsets[:context_map] = current_offset
          current_offset += context_map.size * 2

          # Keywords: not implemented yet, set to 0
          offsets[:keywords] = 0

          # Huffman tree: not implemented yet, set to 0
          offsets[:huffman_tree] = 0

          # Topic text: starts after context map
          offsets[:topic_text] = current_offset

          # Calculate topic text offsets
          offsets[:topic_offsets] = []
          topics.each do |topic|
            offsets[:topic_offsets] << (current_offset - offsets[:topic_text])
            current_offset += topic[:compressed_length]
          end
          # Add end marker
          offsets[:topic_offsets] << (current_offset - offsets[:topic_text])

          # Total database size
          offsets[:database_size] = current_offset

          offsets
        end
      end
    end
  end
end
