# frozen_string_literal: true

module Cabriolet
  module HLP
    module QuickHelp
      autoload :Parser, "cabriolet/hlp/quickhelp/parser"
      autoload :Decompressor, "cabriolet/hlp/quickhelp/decompressor"
      autoload :Compressor, "cabriolet/hlp/quickhelp/compressor"
      autoload :CompressionStream, "cabriolet/hlp/quickhelp/compression_stream"
      autoload :FileWriter, "cabriolet/hlp/quickhelp/file_writer"
      autoload :HuffmanStream, "cabriolet/hlp/quickhelp/huffman_stream"
      autoload :HuffmanTree, "cabriolet/hlp/quickhelp/huffman_tree"
      autoload :OffsetCalculator, "cabriolet/hlp/quickhelp/offset_calculator"
      autoload :StructureBuilder, "cabriolet/hlp/quickhelp/structure_builder"
      autoload :TopicBuilder, "cabriolet/hlp/quickhelp/topic_builder"
      autoload :TopicCompressor, "cabriolet/hlp/quickhelp/topic_compressor"
    end
  end
end
