# frozen_string_literal: true

module Cabriolet
  module CAB
    # Parser reads and parses CAB file headers
    class Parser
      attr_reader :io_system

      # Initialize a new parser
      #
      # @param io_system [System::IOSystem] I/O system for reading
      def initialize(io_system)
        @io_system = io_system
      end

      # Parse a CAB file and return a Cabinet model
      #
      # @param filename [String] Path to the CAB file
      # @return [Models::Cabinet] Parsed cabinet
      # @raise [ParseError] if the file is not a valid CAB
      def parse(filename)
        handle = @io_system.open(filename, Constants::MODE_READ)
        cabinet = parse_handle(handle, filename)
        @io_system.close(handle)
        cabinet
      end

      # Parse a CAB from an already-open handle
      #
      # @param handle [System::FileHandle, System::MemoryHandle] Open handle
      # @param filename [String] Filename for reference
      # @param offset [Integer] Offset in file where cabinet starts
      # @param salvage [Boolean] Enable salvage mode for corrupted files
      # @param quiet [Boolean] Suppress error messages
      # @return [Models::Cabinet] Parsed cabinet
      # @raise [ParseError] if not a valid CAB
      def parse_handle(handle, filename, offset = 0, salvage = false,
quiet = false)
        @salvage = salvage
        @quiet = quiet

        cabinet = Models::Cabinet.new(filename)
        cabinet.base_offset = offset

        # Seek to cabinet start
        @io_system.seek(handle, offset, Constants::SEEK_START)

        # Read and validate header
        header, folder_resv = read_header(handle, cabinet)
        validate_header(header)
        populate_cabinet_from_header(handle, cabinet, header)

        # Read folders
        read_folders(handle, cabinet, header, folder_resv)

        # Read files
        read_files(handle, cabinet, header, salvage)

        cabinet
      end

      private

      def read_header(handle, cabinet)
        header_data = @io_system.read(handle, Constants::CFHEADER_SIZE)
        raise ParseError, "Cannot read CAB header" if header_data.bytesize < Constants::CFHEADER_SIZE

        header = Binary::CFHeader.read(header_data)

        folder_resv = 0

        # Read reserved header if present
        if header.flags.anybits?(Constants::FLAG_RESERVE_PRESENT)
          resv_data = @io_system.read(handle, Constants::CFHEADER_EXT_SIZE)
          if resv_data.bytesize < Constants::CFHEADER_EXT_SIZE
            raise ParseError,
                  "Cannot read reserved header"
          end

          # Parse reserved sizes
          header_resv = resv_data.unpack1("v") # uint16 header_reserved
          folder_resv = resv_data[2].ord # uint8 folder_reserved
          data_resv = resv_data[3].ord # uint8 data_reserved

          # Store reserved data size in cabinet
          cabinet.set_blocks_info(0, data_resv)

          # Skip reserved header data
          if header_resv.positive?
            @io_system.seek(handle, header_resv,
                            Constants::SEEK_CUR)
          end
        end

        [header, folder_resv]
      end

      def validate_header(header)
        unless header.signature == "MSCF"
          raise ParseError,
                "Invalid CAB signature"
        end

        if !(header.major_version == 1 && header.minor_version == 3) && !@quiet
          @io_system.message(nil, "WARNING; cabinet version is not 1.3")
        end

        if header.num_folders.zero?
          @io_system.message(nil, "no folders in cabinet.") unless @quiet
          raise ParseError, "No folders in cabinet"
        end

        return unless header.num_files.zero?

        @io_system.message(nil, "no files in cabinet.") unless @quiet
        raise ParseError, "No files in cabinet"
      end

      def populate_cabinet_from_header(handle, cabinet, header)
        cabinet.length = header.cabinet_size
        cabinet.set_id = header.set_id
        cabinet.set_index = header.cabinet_index
        cabinet.flags = header.flags

        # Read previous cabinet metadata if present
        if header.flags.anybits?(Constants::FLAG_PREV_CABINET)
          cabinet.prevname = read_string(handle, false)
          cabinet.previnfo = read_string(handle, true)
        end

        # Read next cabinet metadata if present
        return unless header.flags.anybits?(Constants::FLAG_NEXT_CABINET)

        cabinet.nextname = read_string(handle, false)
        cabinet.nextinfo = read_string(handle, true)
      end

      def read_folders(handle, cabinet, header, folder_resv)
        header.num_folders.times do
          # Read folder structure
          folder_data = @io_system.read(handle, Constants::CFFOLDER_SIZE)
          if folder_data.bytesize < Constants::CFFOLDER_SIZE
            raise ParseError,
                  "Cannot read folder entry"
          end

          cf_folder = Binary::CFFolder.read(folder_data)

          # Skip folder reserved space if present
          if folder_resv.positive?
            @io_system.seek(handle, folder_resv,
                            Constants::SEEK_CUR)
          end

          # Create folder model with cabinet and offset
          data_offset = cabinet.base_offset + cf_folder.data_offset
          folder = Models::Folder.new(cabinet, data_offset)
          folder.comp_type = cf_folder.comp_type
          folder.num_blocks = cf_folder.num_blocks

          # Add to cabinet
          cabinet.folders << folder
        end
      end

      def read_files(handle, cabinet, header, salvage = false)
        header.num_files.times do
          # Read file structure
          file_data = @io_system.read(handle, Constants::CFFILE_SIZE)
          raise ParseError, "Cannot read file entry" if file_data.bytesize < Constants::CFFILE_SIZE

          cf_file = Binary::CFFile.read(file_data)

          # Create file model
          file = Models::File.new
          file.length = cf_file.uncompressed_size
          file.offset = cf_file.folder_offset
          file.folder_index = cf_file.folder_index
          file.attribs = cf_file.attribs

          # Parse date and time
          file.parse_datetime(cf_file.date, cf_file.time)

          # Read filename
          begin
            file.filename = read_string(handle, false)
          rescue ParseError
            # In salvage mode, skip bad files
            next if salvage

            raise
          end

          # Link file to folder
          begin
            link_file_to_folder(file, cabinet, cf_file.folder_index,
                                header.num_folders)
          rescue ParseError
            # In salvage mode, skip files with bad folder indices
            next if salvage

            raise
          end

          # Skip if folder linkage failed in salvage mode
          next if file.folder.nil? && salvage

          # Add to cabinet
          cabinet.files << file
        end

        # Ensure we got at least some files
        return unless cabinet.files.empty?

        raise ParseError, "No valid files found in cabinet"
      end

      def link_file_to_folder(file, cabinet, folder_index, num_folders)
        if folder_index < Constants::FOLDER_CONTINUED_FROM_PREV
          # Normal folder index
          unless folder_index < num_folders
            raise ParseError,
                  "Invalid folder index: #{folder_index}"
          end

          file.folder = cabinet.folders[folder_index]

        elsif [Constants::FOLDER_CONTINUED_TO_NEXT, Constants::FOLDER_CONTINUED_PREV_AND_NEXT].include?(folder_index)
          # File continues to next cabinet - use last folder
          file.folder = cabinet.folders.last
        elsif folder_index == Constants::FOLDER_CONTINUED_FROM_PREV
          # File continues from previous cabinet - use first folder
          file.folder = cabinet.folders.first
        end
      end

      def read_string(handle, permit_empty)
        # Save current position before reading
        base_pos = @io_system.tell(handle)

        # Read up to 256 bytes to find null terminator
        buffer = @io_system.read(handle, 256)
        raise ParseError, "Cannot read string" if buffer.nil? || buffer.empty?

        # Find null terminator
        null_pos = buffer.index("\x00")
        raise ParseError, "String not null-terminated" if null_pos.nil?

        if null_pos.zero? && !permit_empty
          raise ParseError,
                "Empty string not permitted"
        end

        # Extract string (without null terminator)
        string = buffer[0...null_pos]

        # Seek to position after null terminator (base_pos + null_pos + 1)
        @io_system.seek(handle, base_pos + null_pos + 1, Constants::SEEK_START)

        string
      end
    end
  end
end
