# frozen_string_literal: true

require "fileutils"

module Cabriolet
  module CAB
    # Extractor handles the extraction of files from cabinets
    class Extractor
      attr_reader :io_system, :decompressor

      # Initialize a new extractor
      #
      # @param io_system [System::IOSystem] I/O system
      # @param decompressor [CAB::Decompressor] Parent decompressor
      def initialize(io_system, decompressor)
        @io_system = io_system
        @decompressor = decompressor
      end

      # Extract a single file from the cabinet
      #
      # @param file [Models::File] File to extract
      # @param output_path [String] Where to write the file
      # @param options [Hash] Extraction options
      # @option options [Boolean] :salvage Enable salvage mode
      # @return [Integer] Number of bytes extracted
      def extract_file(file, output_path, **options)
        salvage = options[:salvage] || @decompressor.salvage
        folder = file.folder

        # Validate file
        raise Cabriolet::ArgumentError, "File has no folder" unless folder

        if file.offset > Constants::LENGTH_MAX
          raise DecompressionError,
                "File offset beyond 2GB limit"
        end

        # Check file length
        filelen = file.length
        if filelen > (Constants::LENGTH_MAX - file.offset)
          unless salvage
            raise DecompressionError,
                  "File length exceeds 2GB limit"
          end

          filelen = Constants::LENGTH_MAX - file.offset

        end

        # Check for merge requirements
        if folder.needs_prev_merge?
          raise DecompressionError,
                "File requires previous cabinet, cabinet set is incomplete"
        end

        # Check file fits within folder
        unless salvage
          max_len = folder.num_blocks * Constants::BLOCK_MAX
          if file.offset > max_len || filelen > (max_len - file.offset)
            raise DecompressionError, "File extends beyond folder data"
          end
        end

        # Create output directory if needed
        output_dir = ::File.dirname(output_path)
        FileUtils.mkdir_p(output_dir) unless ::File.directory?(output_dir)

        # Create input wrapper that reads CFDATA blocks across cabinets
        input_handle = BlockReader.new(@io_system, folder.data,
                                       folder.num_blocks, salvage)

        begin
          # Create output file
          output_fh = @io_system.open(output_path, Constants::MODE_WRITE)

          begin
            # Create decompressor
            decomp = @decompressor.create_decompressor(folder, input_handle,
                                                       output_fh)

            # Skip to file offset if needed
            if file.offset.positive?
              # Decompress and discard bytes before file start
              temp_output = System::MemoryHandle.new("", Constants::MODE_WRITE)
              temp_decomp = @decompressor.create_decompressor(folder,
                                                              input_handle, temp_output)
              temp_decomp.decompress(file.offset)
            end

            # Decompress the file
            decomp.decompress(filelen)

            filelen
          ensure
            output_fh.close
          end
        ensure
          input_handle.close
        end
      end

      # Extract all files from a cabinet
      #
      # @param cabinet [Models::Cabinet] Cabinet to extract from
      # @param output_dir [String] Directory to extract to
      # @param options [Hash] Extraction options
      # @option options [Boolean] :preserve_paths Preserve directory structure (default: true)
      # @option options [Boolean] :set_timestamps Set file modification times (default: true)
      # @option options [Proc] :progress Progress callback
      # @return [Integer] Number of files extracted
      def extract_all(cabinet, output_dir, **options)
        preserve_paths = options.fetch(:preserve_paths, true)
        set_timestamps = options.fetch(:set_timestamps, true)
        progress = options[:progress]

        # Create output directory
        FileUtils.mkdir_p(output_dir) unless ::File.directory?(output_dir)

        count = 0
        cabinet.files.each do |file|
          # Determine output path
          output_path = if preserve_paths
                          ::File.join(output_dir, file.filename)
                        else
                          ::File.join(output_dir,
                                      ::File.basename(file.filename))
                        end

          # Extract file
          extract_file(file, output_path, **options)

          # Set timestamp if requested
          if set_timestamps && file.modification_time
            ::File.utime(file.modification_time, file.modification_time,
                         output_path)
          end

          # Set file permissions based on attributes
          set_file_attributes(output_path, file)

          count += 1
          progress&.call(file, count, cabinet.files.size)
        end

        count
      end

      private

      # Set file attributes based on CAB attributes
      #
      # @param path [String] File path
      # @param file [Models::File] CAB file
      def set_file_attributes(path, file)
        # On Unix systems, set read-only if appropriate
        return unless ::File.exist?(path)

        if file.readonly?
          # Make file read-only
          ::File.chmod(0o444, path)
        elsif file.executable?
          # Make file executable
          ::File.chmod(0o755, path)
        else
          # Default permissions
          ::File.chmod(0o644, path)
        end
      rescue StandardError
        # Ignore errors setting attributes
        nil
      end

      # BlockReader wraps cabinet file handles and reads CFDATA blocks
      # Handles multi-part cabinets by following the FolderData chain
      class BlockReader
        attr_reader :io_system, :current_data, :num_blocks, :salvage,
                    :current_block

        def initialize(io_system, folder_data, num_blocks, salvage)
          @io_system = io_system
          @current_data = folder_data
          @num_blocks = num_blocks
          @salvage = salvage
          @current_block = 0
          @buffer = ""
          @buffer_pos = 0
          @cab_handle = nil

          # Open first cabinet and seek to data offset
          open_current_cabinet
        end

        def read(bytes)
          result = +""

          while result.bytesize < bytes
            # Read more data if buffer is empty
            break if (@buffer_pos >= @buffer.bytesize) && !read_next_block

            # Copy from buffer
            available = @buffer.bytesize - @buffer_pos
            to_copy = [available, bytes - result.bytesize].min

            result << @buffer[@buffer_pos, to_copy]
            @buffer_pos += to_copy
          end

          result
        end

        def seek(_offset, _whence)
          # Not implemented for block reader
          0
        end

        def tell
          0
        end

        def close
          @cab_handle&.close
          @cab_handle = nil
        end

        private

        def read_next_block
          return false if @current_block >= @num_blocks

          # Read blocks, potentially spanning multiple cabinets
          accumulated_data = +""

          loop do
            # Read CFDATA header
            header_data = @cab_handle.read(Constants::CFDATA_SIZE)
            return false if header_data.bytesize != Constants::CFDATA_SIZE

            cfdata = Binary::CFData.read(header_data)

            # Skip reserved block data if present
            if @current_data.cabinet.block_resv.positive?
              @cab_handle.seek(@current_data.cabinet.block_resv, Constants::SEEK_CUR)
            end

            # Validate block sizes
            unless @salvage
              total_size = accumulated_data.bytesize + cfdata.compressed_size
              if total_size > Constants::INPUT_MAX
                raise DecompressionError,
                      "Compressed block size exceeds maximum"
              end

              if cfdata.uncompressed_size > Constants::BLOCK_MAX
                raise DecompressionError,
                      "Uncompressed block size exceeds maximum"
              end
            end

            # Read compressed data
            compressed_data = @cab_handle.read(cfdata.compressed_size)
            return false if compressed_data.bytesize != cfdata.compressed_size

            # Verify checksum if present and not in salvage mode
            if cfdata.checksum.positive? && !@salvage
              # Calculate checksum of data
              data_cksum = calculate_checksum(compressed_data)
              # Calculate checksum of header fields (4 bytes starting at offset 4)
              header_cksum = calculate_checksum(header_data[4, 4], data_cksum)

              if header_cksum != cfdata.checksum
                raise ChecksumError,
                      "Block checksum mismatch"
              end
            end

            # Accumulate data
            accumulated_data << compressed_data

            # If uncompressed_size is 0, this block continues in the next cabinet
            break unless cfdata.uncompressed_size.zero?

            # Move to next cabinet in the chain
            unless advance_to_next_cabinet
              raise DecompressionError,
                    "Block continues but no next cabinet available"
            end
            # Continue reading the next part of the block

            # This is the final part of the block
          end

          # Store in buffer
          @buffer = accumulated_data
          @buffer_pos = 0
          @current_block += 1

          true
        end

        def open_current_cabinet
          @cab_handle&.close
          @cab_handle = @io_system.open(@current_data.cabinet.filename, Constants::MODE_READ)
          @cab_handle.seek(@current_data.offset, Constants::SEEK_START)
        end

        def advance_to_next_cabinet
          # Move to next data segment
          @current_data = @current_data.next_data
          return false unless @current_data

          # Open new cabinet file
          open_current_cabinet
          true
        end

        def calculate_checksum(data, initial = 0)
          cksum = initial
          bytes = data.bytes

          # Process 4-byte chunks
          (bytes.size / 4).times do |i|
            offset = i * 4
            value = bytes[offset] |
              (bytes[offset + 1] << 8) |
              (bytes[offset + 2] << 16) |
              (bytes[offset + 3] << 24)
            cksum ^= value
          end

          # Process remaining bytes
          remainder = bytes.size % 4
          if remainder.positive?
            ul = 0
            offset = bytes.size - remainder

            case remainder
            when 3
              ul |= bytes[offset + 2] << 16
              ul |= bytes[offset + 1] << 8
              ul |= bytes[offset]
            when 2
              ul |= bytes[offset + 1] << 8
              ul |= bytes[offset]
            when 1
              ul |= bytes[offset]
            end

            cksum ^= ul
          end

          cksum & 0xFFFFFFFF
        end
      end
    end
  end
end
