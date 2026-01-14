# frozen_string_literal: true

require "thor"

require_relative "cli/command_registry"
require_relative "cli/command_dispatcher"

# Register all format handlers with the command registry
require_relative "cab/command_handler"
require_relative "chm/command_handler"
require_relative "szdd/command_handler"
require_relative "kwaj/command_handler"
require_relative "hlp/command_handler"
require_relative "lit/command_handler"
require_relative "oab/command_handler"

Cabriolet::Commands::CommandRegistry.register_format(:cab, Cabriolet::CAB::CommandHandler)
Cabriolet::Commands::CommandRegistry.register_format(:chm, Cabriolet::CHM::CommandHandler)
Cabriolet::Commands::CommandRegistry.register_format(:szdd, Cabriolet::SZDD::CommandHandler)
Cabriolet::Commands::CommandRegistry.register_format(:kwaj, Cabriolet::KWAJ::CommandHandler)
Cabriolet::Commands::CommandRegistry.register_format(:hlp, Cabriolet::HLP::CommandHandler)
Cabriolet::Commands::CommandRegistry.register_format(:lit, Cabriolet::LIT::CommandHandler)
Cabriolet::Commands::CommandRegistry.register_format(:oab, Cabriolet::OAB::CommandHandler)

module Cabriolet
  # CLI provides unified command-line interface for Cabriolet
  #
  # The CLI uses auto-detection to determine the format of input files,
  # then dispatches commands to the appropriate format handler.
  # A --format option allows manual override when needed.
  #
  # Legacy format-specific commands are maintained for backward compatibility.
  #
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    # Global option for format override
    class_option :format, type: :string, enum: %w[cab chm szdd kwaj hlp lit oab],
                          desc: "Force format (overrides auto-detection)"

    # Global option for verbose output
    class_option :verbose, type: :boolean, aliases: "-v",
                           desc: "Enable verbose output"

    # ==========================================================================
    # Unified Commands (auto-detect format)
    # ==========================================================================

    desc "list FILE", "List contents of archive file (auto-detects format)"
    option :format, type: :string, hide: true # Deprecated, use global --format
    def list(file)
      run_dispatcher(:list, file, **options)
    end

    desc "extract FILE [OUTPUT_DIR]",
         "Extract files from archive (auto-detects format)"
    option :output, type: :string, aliases: "-o",
                    desc: "Output file/directory path"
    option :salvage, type: :boolean,
                     desc: "Enable salvage mode for corrupted files (CAB only)"
    option :base_file, type: :string,
                       desc: "Base file for incremental patches (OAB only)"
    option :use_manifest, type: :boolean,
                          desc: "Use manifest for filenames (LIT only)"
    option :format, type: :string, hide: true # Deprecated, use global --format
    def extract(file, output_dir = nil)
      run_dispatcher(:extract, file, output_dir, **options)
    end

    desc "create OUTPUT FILES...",
         "Create archive file (auto-detects format from extension)"
    option :compression, type: :string, enum: %w[none mszip lzx quantum],
                         desc: "Compression type (CAB only)"
    option :format, type: :string, enum: %w[cab chm szdd kwaj hlp lit oab],
                    desc: "Output format (default: auto-detect from OUTPUT extension)"
    option :window_bits, type: :numeric, desc: "LZX window size for CHM (15-21)"
    option :missing_char, type: :string, desc: "Missing character for SZDD"
    option :szdd_format, type: :string, enum: %w[normal qbasic],
                         desc: "SZDD format variant (default: normal)"
    option :kwaj_compression, type: :string, enum: %w[none xor szdd mszip],
                              desc: "KWAJ compression method (default: szdd)"
    option :include_length, type: :boolean,
                            desc: "Include length in KWAJ header"
    option :kwaj_filename, type: :string,
                           desc: "Original filename for KWAJ header"
    option :extra_data, type: :string, desc: "Extra data for KWAJ header"
    option :hlp_format, type: :string, enum: %w[quickhelp winhelp],
                        desc: "HLP format variant (default: quickhelp)"
    option :language_id, type: :string,
                         desc: "Language ID for LIT (e.g., 0x409)"
    option :lit_version, type: :numeric, desc: "LIT format version (default: 1)"
    option :block_size, type: :numeric, desc: "Block size for OAB compression"
    option :compress, type: :boolean, default: true,
                      desc: "Compress files in HLP/LIT"
    def create(output, *files)
      # Normalize options for create command
      create_options = normalize_create_options(options)

      # Detect format from output extension if not specified
      format = detect_format_from_output(output, create_options[:format])

      # Set the format in options for the dispatcher
      create_options[:format] = format

      run_dispatcher(:create, output, files, **create_options)
    end

    desc "info FILE",
         "Show detailed archive file information (auto-detects format)"
    option :format, type: :string, hide: true # Deprecated, use global --format
    def info(file)
      run_dispatcher(:info, file, **options)
    end

    desc "test FILE", "Test archive file integrity (auto-detects format)"
    option :format, type: :string, hide: true # Deprecated, use global --format
    def test(file)
      run_dispatcher(:test, file, **options)
    end

    # ==========================================================================
    # Legacy Commands (maintained for backward compatibility)
    # ==========================================================================

    # CAB-specific legacy commands
    desc "search FILE", "Search for embedded CAB files"
    def search(file)
      setup_verbose(options[:verbose])

      decompressor = CAB::Decompressor.new
      cabinet = decompressor.search(file)

      if cabinet
        count = 0
        cab = cabinet
        while cab
          puts "Cabinet found at offset #{cab.base_offset}"
          puts "  Files: #{cab.file_count}, Folders: #{cab.folder_count}"
          cab = cab.next
          count += 1
        end
        puts "\nTotal: #{count} cabinet(s) found"
      else
        puts "No cabinets found in #{file}"
      end
    rescue Error => e
      abort "Error: #{e.message}"
    end

    # CHM legacy commands (aliases to unified commands with format override)
    desc "chm-list FILE",
         "List contents of CHM file (legacy, use: list --format chm FILE)"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def chm_list(file)
      run_with_format(:list, :chm, file, verbose: options[:verbose])
    end

    desc "chm-extract FILE [OUTPUT_DIR]",
         "Extract files from CHM (legacy, use: extract --format chm FILE)"
    option :output, type: :string, aliases: "-o", desc: "Output directory"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def chm_extract(file, output_dir = nil)
      opts = { verbose: options[:verbose], output: options[:output] }
      run_with_format(:extract, :chm, file, output_dir, **opts)
    end

    desc "chm-info FILE",
         "Show CHM file information (legacy, use: info --format chm FILE)"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def chm_info(file)
      run_with_format(:info, :chm, file, verbose: options[:verbose])
    end

    desc "chm-create OUTPUT FILES...",
         "Create CHM file (legacy, use: create --format chm OUTPUT FILES...)"
    option :window_bits, type: :numeric, default: 16,
                         desc: "LZX window size (15-21)"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def chm_create(output, *files)
      opts = { verbose: options[:verbose], window_bits: options[:window_bits],
               format: :chm }
      run_dispatcher(:create, output, files, **opts)
    end

    # SZDD legacy commands
    desc "expand FILE [OUTPUT]",
         "Expand SZDD file (legacy, use: extract --format szdd FILE OUTPUT)"
    option :output, type: :string, aliases: "-o", desc: "Output file path"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def expand(file, output = nil)
      # Use positional output if provided, otherwise use option
      final_output = output || options[:output]
      opts = { verbose: options[:verbose], output: final_output, format: :szdd }
      run_dispatcher(:extract, file, final_output, **opts)
    end

    desc "szdd-info FILE",
         "Show SZDD file information (legacy, use: info --format szdd FILE)"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def szdd_info(file)
      run_with_format(:info, :szdd, file, verbose: options[:verbose])
    end

    desc "compress FILE [OUTPUT]",
         "Compress to SZDD format (legacy, use: create --format szdd OUTPUT FILE)"
    option :output, type: :string, aliases: "-o", desc: "Output file path"
    option :missing_char, type: :string, desc: "Missing character for filename"
    option :format, type: :string, enum: %w[normal qbasic], default: "normal",
                    desc: "SZDD format (normal or qbasic)"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def compress(file, output = nil)
      # SZDD format option refers to SZDD variant (normal/qbasic), not file format
      # File format is always :szdd, variant is passed as szdd_format
      szdd_variant = options[:format] || "normal"

      opts = {
        verbose: options[:verbose],
        output: options[:output],
        format: :szdd,  # Always SZDD format
        szdd_format: szdd_variant.to_sym,  # Pass variant as szdd_format
        missing_char: options[:missing_char],
      }
      # SZDD convention: auto-generate output name
      output ||= opts[:output]
      if output.nil?
        ext = File.extname(file)
        # SZDD format: last character of extension replaced with underscore
        # e.g., file.txt -> file.tx_, file.c -> file.c_
        if ext.length.between?(2, 4) # .c, .txt, .html, etc.
          base = File.basename(file, ext)
          output = "#{base}#{ext.chomp(ext[-1])}_"
        else
          output = "#{file}_"
        end
        opts[:output] = output
      end
      run_dispatcher(:create, output, [file], **opts)
    end

    # KWAJ legacy commands
    desc "kwaj-extract FILE [OUTPUT]",
         "Extract KWAJ file (legacy, use: extract --format kwaj FILE OUTPUT)"
    option :output, type: :string, aliases: "-o", desc: "Output file path"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def kwaj_extract(file, output = nil)
      # Use positional output if provided, otherwise use option
      output_file = output || options[:output]
      opts = { verbose: options[:verbose], output: output_file, format: :kwaj }
      run_dispatcher(:extract, file, nil, **opts)
    end

    desc "kwaj-info FILE",
         "Show KWAJ file information (legacy, use: info --format kwaj FILE)"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def kwaj_info(file)
      run_with_format(:info, :kwaj, file, verbose: options[:verbose])
    end

    desc "kwaj-compress FILE [OUTPUT]",
         "Compress to KWAJ format (legacy, use: create --format kwaj OUTPUT FILE)"
    option :output, type: :string, aliases: "-o", desc: "Output file path"
    option :compression, type: :string, enum: %w[none xor szdd mszip], default: "szdd",
                         desc: "Compression method"
    option :include_length, type: :boolean, desc: "Include uncompressed length"
    option :filename, type: :string, desc: "Original filename to embed"
    option :extra_data, type: :string, desc: "Extra data to include"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def kwaj_compress(file, output = nil)
      # Use positional output if provided, otherwise use option or default
      output_file = output || options[:output] || "#{file}.kwj"
      opts = {
        verbose: options[:verbose],
        output: output_file,
        format: :kwaj,
        compression: options[:compression],
        include_length: options[:include_length],
        filename: options[:filename],
        extra_data: options[:extra_data],
      }
      run_dispatcher(:create, opts[:output], [file], **opts)
    end

    # HLP legacy commands
    desc "hlp-extract FILE [OUTPUT_DIR]",
         "Extract HLP file (legacy, use: extract --format hlp FILE)"
    option :output, type: :string, aliases: "-o", desc: "Output directory"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def hlp_extract(file, output_dir = nil)
      opts = { verbose: options[:verbose], output: options[:output],
               format: :hlp }
      run_dispatcher(:extract, file, output_dir, **opts)
    end

    desc "hlp-info FILE",
         "Show HLP file information (legacy, use: info --format hlp FILE)"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def hlp_info(file)
      run_with_format(:info, :hlp, file, verbose: options[:verbose])
    end

    desc "hlp-create OUTPUT FILES...",
         "Create HLP file (legacy, use: create --format hlp OUTPUT FILES...)"
    option :compress, type: :boolean, default: true, desc: "Compress files"
    option :format, type: :string, enum: %w[quickhelp winhelp], default: "quickhelp",
                    desc: "HLP format variant"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def hlp_create(output, *files)
      # Ensure format is set (default from Thor option or :hlp)
      format = options[:format] || :hlp

      opts = {
        verbose: options[:verbose],
        compress: options[:compress],
        format: format,
        hlp_format: options[:format],
      }
      run_dispatcher(:create, output, files, **opts)
    end

    # LIT legacy commands
    desc "lit-extract FILE [OUTPUT_DIR]",
         "Extract LIT file (legacy, use: extract --format lit FILE)"
    option :output, type: :string, aliases: "-o", desc: "Output directory"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def lit_extract(file, output_dir = nil)
      opts = { verbose: options[:verbose], output: options[:output],
               format: :lit }
      run_dispatcher(:extract, file, output_dir, **opts)
    end

    desc "lit-info FILE",
         "Show LIT file information (legacy, use: info --format lit FILE)"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def lit_info(file)
      run_with_format(:info, :lit, file, verbose: options[:verbose])
    end

    desc "lit-create OUTPUT FILES...",
         "Create LIT file (legacy, use: create --format lit OUTPUT FILES...)"
    option :compress, type: :boolean, default: true,
                      desc: "Compress files with LZX"
    option :language_id, type: :string,
                         desc: "Language ID (e.g., 0x409 for English)"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def lit_create(output, *files)
      opts = {
        verbose: options[:verbose],
        compress: options[:compress],
        format: :lit,
        language_id: parse_language_id(options[:language_id]),
      }
      run_dispatcher(:create, output, files, **opts)
    end

    # OAB legacy commands
    desc "oab-extract INPUT OUTPUT",
         "Extract OAB file (legacy, use: extract --format oab INPUT --output OUTPUT)"
    option :base, type: :string, desc: "Base file for incremental patch"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def oab_extract(input, output)
      opts = {
        verbose: options[:verbose],
        output: output,
        format: :oab,
        base_file: options[:base],
      }
      run_dispatcher(:extract, input, nil, **opts)
    end

    desc "oab-info FILE",
         "Show OAB file information (legacy, use: info --format oab FILE)"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def oab_info(file)
      run_with_format(:info, :oab, file, verbose: options[:verbose])
    end

    desc "oab-create INPUT OUTPUT",
         "Create OAB file (legacy, use: create --format oab OUTPUT INPUT)"
    option :base, type: :string, desc: "Base file for incremental patch"
    option :block_size, type: :numeric, default: 32_768, desc: "Block size"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def oab_create(input, output)
      opts = {
        verbose: options[:verbose],
        format: :oab,
        block_size: options[:block_size],
        base_file: options[:base],
      }
      run_dispatcher(:create, output, [input], **opts)
    end

    desc "version", "Show version information"
    def version
      puts "Cabriolet version #{Cabriolet::VERSION}"
    end

    private

    # Run command with unified dispatcher
    #
    # @param command [Symbol] Command to execute
    # @param file [String] File path
    # @param args [Array] Additional arguments
    def run_dispatcher(command, file, *args, **options)
      setup_verbose(options[:verbose])

      dispatcher = Commands::CommandDispatcher.new(**options)
      dispatcher.dispatch(command, file, *args, **options)
    end

    # Run command with explicit format override
    #
    # @param command [Symbol] Command to execute
    # @param format [Symbol] Format to force
    # @param file [String] File path
    # @param args [Array] Additional arguments
    def run_with_format(command, format, file, *args, **options)
      setup_verbose(options[:verbose])
      options[:format] = format.to_s

      dispatcher = Commands::CommandDispatcher.new(**options)
      dispatcher.dispatch(command, file, *args, **options)
    end

    # Detect format from output file extension
    #
    # @param output [String] Output file path
    # @param manual_format [String, nil] Manually specified format
    # @return [Symbol] Detected format symbol
    def detect_format_from_output(output, manual_format)
      return manual_format.to_sym if manual_format

      ext = File.extname(output).downcase
      format_map = {
        ".cab" => :cab,
        ".chm" => :chm,
        ".hlp" => :hlp,
        ".lit" => :lit,
        ".oab" => :oab,
        "._" => :szdd, # SZDD ends with underscore
        ".kwj" => :kwaj,
      }

      # Handle SZDD specially (ends with _)
      if output.end_with?("_")
        return :szdd
      end

      format_map[ext] || :cab # Default to CAB
    end

    # Normalize create options for different formats
    #
    # @param options [Hash] Raw options from Thor
    # @return [Hash] Normalized options
    def normalize_create_options(options)
      normalized = {}
      options.each do |key, value|
        next if value.nil?

        case key.to_s
        when "szdd_format"
          normalized[:szdd_format] = value.to_sym
        when "kwaj_compression"
          normalized[:compression] = value
        when "kwaj_filename"
          normalized[:filename] = value
        when "hlp_format"
          normalized[:hlp_format] = value.to_sym
        when "language_id"
          normalized[:language_id] = parse_language_id(value)
        when "lit_version"
          normalized[:version] = value
        when "compress"
          # Keep as-is for HLP/LIT
          normalized[:compress] = value
        else
          normalized[key.to_sym] = value
        end
      end
      normalized
    end

    # Parse language ID from string
    #
    # @param value [String, Integer, nil] Language ID value
    # @return [Integer] Parsed language ID
    def parse_language_id(value)
      return 0x409 if value.nil? # Default to English

      if value.is_a?(Integer)
        value
      elsif value.start_with?("0x")
        value.to_i(16)
      else
        value.to_i
      end
    end

    def setup_verbose(verbose)
      Cabriolet.verbose = verbose
    end
  end
end
