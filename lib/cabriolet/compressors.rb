# frozen_string_literal: true

module Cabriolet
  module Compressors
    autoload :Base, "cabriolet/compressors/base"
    autoload :LZSS, "cabriolet/compressors/lzss"
    autoload :MSZIP, "cabriolet/compressors/mszip"
    autoload :LZX, "cabriolet/compressors/lzx"
    autoload :Quantum, "cabriolet/compressors/quantum"
  end
end
