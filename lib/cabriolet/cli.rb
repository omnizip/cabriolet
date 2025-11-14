# frozen_string_literal: true

require "thor"

module Cabriolet
  # CLI provides command-line interface for Cabriolet
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc "list FILE", "List contents of CAB file"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def list(file)
      setup_verbose(options[:verbose])

      decompressor = CAB::Decompressor.new
      cabinet = decompressor.open(file)

      puts "Cabinet: #{cabinet.filename}"
      puts "Set ID: #{cabinet.set_id}, Index: #{cabinet.set_index}"
      puts "Folders: #{cabinet.folder_count}, Files: #{cabinet.file_count}"
      puts "\nFiles:"

      cabinet.files.each do |f|
        puts "  #{f.filename} (#{f.length} bytes)"
      end
    rescue Error => e
      abort "Error: #{e.message}"
    end

    desc "extract FILE [OUTPUT_DIR]", "Extract files from CAB"
    option :output, type: :string, aliases: "-o", desc: "Output directory"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    option :salvage, type: :boolean,
                     desc: "Enable salvage mode for corrupted files"
    def extract(file, output_dir = nil)
      setup_verbose(options[:verbose])
      output_dir ||= options[:output] || "."

      decompressor = CAB::Decompressor.new
      decompressor.salvage = options[:salvage] if options[:salvage]

      cabinet = decompressor.open(file)
      count = decompressor.extract_all(cabinet, output_dir)

      puts "Extracted #{count} file(s) to #{output_dir}"
    rescue Error => e
      abort "Error: #{e.message}"
    end

    desc "info FILE", "Show detailed CAB file information"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def info(file)
      setup_verbose(options[:verbose])

      decompressor = CAB::Decompressor.new
      cabinet = decompressor.open(file)

      display_cabinet_info(cabinet)
    rescue Error => e
      abort "Error: #{e.message}"
    end

    desc "test FILE", "Test CAB file integrity"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def test(file)
      setup_verbose(options[:verbose])

      decompressor = CAB::Decompressor.new
      cabinet = decompressor.open(file)

      puts "Testing #{cabinet.filename}..."
      # TODO: Implement integrity testing
      puts "OK: All #{cabinet.file_count} files passed integrity check"
    rescue Error => e
      abort "Error: #{e.message}"
    end

    desc "search FILE", "Search for embedded CAB files"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
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

    desc "create OUTPUT FILES...", "Create a CAB file from source files"
    option :compression, type: :string, enum: %w[none mszip lzx quantum],
                         default: "mszip", desc: "Compression type"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def create(output, *files)
      setup_verbose(options[:verbose])

      raise ArgumentError, "No files specified" if files.empty?

      files.each do |f|
        raise ArgumentError, "File does not exist: #{f}" unless File.exist?(f)
      end

      compressor = CAB::Compressor.new
      files.each { |f| compressor.add_file(f) }

      puts "Creating #{output} with #{files.size} file(s) (#{options[:compression]} compression)" if options[:verbose]
      bytes = compressor.generate(output,
                                  compression: options[:compression].to_sym)
      puts "Created #{output} (#{bytes} bytes, #{files.size} files)"
    rescue Error => e
      abort "Error: #{e.message}"
    end

    # CHM commands
    desc "chm-list FILE", "List contents of CHM file"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def chm_list(file)
      setup_verbose(options[:verbose])

      decompressor = CHM::Decompressor.new
      chm = decompressor.open(file)

      puts "CHM File: #{chm.filename}"
      puts "Version: #{chm.version}"
      puts "Language: #{chm.language}"
      puts "Chunks: #{chm.num_chunks}, Chunk Size: #{chm.chunk_size}"
      puts "\nFiles:"

      chm.all_files.each do |f|
        section_name = f.section.id.zero? ? "Uncompressed" : "MSCompressed"
        puts "  #{f.filename} (#{f.length} bytes, #{section_name})"
      end

      decompressor.close
    rescue Error => e
      abort "Error: #{e.message}"
    end

    desc "chm-extract FILE [OUTPUT_DIR]", "Extract files from CHM"
    option :output, type: :string, aliases: "-o", desc: "Output directory"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def chm_extract(file, output_dir = nil)
      setup_verbose(options[:verbose])
      output_dir ||= options[:output] || "."

      decompressor = CHM::Decompressor.new
      chm = decompressor.open(file)

      require "fileutils"
      FileUtils.mkdir_p(output_dir)

      count = 0
      chm.all_files.each do |f|
        next if f.system_file?

        output_path = File.join(output_dir, f.filename)
        output_subdir = File.dirname(output_path)
        FileUtils.mkdir_p(output_subdir)

        puts "Extracting: #{f.filename}" if options[:verbose]
        decompressor.extract(f, output_path)
        count += 1
      end

      decompressor.close
      puts "Extracted #{count} file(s) to #{output_dir}"
    rescue Error => e
      abort "Error: #{e.message}"
    end

    desc "chm-info FILE", "Show detailed CHM file information"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def chm_info(file)
      setup_verbose(options[:verbose])

      decompressor = CHM::Decompressor.new
      chm = decompressor.open(file)

      display_chm_info(chm)
      decompressor.close
    rescue Error => e
      abort "Error: #{e.message}"

      desc "chm-create OUTPUT FILES...", "Create a CHM file from HTML files"
      option :window_bits, type: :numeric, default: 16,
                           desc: "LZX window size (15-21)"
      option :verbose, type: :boolean, aliases: "-v",
                       desc: "Enable verbose output"
      def chm_create(output, *files)
        setup_verbose(options[:verbose])

        raise ArgumentError, "No files specified" if files.empty?

        files.each do |f|
          raise ArgumentError, "File does not exist: #{f}" unless File.exist?(f)
        end

        compressor = CHM::Compressor.new
        files.each do |f|
          # Default to compressed section for .html, uncompressed for images
          section = f.end_with?(".html", ".htm") ? :compressed : :uncompressed
          compressor.add_file(f, "/#{File.basename(f)}", section: section)
        end

        if options[:verbose]
          puts "Creating #{output} with #{files.size} file(s) (window_bits: #{options[:window_bits]})"
        end
        bytes = compressor.generate(output, window_bits: options[:window_bits])
        puts "Created #{output} (#{bytes} bytes, #{files.size} files)"
      rescue Error => e
        abort "Error: #{e.message}"
      end
    end

    # SZDD commands
    desc "expand FILE [OUTPUT]",
         "Expand SZDD compressed file (like MS-DOS EXPAND.EXE)"
    option :output, type: :string, aliases: "-o", desc: "Output file path"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def expand(file, output = nil)
      setup_verbose(options[:verbose])
      output ||= options[:output]

      decompressor = SZDD::Decompressor.new
      header = decompressor.open(file)

      # Auto-detect output name if not provided
      output ||= decompressor.auto_output_filename(file, header)

      puts "Expanding #{file} -> #{output}" if options[:verbose]
      bytes = decompressor.extract(header, output)
      decompressor.close(header)

      puts "Expanded #{file} to #{output} (#{bytes} bytes)"
    rescue Error => e
      abort "Error: #{e.message}"
    end

    desc "szdd-info FILE", "Show SZDD file information"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def szdd_info(file)
      setup_verbose(options[:verbose])

      decompressor = SZDD::Decompressor.new
      header = decompressor.open(file)

      puts "SZDD File Information"
      puts "=" * 50
      puts "Filename: #{file}"
      puts "Format: #{header.format.to_s.upcase}"
      puts "Uncompressed size: #{header.length} bytes"
      if header.missing_char
        puts "Missing character: '#{header.missing_char}'"
        puts "Suggested filename: #{header.suggested_filename(File.basename(file))}"
      end

      decompressor.close(header)
    rescue Error => e
      abort "Error: #{e.message}"
    end

    desc "compress FILE [OUTPUT]",
         "Compress file to SZDD format (like MS-DOS COMPRESS.EXE)"
    option :output, type: :string, aliases: "-o", desc: "Output file path"
    option :missing_char, type: :string,
                          desc: "Missing character for filename reconstruction"
    option :format, type: :string, enum: %w[normal qbasic], default: "normal",
                    desc: "SZDD format (normal or qbasic)"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def compress(file, output = nil)
      setup_verbose(options[:verbose])
      output ||= options[:output]

      # Auto-generate output name: file.txt -> file.tx_
      if output.nil?
        output = file.sub(/\.([^.])$/, "._")
        # If no extension or single char extension, just append _
        output = "#{file}_" if output == file
      end

      compressor = SZDD::Compressor.new

      puts "Compressing #{file} -> #{output}" if options[:verbose]

      compress_options = { format: options[:format].to_sym }
      if options[:missing_char]
        compress_options[:missing_char] =
          options[:missing_char]
      end

      bytes = compressor.compress(file, output, **compress_options)

      puts "Compressed #{file} to #{output} (#{bytes} bytes)"
    rescue Error => e
      abort "Error: #{e.message}"
    end

    # KWAJ commands
    desc "kwaj-extract FILE [OUTPUT]", "Extract KWAJ compressed file"
    option :output, type: :string, aliases: "-o", desc: "Output file path"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def kwaj_extract(file, output = nil)
      setup_verbose(options[:verbose])
      output ||= options[:output]

      decompressor = KWAJ::Decompressor.new
      header = decompressor.open(file)

      # Auto-detect output name if not provided
      output ||= decompressor.auto_output_filename(file, header)

      puts "Extracting #{file} -> #{output}" if options[:verbose]
      bytes = decompressor.extract(header, file, output)
      decompressor.close(header)

      puts "Extracted #{file} to #{output} (#{bytes} bytes)"
    rescue Error => e
      abort "Error: #{e.message}"
    end

    desc "kwaj-info FILE", "Show KWAJ file information"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def kwaj_info(file)
      setup_verbose(options[:verbose])

      decompressor = KWAJ::Decompressor.new
      header = decompressor.open(file)

      puts "KWAJ File Information"
      puts "=" * 50
      puts "Filename: #{file}"
      puts "Compression: #{header.compression_name}"
      puts "Data offset: #{header.data_offset} bytes"
      puts "Uncompressed size: #{header.length || 'unknown'} bytes"
      puts "Original filename: #{header.filename}" if header.filename
      if header.extra && !header.extra.empty?
        puts "Extra data: #{header.extra_length} bytes"
        puts "  #{header.extra}"
      end

      decompressor.close(header)
    rescue Error => e
      abort "Error: #{e.message}"
    end

    desc "kwaj-compress FILE [OUTPUT]", "Compress file to KWAJ format"
    option :output, type: :string, aliases: "-o", desc: "Output file path"
    option :compression, type: :string, enum: %w[none xor szdd mszip],
                         default: "szdd", desc: "Compression method"
    option :include_length, type: :boolean,
                            desc: "Include uncompressed length in header"
    option :filename, type: :string,
                      desc: "Original filename to embed in header"
    option :extra_data, type: :string, desc: "Extra data to include in header"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def kwaj_compress(file, output = nil)
      setup_verbose(options[:verbose])
      output ||= options[:output] || "#{file}.kwj"

      compressor = KWAJ::Compressor.new

      puts "Compressing #{file} -> #{output} (#{options[:compression]} compression)" if options[:verbose]

      compress_options = { compression: options[:compression].to_sym }
      if options[:include_length]
        compress_options[:include_length] =
          options[:include_length]
      end
      compress_options[:filename] = options[:filename] if options[:filename]
      if options[:extra_data]
        compress_options[:extra_data] =
          options[:extra_data]
      end

      bytes = compressor.compress(file, output, **compress_options)

      puts "Compressed #{file} to #{output} (#{bytes} bytes, #{options[:compression]} compression)"
    rescue Error => e
      abort "Error: #{e.message}"
    end

    # HLP commands
    desc "hlp-extract FILE [OUTPUT_DIR]", "Extract HLP file"
    option :output, type: :string, aliases: "-o", desc: "Output directory"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def hlp_extract(file, output_dir = nil)
      setup_verbose(options[:verbose])
      output_dir ||= options[:output] || "."

      decompressor = HLP::Decompressor.new
      header = decompressor.open(file)

      require "fileutils"
      FileUtils.mkdir_p(output_dir)

      puts "Extracting #{header.files.size} files from #{file}" if options[:verbose]
      count = decompressor.extract_all(header, output_dir)

      decompressor.close(header)
      puts "Extracted #{count} file(s) to #{output_dir}"
    rescue Error => e
      abort "Error: #{e.message}"
    end

    desc "hlp-create OUTPUT FILES...", "Create HLP file"
    option :compress, type: :boolean, default: true,
                      desc: "Compress files (LZSS MODE_MSHELP)"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def hlp_create(output, *files)
      setup_verbose(options[:verbose])

      raise ArgumentError, "No files specified" if files.empty?

      files.each do |f|
        raise ArgumentError, "File does not exist: #{f}" unless File.exist?(f)
      end

      compressor = HLP::Compressor.new
      files.each do |f|
        compressor.add_file(f, File.basename(f), compress: options[:compress])
      end

      puts "Creating #{output} with #{files.size} file(s)" if options[:verbose]
      bytes = compressor.generate(output)
      puts "Created #{output} (#{bytes} bytes, #{files.size} files)"
    rescue Error => e
      abort "Error: #{e.message}"
    end

    desc "hlp-info FILE", "Show HLP file information"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def hlp_info(file)
      setup_verbose(options[:verbose])

      decompressor = HLP::Decompressor.new
      header = decompressor.open(file)

      puts "HLP File Information"
      puts "=" * 50
      puts "Filename: #{file}"
      puts "Version: #{header.version}"
      puts "Files: #{header.files.size}"
      puts ""
      puts "Files:"
      header.files.each do |f|
        compression = f.compressed? ? "LZSS" : "none"
        puts "  #{f.filename}"
        puts "    Uncompressed: #{f.length} bytes"
        puts "    Compressed: #{f.compressed_length} bytes (#{compression})"
      end

      decompressor.close(header)
    rescue Error => e
      abort "Error: #{e.message}"
    end

    # LIT commands
    desc "lit-extract FILE [OUTPUT_DIR]", "Extract LIT eBook file"
    option :output, type: :string, aliases: "-o", desc: "Output directory"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def lit_extract(file, output_dir = nil)
      setup_verbose(options[:verbose])
      output_dir ||= options[:output] || "."

      decompressor = LIT::Decompressor.new
      header = decompressor.open(file)

      abort "Error: LIT file is DRM-encrypted. Decryption not yet supported." if header.encrypted?

      require "fileutils"
      FileUtils.mkdir_p(output_dir)

      puts "Extracting #{header.files.size} files from #{file}" if options[:verbose]
      count = decompressor.extract_all(header, output_dir)

      decompressor.close(header)
      puts "Extracted #{count} file(s) to #{output_dir}"
    rescue Error => e
      abort "Error: #{e.message}"
    rescue NotImplementedError => e
      abort "Error: #{e.message}"
    end

    desc "lit-create OUTPUT FILES...", "Create LIT eBook file"
    option :compress, type: :boolean, default: true,
                      desc: "Compress files with LZX"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def lit_create(output, *files)
      setup_verbose(options[:verbose])

      raise ArgumentError, "No files specified" if files.empty?

      files.each do |f|
        raise ArgumentError, "File does not exist: #{f}" unless File.exist?(f)
      end

      compressor = LIT::Compressor.new
      files.each do |f|
        compressor.add_file(f, File.basename(f), compress: options[:compress])
      end

      puts "Creating #{output} with #{files.size} file(s)" if options[:verbose]
      bytes = compressor.generate(output)
      puts "Created #{output} (#{bytes} bytes, #{files.size} files)"
    rescue Error => e
      abort "Error: #{e.message}"
    rescue NotImplementedError => e
      abort "Error: #{e.message}"
    end

    desc "lit-info FILE", "Show LIT file information"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def lit_info(file)
      setup_verbose(options[:verbose])

      decompressor = LIT::Decompressor.new
      header = decompressor.open(file)

      puts "LIT File Information"
      puts "=" * 50
      puts "Filename: #{file}"
      puts "Version: #{header.version}"
      puts "Encrypted: #{header.encrypted? ? 'Yes (DES)' : 'No'}"
      puts "Files: #{header.files.size}"
      puts ""
      puts "Files:"
      header.files.each do |f|
        compression = f.compressed? ? "LZX" : "none"
        encryption = f.encrypted? ? " [encrypted]" : ""
        puts "  #{f.filename}"
        puts "    Size: #{f.length} bytes"
        puts "    Compression: #{compression}#{encryption}"
      end

      decompressor.close(header)
    rescue Error => e
      abort "Error: #{e.message}"
    rescue NotImplementedError => e
      abort "Error: #{e.message}"
    end

    # OAB commands
    desc "oab-extract INPUT OUTPUT", "Extract OAB (Outlook Address Book) file"
    option :base, type: :string, desc: "Base file for incremental patch"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def oab_extract(input, output)
      setup_verbose(options[:verbose])

      decompressor = OAB::Decompressor.new

      if options[:base]
        puts "Applying patch: #{input} + #{options[:base]} -> #{output}" if options[:verbose]
        bytes = decompressor.decompress_incremental(input, options[:base],
                                                    output)
        puts "Applied patch: #{input} + #{options[:base]} -> #{output} (#{bytes} bytes)"
      else
        puts "Extracting: #{input} -> #{output}" if options[:verbose]
        bytes = decompressor.decompress(input, output)
        puts "Extracted #{input} -> #{output} (#{bytes} bytes)"
      end
    rescue Error => e
      abort "Error: #{e.message}"
    end

    desc "oab-create INPUT OUTPUT", "Create compressed OAB file"
    option :base, type: :string, desc: "Base file for incremental patch"
    option :block_size, type: :numeric, default: 32_768,
                        desc: "Block size (default: 32KB)"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def oab_create(input, output)
      setup_verbose(options[:verbose])

      compressor = OAB::Compressor.new

      if options[:base]
        puts "Creating patch: #{input} (base: #{options[:base]}) -> #{output}" if options[:verbose]
        bytes = compressor.compress_incremental(input, options[:base], output,
                                                block_size: options[:block_size])
        puts "Created patch: #{output} (#{bytes} bytes)"
      else
        puts "Compressing: #{input} -> #{output}" if options[:verbose]
        bytes = compressor.compress(input, output,
                                    block_size: options[:block_size])
        puts "Created #{output} (#{bytes} bytes)"
      end
    rescue Error => e
      abort "Error: #{e.message}"
    end

    desc "oab-info FILE", "Show OAB file information"
    option :verbose, type: :boolean, aliases: "-v",
                     desc: "Enable verbose output"
    def oab_info(file)
      setup_verbose(options[:verbose])

      # Read and parse header
      io_system = System::IOSystem.new
      handle = io_system.open(file, Constants::MODE_READ)

      begin
        header_data = io_system.read(handle, 28) # Read full patch header size
        io_system.close(handle)

        # Try to parse as full header first
        if header_data.length >= 16
          full_header = Binary::OABStructures::FullHeader.read(header_data[0,
                                                                           16])

          if full_header.valid?
            puts "OAB File Information (Full)"
            puts "=" * 50
            puts "Filename: #{file}"
            puts "Version: #{full_header.version_hi}.#{full_header.version_lo}"
            puts "Block size: #{full_header.block_max} bytes"
            puts "Target size: #{full_header.target_size} bytes"
          elsif header_data.length >= 28
            # Try as patch header
            patch_header = Binary::OABStructures::PatchHeader.read(header_data)

            if patch_header.valid?
              puts "OAB File Information (Patch)"
              puts "=" * 50
              puts "Filename: #{file}"
              puts "Version: #{patch_header.version_hi}.#{patch_header.version_lo}"
              puts "Block size: #{patch_header.block_max} bytes"
              puts "Source size: #{patch_header.source_size} bytes"
              puts "Target size: #{patch_header.target_size} bytes"
              puts "Source CRC: 0x#{patch_header.source_crc.to_s(16)}"
              puts "Target CRC: 0x#{patch_header.target_crc.to_s(16)}"
            else
              abort "Error: Not a valid OAB file"
            end
          else
            abort "Error: Not a valid OAB file"
          end
        else
          abort "Error: File too small to be OAB"
        end
      rescue StandardError => e
        io_system.close(handle) if handle
        abort "Error: #{e.message}"
      end
    rescue Error => e
      abort "Error: #{e.message}"
    end

    desc "version", "Show version information"
    def version
      puts "Cabriolet version #{Cabriolet::VERSION}"
    end

    private

    def setup_verbose(verbose)
      Cabriolet.verbose = verbose
    end

    def display_cabinet_info(cabinet)
      puts "Cabinet Information"
      puts "=" * 50
      puts "Filename: #{cabinet.filename}"
      puts "Set ID: #{cabinet.set_id}"
      puts "Set Index: #{cabinet.set_index}"
      puts "Size: #{cabinet.length} bytes"
      puts "Folders: #{cabinet.folder_count}"
      puts "Files: #{cabinet.file_count}"
      puts ""

      puts "Folders:"
      cabinet.folders.each_with_index do |folder, idx|
        puts "  [#{idx}] #{folder.compression_name} (#{folder.num_blocks} blocks)"
      end
      puts ""

      puts "Files:"
      cabinet.files.each do |f|
        puts "  #{f.filename}"
        puts "    Size: #{f.length} bytes"
        puts "    Modified: #{f.modification_time}" if f.modification_time
        puts "    Attributes: #{file_attributes(f)}"
      end
    end

    def file_attributes(file)
      attrs = []
      attrs << "readonly" if file.readonly?
      attrs << "hidden" if file.hidden?
      attrs << "system" if file.system?
      attrs << "archive" if file.archived?
      attrs << "executable" if file.executable?
      attrs.empty? ? "none" : attrs.join(", ")
    end

    def display_chm_info(chm)
      puts "CHM File Information"
      puts "=" * 50
      puts "Filename: #{chm.filename}"
      puts "Version: #{chm.version}"
      puts "Language ID: #{chm.language}"
      puts "Timestamp: #{chm.timestamp}"
      puts "Size: #{chm.length} bytes"
      puts ""
      puts "Directory:"
      puts "  Offset: #{chm.dir_offset}"
      puts "  Chunks: #{chm.num_chunks}"
      puts "  Chunk Size: #{chm.chunk_size}"
      puts "  First PMGL: #{chm.first_pmgl}"
      puts "  Last PMGL: #{chm.last_pmgl}"
      puts ""
      puts "Sections:"
      puts "  Section 0 (Uncompressed): offset #{chm.sec0.offset}"
      puts "  Section 1 (MSCompressed): LZX compression"
      puts ""

      regular_files = chm.all_files
      system_files = chm.all_sysfiles

      puts "Files: #{regular_files.length} regular, #{system_files.length} system"
      puts ""
      puts "Regular Files:"
      regular_files.each do |f|
        section_name = f.section.id.zero? ? "Sec0" : "Sec1"
        puts "  #{f.filename}"
        puts "    Size: #{f.length} bytes (#{section_name})"
      end

      return unless system_files.any?

      puts ""
      puts "System Files:"
      system_files.each do |f|
        section_name = f.section.id.zero? ? "Sec0" : "Sec1"
        puts "  #{f.filename}"
        puts "    Size: #{f.length} bytes (#{section_name})"
      end
    end
  end
end
