# frozen_string_literal: true

module Cabriolet
  module CAB
    # Decompressor is the main interface for CAB file operations
    class Decompressor
      attr_reader :io_system, :parser
      attr_accessor :buffer_size, :fix_mszip, :salvage, :search_buffer_size

      # Initialize a new CAB decompressor
      #
      # @param io_system [System::IOSystem, nil] Custom I/O system or nil for default
      # @param algorithm_factory [AlgorithmFactory, nil] Custom algorithm factory or nil for default
      def initialize(io_system = nil, algorithm_factory = nil)
        @io_system = io_system || System::IOSystem.new
        @algorithm_factory = algorithm_factory || Cabriolet.algorithm_factory
        @parser = Parser.new(@io_system)
        @buffer_size = Cabriolet.default_buffer_size
        @fix_mszip = false
        @salvage = false
        @search_buffer_size = 32_768
      end

      # Open and parse a CAB file
      #
      # @param filename [String] Path to the CAB file
      # @return [Models::Cabinet] Parsed cabinet
      # @raise [ParseError] if the file is not a valid CAB
      def open(filename)
        @parser.parse(filename)
      end

      # Extract a single file from the cabinet
      #
      # @param file [Models::File] File to extract
      # @param output_path [String] Where to write the file
      # @param options [Hash] Extraction options
      # @return [Integer] Number of bytes extracted
      def extract_file(file, output_path, **options)
        extractor = Extractor.new(@io_system, self)
        extractor.extract_file(file, output_path, **options)
      end

      # Extract all files from the cabinet
      #
      # @param cabinet [Models::Cabinet] Cabinet to extract from
      # @param output_dir [String] Directory to extract to
      # @param options [Hash] Extraction options
      # @return [Integer] Number of files extracted
      def extract_all(cabinet, output_dir, **options)
        extractor = Extractor.new(@io_system, self)
        extractor.extract_all(cabinet, output_dir, **options)
      end

      # Create appropriate decompressor for a folder
      #
      # @param folder [Models::Folder] Folder to create decompressor for
      # @param input [System::FileHandle, System::MemoryHandle] Input handle
      # @param output [System::FileHandle, System::MemoryHandle] Output handle
      # @return [Decompressors::Base] Appropriate decompressor instance
      def create_decompressor(folder, input, output)
        @algorithm_factory.create(
          folder.compression_method,
          :decompressor,
          @io_system,
          input,
          output,
          @buffer_size,
          fix_mszip: @fix_mszip,
          salvage: @salvage,
          window_bits: folder.compression_level
        )
      end

      # Append a cabinet to another, merging their folders and files
      #
      # @param cabinet [Models::Cabinet] The left cabinet
      # @param next_cabinet [Models::Cabinet] The cabinet to append
      # @return [Boolean] true if successful
      # @raise [ArgumentError] if cabinets cannot be merged
      def append(cabinet, next_cabinet)
        merge_cabinets(cabinet, next_cabinet)
      end

      # Prepend a cabinet to another, merging their folders and files
      #
      # @param cabinet [Models::Cabinet] The right cabinet
      # @param prev_cabinet [Models::Cabinet] The cabinet to prepend
      # @return [Boolean] true if successful
      # @raise [ArgumentError] if cabinets cannot be merged
      def prepend(cabinet, prev_cabinet)
        merge_cabinets(prev_cabinet, cabinet)
      end

      # Search for embedded CAB files within a file
      #
      # @param filename [String] Path to file to search
      # @return [Models::Cabinet, nil] First cabinet found, or nil if none found
      def search(filename)
        search_buf = Array.new(@search_buffer_size)
        first_cabinet = nil
        link_cabinet = nil
        first_len = 0
        false_cabs = 0

        handle = @io_system.open(filename, Constants::MODE_READ)
        file_length = handle.size

        # Check for InstallShield header at start of file
        if file_length >= 4
          header = @io_system.read(handle, 4)
          @io_system.seek(handle, 0, Constants::SEEK_START)
          if header.unpack1("V") == 0x28635349
            @io_system.message(handle, "WARNING; found InstallShield header. Use unshield " \
                                       "(https://github.com/twogood/unshield) to unpack this file")
          end
        end

        offset = 0
        while offset < file_length
          # Calculate read length
          length = [file_length - offset, @search_buffer_size].min

          # Read chunk
          @io_system.seek(handle, offset, Constants::SEEK_START)
          bytes_read = @io_system.read(handle, length)
          break if bytes_read.nil? || bytes_read.empty?

          search_buf[0, bytes_read.bytesize] = bytes_read.bytes

          # Search for cabinets in this chunk
          cab_offset = find_cabinet_in_buffer(search_buf, bytes_read.size,
                                              offset, handle, filename, file_length)

          if cab_offset
            # Try to parse cabinet at this offset
            cabinet = try_parse_cab_at_offset(handle, filename, cab_offset)

            if cabinet
              # Capture first cabinet length
              first_len = cabinet.length if cab_offset.zero?

              # Link into list
              if first_cabinet.nil?
                first_cabinet = cabinet
              else
                link_cabinet.next = cabinet
              end
              link_cabinet = cabinet

              # Continue searching after this cabinet
              offset = cab_offset + cabinet.length
            else
              false_cabs += 1
              # Restart search after signature
              offset = cab_offset + 4
            end
          else
            # No cabinet found in this chunk, move to next
            offset += length
          end
        end

        @io_system.close(handle)

        # Warn about truncated/extra data
        if first_len.positive? && first_len != file_length && (first_cabinet.nil? || first_cabinet.base_offset.zero?)
          if first_len < file_length
            @io_system.message(handle,
                               "WARNING; possible #{file_length - first_len} extra bytes at end of file.")
          else
            @io_system.message(handle,
                               "WARNING; file possibly truncated by #{first_len - file_length} bytes.")
          end
        end

        if false_cabs.positive? && Cabriolet.verbose
          @io_system.message(handle,
                             "#{false_cabs} false cabinets found")
        end

        first_cabinet
      rescue StandardError
        @io_system.close(handle) if handle
        raise
      end

      private

      # Check if two folders can be merged
      #
      # @param left_folder [Models::Folder] Last folder of left cabinet
      # @param right_folder [Models::Folder] First folder of right cabinet
      # @return [Boolean] true if folders can be merged
      def can_merge_folders?(left_folder, right_folder)
        # Check compression type matches
        unless left_folder.comp_type == right_folder.comp_type
          @io_system.message("Folder merge: compression type mismatch")
          return false
        end

        # Check total blocks won't exceed maximum
        total_blocks = left_folder.num_blocks + right_folder.num_blocks
        if total_blocks > Constants::FOLDER_MAX
          @io_system.message("Folder merge: too many data blocks (#{total_blocks} > #{Constants::FOLDER_MAX})")
          return false
        end

        # Check both folders have merge files
        left_files = left_folder.merge_next
        right_files = right_folder.merge_prev

        unless left_files && right_files
          @io_system.message("Folder merge: one cabinet has no files to merge")
          return false
        end

        # Verify files match by offset and length
        matching = false
        left_file = left_files

        while left_file
          right_file = right_files
          while right_file
            if left_file.offset == right_file.offset && left_file.length == right_file.length
              matching = true
              break
            end
            right_file = right_file.next_file
          end

          @io_system.message("WARNING; merged file #{left_file.filename} not listed in both cabinets") unless matching

          left_file = left_file.next_file
        end

        matching
      end

      # Merge two cabinets together
      #
      # @param left_cab [Models::Cabinet] The left cabinet
      # @param right_cab [Models::Cabinet] The right cabinet
      # @return [Boolean] true if successful
      # @raise [ArgumentError] if cabinets cannot be merged
      def merge_cabinets(left_cab, right_cab)
        # Basic validation
        unless left_cab && right_cab
          raise ArgumentError,
                "Both cabinets must be provided"
        end
        if left_cab == right_cab
          raise ArgumentError,
                "Cannot merge a cabinet with itself"
        end
        if left_cab.next_cabinet || right_cab.prev_cabinet
          raise ArgumentError,
                "Cabinets already joined"
        end

        # Check for circular references
        cab = left_cab.prev_cabinet
        while cab
          if cab == right_cab
            raise ArgumentError,
                  "Circular cabinet chain detected"
          end

          cab = cab.prev_cabinet
        end

        cab = right_cab.next_cabinet
        while cab
          if cab == left_cab
            raise ArgumentError,
                  "Circular cabinet chain detected"
          end

          cab = cab.next_cabinet
        end

        # Warn about mismatched set IDs or indices
        @io_system.message("WARNING; merged cabinets with differing Set IDs") if left_cab.set_id != right_cab.set_id

        @io_system.message("WARNING; merged cabinets with odd order") if left_cab.set_index > right_cab.set_index

        # Find last folder of left cabinet and first folder of right cabinet
        left_folder = left_cab.folders.last
        right_folder = right_cab.folders.first

        # Check if folders need merging
        if left_folder.merge_next && right_folder.merge_prev
          # Folders need merging - validate they can be merged
          unless can_merge_folders?(
            left_folder, right_folder
          )
            raise DataFormatError,
                  "Folders cannot be merged"
          end

          # Create new FolderData for right folder's data
          new_data = Models::FolderData.new(right_folder.data.cabinet,
                                            right_folder.data.offset)

          # Append to left folder's data chain
          data_tail = left_folder.data
          data_tail = data_tail.next_data while data_tail.next_data
          data_tail.next_data = new_data

          # Copy any additional data segments from right folder
          next_data = right_folder.data.next_data
          while next_data
            new_data.next_data = Models::FolderData.new(next_data.cabinet,
                                                        next_data.offset)
            new_data = new_data.next_data
            next_data = next_data.next_data
          end

          # Update block count (subtract 1 because blocks are shared at boundary)
          left_folder.num_blocks += right_folder.num_blocks - 1

          # Update merge_next pointer
          # Special case: if right folder merges both ways, keep left's merge_next
          if right_folder.merge_next.nil? || right_folder.merge_next.folder != right_folder
            left_folder.merge_next = right_folder.merge_next
          end

          # Link remaining folders from right cabinet (skip the merged first folder)
          left_cab.folders.concat(right_cab.folders[1..]) if right_folder.next_folder

          # Link files from right cabinet
          left_cab.files.concat(right_cab.files)

          # Remove duplicate files that belong to the merged right folder
          left_cab.files.reject! { |file| file.folder == right_folder }
        else
          # No folder merge needed - just link them
          left_cab.folders.concat(right_cab.folders)
          left_cab.files.concat(right_cab.files)
        end

        # Link cabinets
        left_cab.next_cabinet = right_cab
        right_cab.prev_cabinet = left_cab

        # Update all cabinets in the set to share the same file and folder lists
        cab = left_cab.prev_cabinet
        while cab
          cab.files = left_cab.files
          cab.folders = left_cab.folders
          cab = cab.prev_cabinet
        end

        cab = left_cab.next_cabinet
        while cab
          cab.files = left_cab.files
          cab.folders = left_cab.folders
          cab = cab.next_cabinet
        end

        true
      end

      # Find cabinet signature in buffer using state machine
      #
      # @param buf [Array<Integer>] Search buffer
      # @param length [Integer] Valid data length in buffer
      # @param base_offset [Integer] Offset of buffer start in file
      # @param handle [IO] File handle
      # @param filename [String] Filename
      # @param file_length [Integer] Total file length
      # @return [Integer, nil] Offset of cabinet in file, or nil
      def find_cabinet_in_buffer(buf, length, base_offset, _handle, _filename,
file_length)
        state = 0
        cablen_u32 = 0
        foffset_u32 = 0
        i = 0

        while i < length
          case state
          when 0
            # Look for 'M' (0x4D)
            i += 1 while i < length && buf[i] != 0x4D
            state = 1 if i < length
            i += 1
          when 1
            # Check for 'S' (0x53)
            state = buf[i] == 0x53 ? 2 : 0
            i += 1
          when 2
            # Check for 'C' (0x43)
            state = buf[i] == 0x43 ? 3 : 0
            i += 1
          when 3
            # Check for 'F' (0x46)
            state = buf[i] == 0x46 ? 4 : 0
            i += 1
          when 4, 5, 6, 7
            # Skip bytes 4-7
            state += 1
            i += 1
          when 8
            # Byte 8: cabinet length (LSB)
            cablen_u32 = buf[i]
            state += 1
            i += 1
          when 9
            # Byte 9
            cablen_u32 |= buf[i] << 8
            state += 1
            i += 1
          when 10
            # Byte 10
            cablen_u32 |= buf[i] << 16
            state += 1
            i += 1
          when 11
            # Byte 11
            cablen_u32 |= buf[i] << 24
            state += 1
            i += 1
          when 12, 13, 14, 15
            # Skip bytes 12-15
            state += 1
            i += 1
          when 16
            # Byte 16: files offset (LSB)
            foffset_u32 = buf[i]
            state += 1
            i += 1
          when 17
            # Byte 17
            foffset_u32 |= buf[i] << 8
            state += 1
            i += 1
          when 18
            # Byte 18
            foffset_u32 |= buf[i] << 16
            state += 1
            i += 1
          when 19
            # Byte 19: complete header read
            foffset_u32 |= buf[i] << 24

            # Calculate cabinet offset in file
            caboff = base_offset + i - 19

            # Validate this looks like a real cabinet
            return caboff if validate_cabinet_signature(foffset_u32,
                                                        cablen_u32, caboff, file_length)

            # Not valid, restart search after "MSCF"
            return nil
          end
        end

        nil
      end

      # Validate that signature looks like a real cabinet
      #
      # @param foffset_u32 [Integer] Files offset from header
      # @param cablen_u32 [Integer] Cabinet length from header
      # @param caboff [Integer] Offset of cabinet in file
      # @param file_length [Integer] Total file length
      # @return [Boolean] true if looks valid
      def validate_cabinet_signature(foffset_u32, cablen_u32, caboff,
file_length)
        # Files offset must be less than cabinet length
        return false if foffset_u32 >= cablen_u32

        # Offset + files offset must be roughly within file
        return false if (caboff + foffset_u32) >= (file_length + 32)

        # In salvage mode, allow garbage length
        # Otherwise, offset + length must be roughly within file
        return false if !@salvage && (caboff + cablen_u32) >= (file_length + 32)

        true
      end

      # Try to parse a cabinet at the given offset
      #
      # @param handle [IO] File handle
      # @param filename [String] Filename
      # @param offset [Integer] Offset in file
      # @return [Models::Cabinet, nil] Cabinet if successful, nil otherwise
      def try_parse_cab_at_offset(handle, filename, offset)
        # Try parsing in quiet mode (suppress errors)
        old_verbose = Cabriolet.verbose
        Cabriolet.verbose = false

        begin
          parser = Parser.new(@io_system)
          parser.parse_handle(handle, filename, offset, @salvage, true)
        rescue StandardError
          nil
        ensure
          Cabriolet.verbose = old_verbose
        end
      end
    end
  end
end
