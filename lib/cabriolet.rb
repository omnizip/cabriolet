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
require_relative "cabriolet/checksum"

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
  # Default buffer size of 64KB - better for modern systems
  # Larger buffers reduce I/O syscall overhead significantly
  self.default_buffer_size = 65_536
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

# Load plugin system
require_relative "cabriolet/plugin"
require_relative "cabriolet/plugin_validator"
require_relative "cabriolet/plugin_manager"

# Load algorithm factory
require_relative "cabriolet/algorithm_factory"

# Load core components

require_relative "cabriolet/quantum_shared"

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
require_relative "cabriolet/extraction/base_extractor"
require_relative "cabriolet/extraction/extractor"
require_relative "cabriolet/streaming"
require_relative "cabriolet/validator"
require_relative "cabriolet/repairer"
require_relative "cabriolet/modifier"

# Load CLI (optional, for command-line usage)
require_relative "cabriolet/cli"

# Convenience methods at top level
module Cabriolet
  class << self
    # Open and parse an archive with automatic format detection
    #
    # @param path [String] Path to the archive file
    # @param options [Hash] Options to pass to the parser
    # @return [Object] Parsed archive object
    # @raise [UnsupportedFormatError] if format cannot be detected or is unsupported
    #
    # @example
    #   archive = Cabriolet.open('unknown.archive')
    #   archive.files.each { |f| puts f.name }
    def open(path, **options)
      parser_class = FormatDetector.parser_for(path)

      unless parser_class
        format = detect_format(path)
        raise UnsupportedFormatError,
              "Unable to detect format or no parser available for: #{path} (detected: #{format || 'unknown'})"
      end

      parser_class.new(**options).parse(path)
    end

    # Detect format of an archive file
    #
    # @param path [String] Path to the file
    # @return [Symbol, nil] Detected format symbol or nil
    #
    # @example
    #   format = Cabriolet.detect_format('file.cab')
    #   # => :cab
    def detect_format(path)
      FormatDetector.detect(path)
    end

    # Extract files from an archive with automatic format detection
    #
    # @param archive_path [String] Path to the archive
    # @param output_dir [String] Directory to extract to
    # @param options [Hash] Extraction options
    # @option options [Integer] :workers (4) Number of parallel workers (1 = sequential)
    # @option options [Boolean] :preserve_paths (true) Preserve directory structure
    # @option options [Boolean] :overwrite (false) Overwrite existing files
    # @return [Hash] Extraction statistics
    #
    # @example Sequential extraction
    #   Cabriolet.extract('archive.cab', 'output/')
    #
    # @example Parallel extraction with 8 workers
    #   stats = Cabriolet.extract('file.chm', 'docs/', workers: 8)
    #   puts "Extracted #{stats[:extracted]} files"
    def extract(archive_path, output_dir, **options)
      archive = open(archive_path)
      extractor = Extraction::Extractor.new(archive, output_dir, **options)
      extractor.extract_all
    end

    # Get information about an archive without full extraction
    #
    # @param path [String] Path to the archive
    # @return [Hash] Archive information
    #
    # @example
    #   info = Cabriolet.info('archive.cab')
    #   # => { format: :cab, file_count: 145, total_size: 52428800, ... }
    def info(path)
      archive = open(path)
      format = detect_format(path)

      {
        format: format,
        path: path,
        file_count: archive.files.count,
        total_size: archive.files.sum { |f| f.size || 0 },
        compressed_size: File.size(path),
        compression_ratio: calculate_compression_ratio(archive, path),
        files: archive.files.map { |f| file_info(f) },
      }
    end

    private

    def calculate_compression_ratio(archive, path)
      total_uncompressed = archive.files.sum { |f| f.size || 0 }
      compressed = File.size(path)

      return 0 if total_uncompressed.zero?

      ((compressed.to_f / total_uncompressed) * 100).round(2)
    end

    def file_info(file)
      {
        name: file.name,
        size: file.size,
        compressed_size: file.respond_to?(:compressed_size) ? file.compressed_size : nil,
        attributes: file.respond_to?(:attributes) ? file.attributes : nil,
        date: file.respond_to?(:date) ? file.date : nil,
        time: file.respond_to?(:time) ? file.time : nil,
      }
    end
  end
end
