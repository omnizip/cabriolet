# frozen_string_literal: true

module Cabriolet
  module HLP
    module WinHelp
      # Parser for Windows Help (WinHelp) files
      #
      # Parses Windows Help files (3.x and 4.x formats) used in Windows 3.0+
      # through Windows XP.
      #
      # Format structure:
      # - File Header (28 or 32 bytes depending on version)
      # - Internal File Directory
      # - File Data Blocks (|SYSTEM, |TOPIC, etc.)
      #
      # Magic numbers:
      # - WinHelp 3.x (16-bit): 0x35F3
      # - WinHelp 4.x (32-bit): 0x3F5F0000 (varies)
      class Parser
        attr_reader :io_system

        # Initialize parser
        #
        # @param io_system [System::IOSystem, nil] Custom I/O system or nil for default
        def initialize(io_system = nil)
          @io_system = io_system || System::IOSystem.new
        end

        # Parse a WinHelp file
        #
        # @param filename [String] Path to WinHelp file
        # @return [Models::WinHelpHeader] Parsed header with metadata
        # @raise [Cabriolet::ParseError] if file is not valid WinHelp
        def parse(filename)
          handle = @io_system.open(filename, Constants::MODE_READ)

          begin
            header = parse_file(handle)
            header.filename = filename
            header
          ensure
            @io_system.close(handle)
          end
        end

        private

        # Parse complete WinHelp file structure
        #
        # @param handle [System::FileHandle] Open file handle
        # @return [Models::WinHelpHeader] Parsed header
        # @raise [Cabriolet::ParseError] if parsing fails
        def parse_file(handle)
          # Detect version and parse appropriate header
          version = detect_version(handle)

          case version
          when :winhelp3
            parse_winhelp3(handle)
          when :winhelp4
            parse_winhelp4(handle)
          else
            raise Cabriolet::ParseError, "Unknown WinHelp version"
          end
        end

        # Detect WinHelp version from magic number
        #
        # @param handle [System::FileHandle] Open file handle
        # @return [Symbol] :winhelp3 or :winhelp4
        # @raise [Cabriolet::ParseError] if magic number is invalid
        def detect_version(handle)
          @io_system.seek(handle, 0, Constants::SEEK_START)
          magic_data = @io_system.read(handle, 4)

          raise Cabriolet::ParseError, "File too small for WinHelp header" if magic_data.nil? || magic_data.bytesize < 4

          # Check for WinHelp 3.x (little-endian 16-bit magic: 0x35F3)
          magic_word = magic_data[0..1].unpack1("v")
          return :winhelp3 if magic_word == 0x35F3

          # Check for WinHelp 4.x (little-endian 32-bit magic, low 16 bits: 0x5F3F or 0x3F5F)
          magic_dword = magic_data.unpack1("V")
          return :winhelp4 if (magic_dword & 0xFFFF) == 0x5F3F || (magic_dword & 0xFFFF) == 0x3F5F

          raise Cabriolet::ParseError,
                "Unknown WinHelp magic: 0x#{magic_dword.to_s(16).upcase}"
        end

        # Parse WinHelp 3.x file
        #
        # @param handle [System::FileHandle] Open file handle
        # @return [Models::WinHelpHeader] Parsed header
        def parse_winhelp3(handle)
          @io_system.seek(handle, 0, Constants::SEEK_START)
          header_data = @io_system.read(handle, 28)

          raise Cabriolet::ParseError, "File too small for WinHelp 3.x header" if header_data.bytesize < 28

          binary_header = Binary::HLPStructures::WinHelp3Header.read(header_data)

          # Validate magic
          unless binary_header.magic == 0x35F3
            raise Cabriolet::ParseError, "Invalid WinHelp 3.x magic: 0x#{binary_header.magic.to_s(16)}"
          end

          # Create header model
          header = Models::WinHelpHeader.new(
            version: :winhelp3,
            magic: binary_header.magic,
            directory_offset: binary_header.directory_offset,
            free_list_offset: binary_header.free_list_offset,
            file_size: binary_header.file_size,
          )

          # Parse directory (WinHelp 3.x format: variable-length entries)
          parse_directory_winhelp3(handle, header)

          header
        end

        # Parse WinHelp 4.x file
        #
        # @param handle [System::FileHandle] Open file handle
        # @return [Models::WinHelpHeader] Parsed header
        def parse_winhelp4(handle)
          @io_system.seek(handle, 0, Constants::SEEK_START)
          header_data = @io_system.read(handle, 32)

          raise Cabriolet::ParseError, "File too small for WinHelp 4.x header" if header_data.bytesize < 32

          binary_header = Binary::HLPStructures::WinHelp4Header.read(header_data)

          # Validate magic (lower 16 bits should be 0x5F3F or 0x3F5F)
          magic_val = binary_header.magic.respond_to?(:to_i) ? binary_header.magic.to_i : binary_header.magic
          unless (magic_val & 0xFFFF) == 0x5F3F || (magic_val & 0xFFFF) == 0x3F5F
            raise Cabriolet::ParseError, "Invalid WinHelp 4.x magic: 0x#{magic_val.to_s(16)}"
          end

          # Determine if directory_offset needs +2 adjustment
          # The BinData structure reads 4 bytes for magic, but the actual format has:
          # - 2 bytes: magic (0x5F3F)
          # - 2 bytes: version/flags
          # - 4 bytes: directory_offset
          #
          # If the version field (bytes 2-3) has a non-zero high byte, it's a 2-byte magic format
          # and directory_offset needs +2 adjustment. If version is small (< 256),
          # it's likely a 4-byte magic format where directory_offset is already correct.
          version_bytes = (magic_val >> 16) & 0xFFFF
          needs_offset_adjustment = version_bytes > 255

          # Create header model
          header = Models::WinHelpHeader.new(
            version: :winhelp4,
            magic: binary_header.magic,
            directory_offset: needs_offset_adjustment ? binary_header.directory_offset + 2 : binary_header.directory_offset,
            free_list_offset: binary_header.free_list_offset,
            file_size: binary_header.file_size,
          )

          # Parse directory (WinHelp 4.x format: fixed 12-byte entries)
          parse_directory_winhelp4(handle, header)

          header
        end

        # Parse WinHelp 3.x internal file directory
        #
        # WinHelp 3.x directory structure:
        # - Directory starts at directory_offset
        # - Each entry is variable length:
        #   - 4 bytes: file size
        #   - 2 bytes: starting block number
        #   - Null-terminated filename (padded to even length)
        # - End of directory marked by zero size
        #
        # @param handle [System::FileHandle] Open file handle
        # @param header [Models::WinHelpHeader] Header to populate
        def parse_directory_winhelp3(handle, header)
          return if header.directory_offset.zero?

          dir_start = header.directory_offset
          @io_system.seek(handle, dir_start, Constants::SEEK_START)

          header.internal_files = []

          # Read variable-length directory entries
          loop do
            # Read file size (4 bytes)
            size_data = @io_system.read(handle, 4)
            break if size_data.nil? || size_data.bytesize < 4

            file_size = size_data.unpack1("V")

            # End of directory marker
            break if file_size.zero?

            # Read starting block (2 bytes)
            block_data = @io_system.read(handle, 2)
            break if block_data.nil? || block_data.bytesize < 2
            starting_block = block_data.unpack1("v")

            # Read filename (null-terminated, padded to even)
            filename = +""
            loop do
              byte_data = @io_system.read(handle, 1)
              break if byte_data.nil? || byte_data.empty?

              byte = byte_data.getbyte(0)
              break if byte.zero?

              filename << byte.chr
            end

            # Align to even boundary
            align_read(handle)

            # Skip empty filenames
            next if filename.empty?

            header.internal_files << {
              filename: filename,
              file_size: file_size,
              starting_block: starting_block,
            }
          end
        end

        # Parse WinHelp 4.x internal file directory
        #
        # WinHelp 4.x directory structure:
        # - Directory starts at directory_offset
        # - Can have two formats:
        #   1. Fixed 12-byte entries: size(4) + block(2) + unknown(2) + name_offset(4)
        #   2. Variable-length entries (like WinHelp 3.x): size(4) + block(2) + filename
        #
        # @param handle [System::FileHandle] Open file handle
        # @param header [Models::WinHelpHeader] Header to populate
        # @raise [ParseError] if directory is invalid
        def parse_directory_winhelp4(handle, header)
          return if header.directory_offset.zero?

          dir_start = header.directory_offset
          @io_system.seek(handle, dir_start, Constants::SEEK_START)

          header.internal_files = []

          # Try to detect format by reading first few bytes
          # Check if this looks like variable-length format (filename starts with '|')
          preview = @io_system.read(handle, 20)
          return if preview.nil? || preview.bytesize < 6

          # In variable-length format: bytes 0-3 = size, bytes 4-5 = block, bytes 6+ = filename
          # In fixed format: bytes 0-3 = size, bytes 4-5 = block, bytes 6-7 = unknown, bytes 8-11 = name_offset
          # If byte 6 is part of a filename starting with '|', use variable format
          # The filename starts at byte 6, so check if byte 6 is '|'
          # Actually, filename starts after size(4) + block(2) = byte 6
          if preview.getbyte(6) == 0x7C
            # Variable-length format (inline filenames)
            @io_system.seek(handle, dir_start, Constants::SEEK_START)
            parse_directory_variable(handle, header)
          else
            # Fixed 12-byte format with name_offset
            @io_system.seek(handle, dir_start, Constants::SEEK_START)
            parse_directory_fixed(handle, header)
          end
        end

        # Parse variable-length directory entries (WinHelp 3.x style)
        def parse_directory_variable(handle, header)
          loop do
            # Read file size (4 bytes)
            size_data = @io_system.read(handle, 4)
            break if size_data.nil? || size_data.bytesize < 4

            file_size = size_data.unpack1("V")

            # End of directory marker
            break if file_size.zero?

            # Read starting block (2 bytes)
            block_data = @io_system.read(handle, 2)
            break if block_data.nil? || block_data.bytesize < 2
            starting_block = block_data.unpack1("v")

            # Read filename (null-terminated, padded to even)
            filename = +""
            loop do
              byte_data = @io_system.read(handle, 1)
              break if byte_data.nil? || byte_data.empty?

              byte = byte_data.getbyte(0)
              break if byte.zero?

              filename << byte.chr
            end

            # Align to even boundary
            align_read(handle)

            # Skip empty filenames
            next if filename.empty?

            header.internal_files << {
              filename: filename,
              file_size: file_size,
              starting_block: starting_block,
            }
          end
        end

        # Parse fixed 12-byte directory entries (WinHelp 4.x style with name_offset)
        def parse_directory_fixed(handle, header)
          # Read directory entries
          entries = []
          100.times do # Safety limit
            entry_data = @io_system.read(handle, 12)
            break if entry_data.nil? || entry_data.bytesize < 12

            # Read size as 4-byte LE value (bytes 0-3)
            file_size = entry_data[0..3].unpack1("V")

            # Check for end of directory marker
            break if file_size.zero?

            # Read block as 2-byte LE value (bytes 4-5)
            starting_block = entry_data[4..5].unpack1("v")

            # Read name_offset as 4-byte LE value (bytes 8-11)
            name_offset = entry_data[8..11].unpack1("V")

            entries << {
              file_size: file_size,
              starting_block: starting_block,
              name_offset: name_offset,
            }
          end

          return if entries.empty?

          # Scan for filenames starting after the directory entries
          scan_start = @io_system.tell(handle)
          @io_system.seek(handle, scan_start, Constants::SEEK_START)
          scan_data = @io_system.read(handle, 2000)

          # Find all filenames (null-terminated strings starting with '|')
          filenames = []
          i = 0
          while i < scan_data.bytesize
            # Skip 0xFF filler bytes
            if scan_data.getbyte(i) == 0xFF
              i += 1
              next
            end

            # Check for filename start
            if scan_data.getbyte(i) == 0x7C
              # Read null-terminated string
              filename = +""
              j = i
              while j < scan_data.bytesize
                byte = scan_data.getbyte(j)
                break if byte == 0x00
                filename << byte.chr
                j += 1
              end

              # Valid filename must start with '|' and have content
              if filename.start_with?("|") && filename.length > 1
                filenames << filename
              end

              # Move past this filename
              i = j + 1
            else
              i += 1
            end
          end

          # Match filenames with directory entries
          total_size = entries.empty? ? 0 : entries[0][:file_size]
          base_block = entries.empty? ? 0 : entries[0][:starting_block]

          filenames.each_with_index do |filename, idx|
            if idx < entries.length
              entry = entries[idx]
              header.internal_files << {
                filename: filename,
                file_size: entry[:file_size],
                starting_block: entry[:starting_block],
              }
            else
              # Estimate size and block for additional files
              estimated_size = total_size / filenames.length
              estimated_block = base_block + idx
              header.internal_files << {
                filename: filename,
                file_size: estimated_size,
                starting_block: estimated_block,
              }
            end
          end
        end

        # Read null-terminated string from handle
        #
        # @param handle [System::FileHandle] Open file handle
        # @return [String, nil] String or nil if read fails
        def read_cstring(handle)
          result = +""
          loop do
            byte_data = @io_system.read(handle, 1)
            return nil if byte_data.nil? || byte_data.empty?

            byte = byte_data.getbyte(0)
            break if byte.zero?

            result << byte.chr
          end
          result
        end

        # Align file position (skip padding after filename)
        #
        # @param handle [System::FileHandle] Open file handle
        def align_read(handle)
          # WinHelp aligns directory entries to 2-byte boundaries
          pos = @io_system.tell(handle)
          # If position is odd, read one byte to align
          @io_system.read(handle, 1) if pos.odd?
        end
      end
    end
  end
end
