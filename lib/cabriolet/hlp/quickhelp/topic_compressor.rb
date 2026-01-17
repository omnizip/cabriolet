# frozen_string_literal: true

module Cabriolet
  module HLP
    module QuickHelp
      # Compresses topic text using QuickHelp keyword compression
      class TopicCompressor
        # Compress topic text using QuickHelp keyword compression
        #
        # QuickHelp format uses:
        # - 0x00-0x0F: Literal bytes
        # - 0x10-0x17: Dictionary entry references
        # - 0x18: Run of spaces
        # - 0x19: Run of bytes (repeat)
        # - 0x1A: Escape byte (next byte is literal)
        # - 0x1B-0xFF: Literal bytes
        #
        # Without a dictionary, we encode literals directly and escape
        # control characters (0x10-0x1A) with 0x1A prefix.
        #
        # Topic text format:
        # - Each line: [len][text][newline][attr_len][attrs][0xFF]
        # - len includes itself, text, newline, attr_len
        # - attr_len includes itself and attrs, minimum 1 (just 0xFF terminator)
        #
        # @param text [String] Topic text
        # @return [Hash] Compressed topic with metadata
        def self.compress_topic(text)
          topic_data = TopicBuilder.build_topic_data(text)
          encoded = encode_keyword_compression(topic_data)

          # Prepend decompressed length (2 bytes)
          length_header = [topic_data.bytesize].pack("v")

          {
            text: text,
            compressed: length_header + encoded,
            decompressed_length: topic_data.bytesize,
            compressed_length: (length_header + encoded).bytesize,
          }
        end

        # Store topic without compression
        #
        # @param text [String] Topic text
        # @return [Hash] Uncompressed topic with metadata
        def self.store_uncompressed(text)
          topic_data = TopicBuilder.build_topic_data(text)

          {
            text: text,
            compressed: topic_data,
            decompressed_length: topic_data.bytesize,
            compressed_length: topic_data.bytesize,
          }
        end

        # Encode data using QuickHelp keyword compression format
        #
        # @param data [String] Data to encode
        # @return [String] Encoded data
        def self.encode_keyword_compression(data)
          result = +""

          data.bytes.each do |byte|
            if byte < 0x10 || byte == 0x1B || byte > 0x1A
              # Literal byte (except control range 0x10-0x1A)
              result << byte.chr
            elsif byte.between?(0x10, 0x1A)
              # Control byte - escape it
              result << 0x1A.chr << byte.chr
            else
              # 0x1B is also literal (above control range)
              result << byte.chr
            end
          end

          result
        end
      end
    end
  end
end
