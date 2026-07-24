# frozen_string_literal: true

# Cabriolet is a pure Ruby library for extracting Microsoft Cabinet (.CAB) files,
# CHM (Compiled HTML Help) files, and related compression formats.
module Cabriolet
  autoload :VERSION, "cabriolet/version"
  autoload :Constants, "cabriolet/constants"
  autoload :Platform, "cabriolet/platform"

  # Error hierarchy — all defined in cabriolet/errors.rb
  autoload :Error, "cabriolet/errors"
  autoload :IOError, "cabriolet/errors"
  autoload :ParseError, "cabriolet/errors"
  autoload :DecompressionError, "cabriolet/errors"
  autoload :CompressionError, "cabriolet/errors"
  autoload :ChecksumError, "cabriolet/errors"
  autoload :UnsupportedFormatError, "cabriolet/errors"
  autoload :ArgumentError, "cabriolet/errors"
  autoload :SignatureError, "cabriolet/errors"
  autoload :FormatError, "cabriolet/errors"
  autoload :ReadError, "cabriolet/errors"
  autoload :SeekError, "cabriolet/errors"
  autoload :PluginError, "cabriolet/errors"

  # Sub-namespaces — each has its own namespace file with child autoloads
  autoload :System, "cabriolet/system"
  autoload :Binary, "cabriolet/binary"
  autoload :Huffman, "cabriolet/huffman"
  autoload :Models, "cabriolet/models"
  autoload :Decompressors, "cabriolet/decompressors"
  autoload :Compressors, "cabriolet/compressors"
  autoload :CAB, "cabriolet/cab"
  autoload :CHM, "cabriolet/chm"
  autoload :SZDD, "cabriolet/szdd"
  autoload :KWAJ, "cabriolet/kwaj"
  autoload :HLP, "cabriolet/hlp"
  autoload :LIT, "cabriolet/lit"
  autoload :OAB, "cabriolet/oab"
  autoload :Extraction, "cabriolet/extraction"
  autoload :Collections, "cabriolet/collections"
  autoload :Commands, "cabriolet/commands"
  autoload :Streaming, "cabriolet/streaming"

  # Foundation modules
  autoload :Checksum, "cabriolet/checksum"
  autoload :QuantumShared, "cabriolet/quantum_shared"

  # Core service classes
  autoload :AlgorithmFactory, "cabriolet/algorithm_factory"
  autoload :Plugin, "cabriolet/plugin"
  autoload :PluginValidator, "cabriolet/plugin_validator"
  autoload :PluginManager, "cabriolet/plugin_manager"
  autoload :BaseCompressor, "cabriolet/base_compressor"
  autoload :FileEntry, "cabriolet/file_entry"
  autoload :FileManager, "cabriolet/file_manager"
  autoload :FormatBase, "cabriolet/format_base"
  autoload :FormatDetector, "cabriolet/format_detector"
  autoload :Validator, "cabriolet/validator"
  autoload :ValidationReport, "cabriolet/validator"
  autoload :Repairer, "cabriolet/repairer"
  autoload :RepairReport, "cabriolet/repairer"
  autoload :SalvageReport, "cabriolet/repairer"
  autoload :Modifier, "cabriolet/modifier"
  autoload :ModificationReport, "cabriolet/modifier"
  autoload :OffsetCalculator, "cabriolet/offset_calculator"
  autoload :CABOffsetCalculator, "cabriolet/offset_calculator"

  # CLI — loading this also registers all format command handlers
  autoload :CLI, "cabriolet/cli"

  class << self
    attr_accessor :verbose
    attr_accessor :default_buffer_size

    def algorithm_factory
      @algorithm_factory ||= AlgorithmFactory.new
    end

    def algorithm_factory=(factory)
      @algorithm_factory = factory
    end

    def plugin_manager
      PluginManager.instance
    end
  end

  self.verbose = false
  self.default_buffer_size = 65_536

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
    def open(path, **)
      parser_class = FormatDetector.parser_for(path)

      unless parser_class
        format = detect_format(path)
        raise UnsupportedFormatError,
              "Unable to detect format or no parser available for: #{path} (detected: #{format || 'unknown'})"
      end

      parser_class.new(**).parse(path)
    end

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
    def extract(archive_path, output_dir, **)
      archive = open(archive_path)
      extractor = Extraction::Extractor.new(archive, output_dir, **)
      extractor.extract_all
    end

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
        compressed_size: file.compressed_size,
        attributes: file.attributes,
        date: file.date,
        time: file.time,
      }
    end
  end
end
