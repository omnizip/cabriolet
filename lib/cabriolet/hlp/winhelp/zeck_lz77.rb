# frozen_string_literal: true

module Cabriolet
  module HLP
    module WinHelp
      # Zeck LZ77 decompressor for Windows Help files
      #
      # Implements the Zeck LZ77 compression algorithm used in WinHelp files.
      # This is a variant of LZ77 with specific encoding:
      # - 4KB sliding window (4096 bytes)
      # - Minimum match: 3 bytes
      # - Maximum match: 271 bytes
      # - Flag-based token control (8 tokens per flag byte)
      #
      # Encoding:
      # - Flag byte: 8 bits controlling next 8 tokens
      #   - Bit = 0: Literal byte follows
      #   - Bit = 1: Match follows (2-3 bytes)
      # - Match format:
      #   - Byte 1: OOOO LLLL (O=offset high 4 bits, L=length 0-15)
      #   - Byte 2: OOOO OOOO (O=offset low 8 bits)
      #   - Byte 3 (if L=15): Extra length byte (0-252, add 19)
      #
      # Match decoding:
      # - Offset: 12 bits (0-4095)
      # - Length 3-18: 4 bits (0-15, add 3)
      # - Length 19-271: Extra byte (0-252, add 19)
      class ZeckLZ77
        # Window size for LZ77 compression
        WINDOW_SIZE = 4096

        # Minimum match length
        MIN_MATCH = 3

        # Maximum match length without extra byte
        MAX_SHORT_MATCH = 18

        # Maximum match length with extra byte
        MAX_LONG_MATCH = 271

        # Initialize decompressor
        def initialize
          @window = String.new(capacity: WINDOW_SIZE)
        end

        # Compress data using Zeck LZ77
        #
        # @param input [String] Uncompressed data
        # @return [String] Compressed data
        def compress(input)
          output = +""
          pos = 0
          @window.clear

          while pos < input.bytesize
            # Collect up to 8 tokens for this flag byte
            tokens = []
            flag = 0

            8.times do |bit|
              break if pos >= input.bytesize

              # Try to find a match
              match = find_best_match(input, pos)

              if match && match[:length] >= MIN_MATCH
                # Encode match
                tokens << encode_match(match)
                flag |= (1 << bit) # Set flag bit for match

                # Add matched bytes to window
                match[:length].times do
                  add_to_window(input.getbyte(pos))
                  pos += 1
                end
              else
                # Encode literal
                byte = input.getbyte(pos)
                tokens << [byte].pack("C")
                add_to_window(byte)
                pos += 1
              end
            end

            # Write flag byte followed by tokens
            output << [flag].pack("C")
            tokens.each { |token| output << token }
          end

          output
        end

        # Find best match in sliding window
        #
        # @param input [String] Input data
        # @param pos [Integer] Current position
        # @return [Hash, nil] Match info or nil
        def find_best_match(input, pos)
          return nil if @window.empty?

          best_match = nil
          best_length = 0

          # Search window for matches
          window_size = @window.bytesize
          max_offset = [window_size, WINDOW_SIZE].min

          # Start from most recent bytes (end of window)
          (1..max_offset).each do |offset|
            window_pos = window_size - offset
            match_length = 0

            # Count matching bytes
            while match_length < MAX_LONG_MATCH &&
                (pos + match_length) < input.bytesize &&
                (window_pos + match_length) < window_size

              if @window.getbyte(window_pos + match_length) == input.getbyte(pos + match_length)
                match_length += 1
              else
                break
              end
            end

            # Update best match if this is better
            if match_length >= MIN_MATCH && match_length > best_length
              best_length = match_length
              best_match = {
                offset: offset,
                length: match_length,
              }
            end
          end

          best_match
        end

        # Encode a match into bytes
        #
        # @param match [Hash] Match with :offset and :length
        # @return [String] Encoded match (2-3 bytes)
        def encode_match(match)
          offset = match[:offset]
          length = match[:length]

          # Calculate encoded length
          encoded_length = length - MIN_MATCH

          if length <= MAX_SHORT_MATCH
            # Short match: 2 bytes
            # Byte 1: OOOO LLLL (high offset 4 bits, length 0-15)
            # Byte 2: OOOO OOOO (low offset 8 bits)
            byte1 = ((offset >> 4) & 0xF0) | (encoded_length & 0x0F)
            byte2 = offset & 0xFF
            [byte1, byte2].pack("CC")
          else
            # Long match: 3 bytes (length > 18, needs extra byte)
            # Byte 1: OOOO 1111 (high offset, length = 15)
            # Byte 2: OOOO OOOO (low offset)
            # Byte 3: Extra length (length - 19)
            byte1 = ((offset >> 4) & 0xF0) | 0x0F
            byte2 = offset & 0xFF
            byte3 = length - 19
            [byte1, byte2, byte3].pack("CCC")
          end
        end

        # Decompress Zeck LZ77 compressed data
        #
        # @param input [String] Compressed data
        # @param output_size [Integer] Expected decompressed size
        # @return [String] Decompressed data
        # @raise [Cabriolet::DecompressionError] if decompression fails
        def decompress(input, output_size)
          output = String.new(capacity: output_size)
          input_pos = 0
          @window.clear

          while output.bytesize < output_size && input_pos < input.bytesize
            # Read flag byte
            flags = input.getbyte(input_pos)
            input_pos += 1
            break if input_pos > input.bytesize

            # Process 8 tokens controlled by flag byte
            8.times do |bit|
              break if output.bytesize >= output_size

              if flags.nobits?(1 << bit)
                # Bit = 0: Literal byte
                byte = input.getbyte(input_pos)
                return output if byte.nil? # End of input

                input_pos += 1
                output << byte.chr
                add_to_window(byte)
              else
                # Bit = 1: Match (2-3 bytes)
                break if input_pos + 1 >= input.bytesize

                # Read match bytes
                byte1 = input.getbyte(input_pos)
                byte2 = input.getbyte(input_pos + 1)
                input_pos += 2

                # Decode offset and length
                # byte1: OOOO LLLL (high offset and length)
                # byte2: OOOO OOOO (low offset)
                offset = ((byte1 & 0xF0) << 4) | byte2
                length = (byte1 & 0x0F) + MIN_MATCH

                # If length is max short match, check for extra length byte
                if length == (15 + MIN_MATCH) && input_pos < input.bytesize
                  extra = input.getbyte(input_pos)
                  input_pos += 1
                  length = extra + 19 # Length 19-271
                end

                # Copy from window
                copy_match(output, offset, length)
              end
            end
          end

          output
        end

        private

        # Add byte to sliding window
        #
        # @param byte [Integer] Byte to add
        def add_to_window(byte)
          @window << byte.chr
          @window = @window[-WINDOW_SIZE..] if @window.bytesize > WINDOW_SIZE
        end

        # Copy match from window
        #
        # @param output [String] Output buffer
        # @param offset [Integer] Offset in window (0-4095)
        # @param length [Integer] Match length (3-271)
        def copy_match(output, offset, length)
          # Calculate position in window
          window_pos = @window.bytesize - offset

          raise Cabriolet::DecompressionError, "Invalid offset: #{offset}" if window_pos.negative?

          # Copy bytes from window
          length.times do
            if window_pos < @window.bytesize
              byte = @window.getbyte(window_pos)
              output << byte.chr
              add_to_window(byte)
              window_pos += 1
            else
              # Match extends beyond current window, copy from output
              # This handles overlapping matches
              byte = output.getbyte(output.bytesize - offset)
              output << byte.chr
              add_to_window(byte)
            end
          end
        end
      end
    end
  end
end
