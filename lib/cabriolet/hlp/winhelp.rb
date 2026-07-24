# frozen_string_literal: true

module Cabriolet
  module HLP
    module WinHelp
      autoload :Parser, "cabriolet/hlp/winhelp/parser"
      autoload :Decompressor, "cabriolet/hlp/winhelp/decompressor"
      autoload :Compressor, "cabriolet/hlp/winhelp/compressor"
      autoload :BTreeBuilder, "cabriolet/hlp/winhelp/btree_builder"
      autoload :ZeckLZ77, "cabriolet/hlp/winhelp/zeck_lz77"
    end
  end
end
