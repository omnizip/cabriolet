# frozen_string_literal: true

require_relative "../../binary/bitstream"

module Cabriolet
  module HLP
    module QuickHelp
      # Huffman stream decoder for QuickHelp topics
      #
      # Wraps a bitstream and uses a Huffman tree to decode symbols.
      # Reads bits from MSB to LSB within each byte.
      class HuffmanStream
        # Initialize Huffman stream decoder
        #
        # @param input [String, IO] Input data (Huffman-encoded bitstream)
        # @param huffman_tree [HuffmanTree] Huffman tree for decoding
        def initialize(input, huffman_tree)
          @input = input.is_a?(String) ? StringIO.new(input) : input
          @huffman_tree = huffman_tree
          # QuickHelp uses MSB-first bit order
          @bitstream = Binary::Bitstream.new(@input, true) # MSB first
        end

        # Read and decode bytes from the Huffman stream
        #
        # @param length [Integer] Number of decoded bytes to read
        # @return [String] Decoded data
        def read(length)
          result = String.new(encoding: Encoding::BINARY)

          length.times do
            byte = read_byte
            break if byte.nil?

            result << byte.chr
          end

          result
        end

        # Read and decode a single byte
        #
        # @return [Integer, nil] Decoded byte value or nil on EOF
        def read_byte
          return nil if @huffman_tree.empty?

          # Handle singular tree (single symbol, no bits needed)
          if @huffman_tree.singular?
            return @huffman_tree.root.symbol
          end

          # Decode using tree
          decoder = @huffman_tree.create_decoder

          until decoder.has_value?
            bit = @bitstream.read_bits(1)
            return nil if bit.nil? # EOF

            decoder.push(bit != 0)
          end

          decoder.value
        end

        # Check if at end of stream
        #
        # @return [Boolean] true if EOF
        def eof?
          @input.eof?
        end
      end
    end
  end
end
