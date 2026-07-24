# frozen_string_literal: true

module Cabriolet
  module CHM
    autoload :Parser, "cabriolet/chm/parser"
    autoload :Decompressor, "cabriolet/chm/decompressor"
    autoload :Compressor, "cabriolet/chm/compressor"
    autoload :CommandHandler, "cabriolet/chm/command_handler"
  end
end
