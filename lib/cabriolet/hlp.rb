# frozen_string_literal: true

module Cabriolet
  module HLP
    autoload :Parser, "cabriolet/hlp/parser"
    autoload :Decompressor, "cabriolet/hlp/decompressor"
    autoload :Compressor, "cabriolet/hlp/compressor"
    autoload :CommandHandler, "cabriolet/hlp/command_handler"
    autoload :WinHelp, "cabriolet/hlp/winhelp"
    autoload :QuickHelp, "cabriolet/hlp/quickhelp"
  end
end
