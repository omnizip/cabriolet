# frozen_string_literal: true

module Cabriolet
  module LIT
    autoload :Parser, "cabriolet/lit/parser"
    autoload :Decompressor, "cabriolet/lit/decompressor"
    autoload :Compressor, "cabriolet/lit/compressor"
    autoload :CommandHandler, "cabriolet/lit/command_handler"
    autoload :ContentEncoder, "cabriolet/lit/content_encoder"
    autoload :ContentTypeDetector, "cabriolet/lit/content_type_detector"
    autoload :DirectoryBuilder, "cabriolet/lit/directory_builder"
    autoload :GuidGenerator, "cabriolet/lit/guid_generator"
    autoload :HeaderWriter, "cabriolet/lit/header_writer"
    autoload :PieceBuilder, "cabriolet/lit/piece_builder"
    autoload :StructureBuilder, "cabriolet/lit/structure_builder"
  end
end
