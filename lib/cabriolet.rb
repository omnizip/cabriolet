# frozen_string_literal: true

# Cabriolet - Pure Ruby implementation of Microsoft compression formats
require_relative "cabriolet/version"
require_relative "cabriolet/constants"
require_relative "cabriolet/errors"
require_relative "cabriolet/platform"

# System layer
require_relative "cabriolet/system/io_system"
require_relative "cabriolet/system/file_handle"
require_relative "cabriolet/system/memory_handle"

# Binary structures
require_relative "cabriolet/binary/bitstream"
require_relative "cabriolet/binary/bitstream_writer"
require_relative "cabriolet/binary/structures"
require_relative "cabriolet/binary/chm_structures"
require_relative "cabriolet/binary/szdd_structures"
require_relative "cabriolet/binary/kwaj_structures"
require_relative "cabriolet/binary/hlp_structures"
require_relative "cabriolet/binary/lit_structures"
require_relative "cabriolet/binary/oab_structures"

# Foundation classes (architectural improvements)
require_relative "cabriolet/file_entry"
require_relative "cabriolet/file_manager"
require_relative "cabriolet/base_compressor"

# Cabriolet is a pure Ruby library for extracting Microsoft Cabinet (.CAB) files,
# CHM (Compiled HTML Help) files, and related compression formats.
module Cabriolet
  class << self
    # Enable or disable verbose output
    attr_accessor :verbose

    # Default buffer size for I/O operations (4KB)
    attr_accessor :default_buffer_size

    # Get the global algorithm factory instance
    #
    # @return [AlgorithmFactory] The algorithm factory
    def algorithm_factory
      @algorithm_factory ||= AlgorithmFactory.new
    end

    # Set the global algorithm factory instance
    #
    # @param factory [AlgorithmFactory] The algorithm factory to use
    # @return [AlgorithmFactory] The factory
    def algorithm_factory=(factory)
      @algorithm_factory = factory
    end

    # Get the global plugin manager instance
    #
    # @return [PluginManager] The plugin manager
    def plugin_manager
      PluginManager.instance
    end
  end

  self.verbose = false
  self.default_buffer_size = 4096
end

# Models
require_relative "cabriolet/models/cabinet"
require_relative "cabriolet/models/folder"
require_relative "cabriolet/models/folder_data"
require_relative "cabriolet/models/file"
require_relative "cabriolet/models/chm_header"
require_relative "cabriolet/models/chm_section"
require_relative "cabriolet/models/chm_file"
require_relative "cabriolet/models/szdd_header"
require_relative "cabriolet/models/kwaj_header"
require_relative "cabriolet/models/hlp_header"
require_relative "cabriolet/models/hlp_file"
require_relative "cabriolet/models/winhelp_header"
require_relative "cabriolet/models/lit_header"
require_relative "cabriolet/models/oab_header"

# Load errors first (needed by algorithm_factory)
require_relative "cabriolet/errors"

# Load plugin system
require_relative "cabriolet/plugin"
require_relative "cabriolet/plugin_validator"
require_relative "cabriolet/plugin_manager"

# Load algorithm factory
require_relative "cabriolet/algorithm_factory"

# Load core components
require_relative "cabriolet/system/io_system"
require_relative "cabriolet/system/file_handle"
require_relative "cabriolet/system/memory_handle"

require_relative "cabriolet/binary/structures"
require_relative "cabriolet/binary/bitstream"
require_relative "cabriolet/binary/bitstream_writer"
require_relative "cabriolet/binary/chm_structures"
require_relative "cabriolet/binary/szdd_structures"
require_relative "cabriolet/binary/kwaj_structures"
require_relative "cabriolet/binary/hlp_structures"
require_relative "cabriolet/binary/lit_structures"
require_relative "cabriolet/binary/oab_structures"

require_relative "cabriolet/models/cabinet"
require_relative "cabriolet/models/folder"
require_relative "cabriolet/models/file"
require_relative "cabriolet/models/chm_header"
require_relative "cabriolet/models/chm_file"
require_relative "cabriolet/models/chm_section"
require_relative "cabriolet/models/szdd_header"
require_relative "cabriolet/models/kwaj_header"
require_relative "cabriolet/models/hlp_header"
require_relative "cabriolet/models/hlp_file"
require_relative "cabriolet/models/lit_header"
require_relative "cabriolet/models/oab_header"

require_relative "cabriolet/huffman/tree"
require_relative "cabriolet/huffman/decoder"
require_relative "cabriolet/huffman/encoder"

require_relative "cabriolet/decompressors/base"
require_relative "cabriolet/decompressors/none"
require_relative "cabriolet/decompressors/lzss"
require_relative "cabriolet/decompressors/mszip"
require_relative "cabriolet/decompressors/lzx"
require_relative "cabriolet/decompressors/quantum"

require_relative "cabriolet/compressors/base"
require_relative "cabriolet/compressors/lzss"
require_relative "cabriolet/compressors/mszip"
require_relative "cabriolet/compressors/lzx"
require_relative "cabriolet/compressors/quantum"

require_relative "cabriolet/cab/parser"
require_relative "cabriolet/cab/decompressor"
require_relative "cabriolet/cab/extractor"
require_relative "cabriolet/cab/compressor"

require_relative "cabriolet/chm/parser"
require_relative "cabriolet/chm/decompressor"
require_relative "cabriolet/chm/compressor"

require_relative "cabriolet/szdd/parser"
require_relative "cabriolet/szdd/decompressor"
require_relative "cabriolet/szdd/compressor"

require_relative "cabriolet/kwaj/parser"
require_relative "cabriolet/kwaj/decompressor"
require_relative "cabriolet/kwaj/compressor"

require_relative "cabriolet/hlp/parser"
require_relative "cabriolet/hlp/decompressor"
require_relative "cabriolet/hlp/compressor"

require_relative "cabriolet/hlp/winhelp/parser"
require_relative "cabriolet/hlp/winhelp/zeck_lz77"
require_relative "cabriolet/hlp/winhelp/decompressor"
require_relative "cabriolet/hlp/winhelp/compressor"

require_relative "cabriolet/lit/decompressor"
require_relative "cabriolet/lit/compressor"

require_relative "cabriolet/oab/decompressor"
require_relative "cabriolet/oab/compressor"

# Load new advanced features
require_relative "cabriolet/format_detector"
require_relative "cabriolet/auto"
require_relative "cabriolet/streaming"
require_relative "cabriolet/validator"
require_relative "cabriolet/repairer"
require_relative "cabriolet/modifier"
require_relative "cabriolet/parallel"

# Load CLI (optional, for command-line usage)
require_relative "cabriolet/cli"
