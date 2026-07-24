# frozen_string_literal: true

module Cabriolet
  module CAB
    autoload :Parser, "cabriolet/cab/parser"
    autoload :Decompressor, "cabriolet/cab/decompressor"
    autoload :Extractor, "cabriolet/cab/extractor"
    autoload :Compressor, "cabriolet/cab/compressor"
    autoload :CommandHandler, "cabriolet/cab/command_handler"
    autoload :FileCompressionWork, "cabriolet/cab/file_compression_work"
    autoload :FileCompressionWorker, "cabriolet/cab/file_compression_worker"
  end
end
