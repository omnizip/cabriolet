# frozen_string_literal: true

require_relative "../../binary/bitstream"

module Cabriolet
  module HLP
    module QuickHelp
      # Compression stream decoder for QuickHelp topics
      #
      # Handles dictionary substitution (keyword compression) and run-length
      # encoding as specified in the QuickHelp format.
      #
      # Control bytes 0x10-0x1A have special meanings:
      # - 0x10-0x17: Dictionary entry (with optional space append)
      # - 0x18: Run of spaces
      # - 0x19: Run of bytes
      # - 0x1A: Escape byte
      class CompressionStream
        # Initialize compression stream decoder
        #
        # @param input [String, IO] Input data (compressed)
        # @param keywords [Array<String>] Keyword dictionary
        def initialize(input, keywords = [])
          @input = input.is_a?(String) ? StringIO.new(input) : input
          @keywords = keywords || []
          @buffer = ""
          @buffer_pos = 0
        end

        # Read bytes from the decompressed stream
        #
        # @param length [Integer] Number of bytes to read
        # @return [String] Decompressed data
        def read(length)
          result = String.new(encoding: Encoding::BINARY)

          while result.bytesize < length
            # Fill buffer if needed
            fill_buffer(length - result.bytesize) if @buffer_pos >= @buffer.bytesize

            # Check for EOF
            break if @buffer_pos >= @buffer.bytesize

            # Copy from buffer
            available = @buffer.bytesize - @buffer_pos
            to_copy = [length - result.bytesize, available].min
            result << @buffer[@buffer_pos, to_copy]
            @buffer_pos += to_copy
          end

          result
        end

        # Check if at end of stream
        #
        # @return [Boolean] true if EOF
        def eof?
          @buffer_pos >= @buffer.bytesize && @input.eof?
        end

        private

        # Fill internal buffer by decoding compressed data
        #
        # @param max_bytes [Integer] Maximum bytes to decode
        def fill_buffer(max_bytes)
          @buffer = String.new(encoding: Encoding::BINARY)
          @buffer_pos = 0

          # Decode until buffer has enough data or we hit EOF
          while @buffer.bytesize <= 256 && @buffer.bytesize < max_bytes
            byte = read_byte
            break if byte.nil? # EOF

            if byte < 0x10 || byte > 0x1A
              # Regular value byte
              @buffer << byte.chr
            elsif byte == 0x1A
              # Escape byte - next byte is literal
              escaped = read_byte
              raise Cabriolet::DecompressionError, "Unexpected EOF after escape byte" if escaped.nil?

              @buffer << escaped.chr
            elsif byte == 0x19
              # Run of bytes: REPEAT-BYTE, REPEAT-COUNT
              repeat_byte = read_byte
              repeat_count = read_byte
              raise Cabriolet::DecompressionError, "Unexpected EOF in byte run" if repeat_byte.nil? || repeat_count.nil?

              @buffer << (repeat_byte.chr * repeat_count)
            elsif byte == 0x18
              # Run of spaces: SPACE-COUNT
              space_count = read_byte
              raise Cabriolet::DecompressionError, "Unexpected EOF in space run" if space_count.nil?

              @buffer << (" " * space_count)
            else
              # Dictionary entry (0x10-0x17)
              dict_index_low = read_byte
              raise Cabriolet::DecompressionError, "Unexpected EOF reading dictionary index" if dict_index_low.nil?

              # Extract append-space flag (bit 2) and index (bits 0-1 + next 8 bits)
              append_space = byte.anybits?(0x04)
              dict_index = ((byte & 0x03) << 8) | dict_index_low

              if dict_index >= @keywords.length
                raise Cabriolet::DecompressionError, "Dictionary index #{dict_index} out of range (max #{@keywords.length - 1})"
              end

              @buffer << @keywords[dict_index]
              @buffer << " " if append_space
            end
          end
        end

        # Read a single byte from input
        #
        # @return [Integer, nil] Byte value or nil on EOF
        def read_byte
          @input.getbyte
        end
      end
    end
  end
end
