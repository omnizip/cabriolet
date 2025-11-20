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

          # Check for WinHelp 3.x (16-bit magic at offset 0)
          magic_word = magic_data[0..1].unpack1("v")
          return :winhelp3 if magic_word == 0x35F3

          # Check for WinHelp 4.x (32-bit magic)
          magic_dword = magic_data.unpack1("V")
          # WinHelp 4.x magic can be 0x3F5F0000 or similar
          return :winhelp4 if (magic_dword & 0xFFFF) == 0x3F5F

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

          # Parse directory
          parse_directory(handle, header)

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

          # Validate magic (lower 16 bits should be 0x3F5F)
          unless (binary_header.magic & 0xFFFF) == 0x3F5F
            raise Cabriolet::ParseError, "Invalid WinHelp 4.x magic: 0x#{binary_header.magic.to_s(16)}"
          end

          # Create header model
          header = Models::WinHelpHeader.new(
            version: :winhelp4,
            magic: binary_header.magic,
            directory_offset: binary_header.directory_offset,
            free_list_offset: binary_header.free_list_offset,
            file_size: binary_header.file_size,
          )

          # Parse directory
          parse_directory(handle, header)

          header
        end

        # Parse internal file directory
        #
        # @param handle [System::FileHandle] Open file handle
        # @param header [Models::WinHelpHeader] Header to populate
        # @raise [Cabriolet::ParseError] if directory is invalid
        def parse_directory(handle, header)
          return if header.directory_offset.zero?

          @io_system.seek(handle, header.directory_offset, Constants::SEEK_START)

          header.internal_files = []

          # Read directory entries until we've read all files
          # Each entry is variable size (4 + 2 + filename length + padding)
          100.times do # Safety limit to prevent infinite loops
            # Try to read file size (first 4 bytes of entry)
            size_data = @io_system.read(handle, 4)
            break if size_data.nil? || size_data.bytesize < 4

            file_size = size_data.unpack1("V")
            break if file_size.zero? # End of directory

            # Read starting block
            block_data = @io_system.read(handle, 2)
            break if block_data.nil? || block_data.bytesize < 2

            starting_block = block_data.unpack1("v")

            # Read filename (null-terminated)
            filename = read_cstring(handle)
            break if filename.nil? || filename.empty?

            # Store file entry
            header.internal_files << {
              filename: filename,
              file_size: file_size,
              starting_block: starting_block,
            }

            # Align to next entry (filenames are aligned to 2-byte boundaries)
            align_read(handle)
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
