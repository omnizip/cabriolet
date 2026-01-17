# frozen_string_literal: true

module Cabriolet
  module HLP
    module QuickHelp
      # Builds topic data in QuickHelp internal format
      class TopicBuilder
        # Build topic data in QuickHelp internal format
        #
        # Topic format as expected by decompressor:
        # - Each line: [text_length][text][newline][attr_len][attrs][0xFF]
        # - text_length = text + newline + 1 (for attr_len byte) = text_bytes + 2
        # - Line structure: text_length byte + text + newline + attr_len byte + attr_data
        #
        # The decompressor reads:
        # - text_length = data.getbyte(pos)
        # - text_bytes = text_length - 2 (reads text, skips newline)
        # - attr_length = data.getbyte(pos after text + newline)
        #
        # @param text [String] Raw topic text
        # @return [String] Formatted topic data
        def self.build_topic_data(text)
          result = +""

          # Split text into lines
          lines = text.split("\n")

          lines.each do |line|
            text_bytes = line.b
            newline = "\x0D" # Carriage return

            # Attribute section: just 0xFF terminator (attr_len = 1)
            attr_data = "\xFF"
            attr_len = 1

            # text_length = text + newline + 1 (for attr_len byte)
            # This ensures text_bytes = text_length - 2 gives correct text length
            text_length = text_bytes.bytesize + 2

            result << text_length.chr
            result << text_bytes
            result << newline
            result << attr_len.chr
            result << attr_data
          end

          result
        end
      end
    end
  end
end
