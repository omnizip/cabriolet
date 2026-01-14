# frozen_string_literal: true

require_relative "../../binary/hlp_structures"
require_relative "../../models/winhelp_header"
require_relative "../../errors"
require_relative "../../system/io_system"
require_relative "../../constants"

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

          if magic_data.nil? || magic_data.bytesize < 4
            raise Cabriolet::ParseError,
                  "File too small for WinHelp header"
          end

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

          if header_data.bytesize < 28
            raise Cabriolet::ParseError,
                  "File too small for WinHelp 3.x header"
          end

          binary_header = Binary::HLPStructures::WinHelp3Header.read(header_data)

          # Validate magic
          unless binary_header.magic == 0x35F3
            raise Cabriolet::ParseError,
                  "Invalid WinHelp 3.x magic: 0x#{binary_header.magic.to_i.to_s(16)}"
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

          if header_data.bytesize < 32
            raise Cabriolet::ParseError,
                  "File too small for WinHelp 4.x header"
          end

          binary_header = Binary::HLPStructures::WinHelp4Header.read(header_data)

          # Validate magic (lower 16 bits should be 0x5F3F or 0x3F5F)
          magic_val = binary_header.magic.respond_to?(:to_i) ? binary_header.magic.to_i : binary_header.magic
          unless (magic_val & 0xFFFF) == 0x5F3F || (magic_val & 0xFFFF) == 0x3F5F
            raise Cabriolet::ParseError,
                  "Invalid WinHelp 4.x magic: 0x#{magic_val.to_s(16)}"
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

        # Parse WinHelp 4.x internal file directory using B+ tree
        #
        # WinHelp 4.x directory structure:
        # - FILEHEADER at directory_offset
        # - BTREEHEADER immediately after FILEHEADER
        # - B+ tree pages containing filename -> file_offset mappings
        #
        # @param handle [System::FileHandle] Open file handle
        # @param header [Models::WinHelpHeader] Header to populate
        # @raise [ParseError] if directory is invalid
        def parse_directory_winhelp4(handle, header)
          return if header.directory_offset.zero?

          # Seek to directory and read FILEHEADER
          @io_system.seek(handle, header.directory_offset, Constants::SEEK_START)
          file_header_data = @io_system.read(handle, 9) # FILEHEADER is 9 bytes

          if file_header_data.nil? || file_header_data.bytesize < 9
            raise Cabriolet::ParseError,
                  "Failed to read FILEHEADER"
          end

          # Read BTREEHEADER (38 bytes according to helpdeco)
          btree_header_data = @io_system.read(handle, 38) # BTREEHEADER is 38 bytes

          if btree_header_data.nil? || btree_header_data.bytesize < 38
            raise Cabriolet::ParseError,
                  "Failed to read BTREEHEADER"
          end

          btree_header = Binary::HLPStructures::WinHelpBTreeHeader.read(btree_header_data)

          # Validate B+ tree magic
          unless btree_header.magic == 0x293B
            raise Cabriolet::ParseError,
                  "Invalid B+ tree magic: 0x#{btree_header.magic.to_i.to_s(16)}"
          end

          # Store first page offset (where B+ tree pages start)
          first_page_offset = @io_system.tell(handle)

          # Parse all files from B+ tree
          header.internal_files = []
          parse_btree_files(handle, header, btree_header, first_page_offset)
        end

        # Parse all files from WinHelp B+ tree
        #
        # @param handle [System::FileHandle] Open file handle
        # @param header [Models::WinHelpHeader] Header to populate
        # @param btree_header [Binary::HLPStructures::WinHelpBTreeHeader] B+ tree header
        # @param first_page_offset [Integer] Offset of first B+ tree page
        def parse_btree_files(handle, header, btree_header, first_page_offset)
          return unless btree_header.total_btree_entries.positive?

          # Start at root page and traverse to first leaf page
          current_page = btree_header.root_page

          # If we have multiple levels, traverse down index pages to find first leaf page
          if btree_header.n_levels > 1
            (btree_header.n_levels - 1).times do
              # Seek to index page
              page_offset = first_page_offset + (current_page * btree_header.page_size)
              @io_system.seek(handle, page_offset, Constants::SEEK_START)

              # Read index header
              index_header_data = @io_system.read(handle, 6)
              break if index_header_data.nil? || index_header_data.bytesize < 6

              # For index pages, the first page is always 0 (leftmost child)
              # The index header is followed by entries: (filename, page_number)
              # We want the leftmost (smallest filename), so we take the first entry's page
              current_page = read_first_page_from_index(handle,
                                                        index_header_data)
              break if current_page.nil?
            end
          end

          # Now read all leaf pages
          loop do
            # Seek to leaf page
            page_offset = first_page_offset + (current_page * btree_header.page_size)
            @io_system.seek(handle, page_offset, Constants::SEEK_START)

            # Read leaf node header
            leaf_header_data = @io_system.read(handle, 8)
            break if leaf_header_data.nil? || leaf_header_data.bytesize < 8

            leaf_header = Binary::HLPStructures::WinHelpBTreeNodeHeader.read(leaf_header_data)

            # Read all entries in this leaf page
            leaf_header.n_entries.times do
              # Read null-terminated filename
              filename = read_cstring(handle)
              break if filename.nil?

              # Read file offset (4-byte LE value)
              offset_data = @io_system.read(handle, 4)
              break if offset_data.nil? || offset_data.bytesize < 4

              file_offset = offset_data.unpack1("V")

              # Skip empty filenames
              next if filename.empty?

              # Read FILEHEADER at file_offset to get file size
              # This will seek away, so save current position first
              current_position = @io_system.tell(handle)
              file_size = read_file_size(handle, file_offset)
              @io_system.seek(handle, current_position, Constants::SEEK_START)

              header.internal_files << {
                filename: filename,
                file_size: file_size,
                file_offset: file_offset, # Store actual offset, not block number
              }
            end

            # Move to next leaf page or exit
            break if leaf_header.next_page == -1

            current_page = leaf_header.next_page
          end
        end

        # Read first page number from index page
        #
        # @param handle [System::FileHandle] Open file handle
        # @param index_header_data [String] Index header data (6 bytes)
        # @return [Integer, nil] First page number or nil on error
        def read_first_page_from_index(handle, _index_header_data)
          # For index pages, we want the leftmost (smallest filename)
          # The index header is followed by entries: (filename, page_number)
          # We read the first filename and then the page number
          filename = read_cstring(handle)
          return nil if filename.nil?

          # Read page number (2-byte LE)
          page_data = @io_system.read(handle, 2)
          return nil if page_data.nil? || page_data.bytesize < 2

          page_data.unpack1("v")
        end

        # Read file size from FILEHEADER at given offset
        #
        # @param handle [System::FileHandle] Open file handle
        # @param file_offset [Integer] Offset of FILEHEADER
        # @return [Integer] File size (UsedSpace from FILEHEADER)
        def read_file_size(handle, file_offset)
          # Seek to FILEHEADER
          @io_system.seek(handle, file_offset, Constants::SEEK_START)

          # Read FILEHEADER (9 bytes)
          file_header_data = @io_system.read(handle, 9)
          return 0 if file_header_data.nil? || file_header_data.bytesize < 9

          file_header = Binary::HLPStructures::WinHelpFileHeader.read(file_header_data)

          # Return UsedSpace (the actual file size)
          file_header.used_space
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
