# frozen_string_literal: true

module Cabriolet
  module Decompressors
    autoload :Base, "cabriolet/decompressors/base"
    autoload :None, "cabriolet/decompressors/none"
    autoload :LZSS, "cabriolet/decompressors/lzss"
    autoload :MSZIP, "cabriolet/decompressors/mszip"
    autoload :LZX, "cabriolet/decompressors/lzx"
    autoload :Quantum, "cabriolet/decompressors/quantum"
  end
end
