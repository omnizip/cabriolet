# frozen_string_literal: true

module Cabriolet
  module HLP
    module QuickHelp
      # Huffman tree for QuickHelp topic compression
      #
      # Represents a Huffman tree that encodes symbols 0-255.
      # Based on the QuickHelp binary format specification.
      class HuffmanTree
        attr_reader :root, :symbol_count

        # Node in the Huffman tree
        class Node
          attr_accessor :symbol, :left_child, :right_child

          def initialize
            @symbol = nil
            @left_child = nil
            @right_child = nil
          end

          def leaf?
            @left_child.nil? && @right_child.nil?
          end
        end

        # Initialize empty tree
        def initialize
          @root = nil
          @symbol_count = 0
        end

        # Check if tree is empty
        #
        # @return [Boolean] true if empty
        def empty?
          @root.nil?
        end

        # Check if tree has single node
        #
        # @return [Boolean] true if singular
        def singular?
          !@root.nil? && @root.leaf?
        end

        # Deserialize Huffman tree from node values
        #
        # @param node_values [Array<Integer>] Array of 16-bit node values
        # @return [HuffmanTree] Deserialized tree
        # @raise [Cabriolet::ParseError] if tree is invalid
        def self.deserialize(node_values)
          tree = new
          return tree if node_values.empty?

          n = node_values.length
          if n.even?
            raise Cabriolet::ParseError,
                  "Invalid Huffman tree: expected odd number of nodes"
          end

          nodes = Array.new(n) { Node.new }
          symbol_exists = Array.new(256, false)

          n.times do |i|
            node = nodes[i]
            node_value = node_values[i]

            if node_value.negative? # Leaf node (bit 15 set)
              symbol = node_value & 0xFF
              if symbol_exists[symbol]
                raise Cabriolet::ParseError,
                      "Invalid Huffman tree: symbol #{symbol} already encoded"
              end

              node.symbol = symbol
              symbol_exists[symbol] = true
            else # Internal node
              child0 = node_value / 2
              child1 = i + 1

              # Validate child indices are within bounds
              unless child0 < n && child1 < n
                raise Cabriolet::ParseError,
                      "Invalid Huffman tree: invalid child node location (child0=#{child0}, child1=#{child1}, n=#{n})"
              end

              # Check for cycles by verifying left child hasn't been assigned yet
              if !nodes[child0].nil? && nodes[child0].left_child
                raise Cabriolet::ParseError,
                      "Invalid Huffman tree: cycle detected"
              end

              node.left_child = nodes[child0]
              node.right_child = nodes[child1]
            end
          end

          tree.instance_variable_set(:@root, nodes[0])
          tree.instance_variable_set(:@symbol_count, (n / 2) + 1)
          tree
        end

        # Create a decoder for this tree
        #
        # @return [HuffmanDecoder] New decoder
        def create_decoder
          HuffmanDecoder.new(self)
        end
      end

      # Decoder for Huffman-encoded data
      #
      # Usage:
      #   decoder = tree.create_decoder
      #   while !decoder.has_value?
      #     decoder.push(bitstream.read_bit)
      #   end
      #   symbol = decoder.value
      class HuffmanDecoder
        attr_reader :current_node

        # Initialize decoder
        #
        # @param tree [HuffmanTree] Huffman tree to use
        def initialize(tree)
          @tree = tree
          @current_node = tree.root
        end

        # Check if decoder has decoded a complete symbol
        #
        # @return [Boolean] true if value is ready
        def has_value?
          !@current_node.nil? && @current_node.leaf?
        end

        # Get decoded symbol value
        #
        # @return [Integer] Symbol value (0-255)
        # @raise [RuntimeError] if no value is ready
        def value
          raise "Decoder does not have a value" unless has_value?

          @current_node.symbol
        end

        # Push a bit into the decoder
        #
        # @param bit [Boolean, Integer] Bit value (true/1 for right, false/0 for left)
        # @raise [RuntimeError] if tree is empty or at leaf
        def push(bit)
          raise "Cannot walk an empty tree" if @current_node.nil?
          raise "Cannot walk further from a leaf" if @current_node.leaf?

          @current_node = bit ? @current_node.right_child : @current_node.left_child
        end

        # Reset decoder to tree root
        def reset
          @current_node = @tree.root
        end
      end
    end
  end
end
