# frozen_string_literal: true

module Cabriolet
  module SZDD
    autoload :Parser, "cabriolet/szdd/parser"
    autoload :Decompressor, "cabriolet/szdd/decompressor"
    autoload :Compressor, "cabriolet/szdd/compressor"
    autoload :CommandHandler, "cabriolet/szdd/command_handler"
  end
end
