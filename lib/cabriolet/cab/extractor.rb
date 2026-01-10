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

        # State reuse for multi-file extraction (like libmspack self->d)
        @current_folder = nil
        @current_decomp = nil
        @current_input = nil
        @current_offset = 0
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

        # Check if we need to change folder or reset (libmspack lines 1076-1078)
        if ENV['DEBUG_BLOCK']
          $stderr.puts "DEBUG extract_file: Checking reset condition for file #{file.filename} (offset=#{file.offset}, length=#{file.length})"
          $stderr.puts "  @current_folder == folder: #{@current_folder == folder} (current=#{@current_folder.object_id}, new=#{folder.object_id})"
          $stderr.puts "  @current_offset (#{@current_offset}) > file.offset (#{file.offset}): #{@current_offset > file.offset}"
          $stderr.puts "  @current_decomp.nil?: #{@current_decomp.nil?}"
          $stderr.puts "  Reset needed?: #{@current_folder != folder || @current_offset > file.offset || !@current_decomp}"
        end

        if @current_folder != folder || @current_offset > file.offset || !@current_decomp
          if ENV['DEBUG_BLOCK']
            $stderr.puts "DEBUG extract_file: RESETTING state (creating new BlockReader)"
          end

          # Reset state
          @current_input&.close
          @current_input = nil
          @current_decomp = nil

          # Create new input (libmspack lines 1092-1095)
          # This BlockReader will be REUSED across all files in this folder
          @current_input = BlockReader.new(@io_system, folder.data,
                                          folder.num_blocks, salvage)
          @current_folder = folder
          @current_offset = 0

          # Create decompressor ONCE and reuse it (this is the key fix!)
          # The decompressor maintains bitstream state across files
          @current_decomp = @decompressor.create_decompressor(folder, @current_input, nil)
        else
          if ENV['DEBUG_BLOCK']
            $stderr.puts "DEBUG extract_file: NOT resetting (reusing existing BlockReader and decompressor)"
          end
        end

        # Skip ahead if needed (libmspack lines 1130-1134)
        if file.offset > @current_offset
          skip_bytes = file.offset - @current_offset

          # Decompress with NULL output to skip (libmspack line 1130: self->d->outfh = NULL)
          null_output = System::MemoryHandle.new("", Constants::MODE_WRITE)

          # Reuse existing decompressor, change output to NULL
          @current_decomp.instance_variable_set(:@output, null_output)

          # Set output length for LZX frame limiting
          @current_decomp.set_output_length(skip_bytes) if @current_decomp.respond_to?(:set_output_length)

          @current_decomp.decompress(skip_bytes)
          @current_offset += skip_bytes
        end

        # Extract actual file (libmspack lines 1137-1141)
        output_fh = @io_system.open(output_path, Constants::MODE_WRITE)

        begin
          # Reuse existing decompressor, change output to real file
          @current_decomp.instance_variable_set(:@output, output_fh)

          # Set output length for LZX frame limiting
          @current_decomp.set_output_length(filelen) if @current_decomp.respond_to?(:set_output_length)

          @current_decomp.decompress(filelen)
          @current_offset += filelen
        ensure
          output_fh.close
        end

        filelen
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
          # Early return if we've already exhausted all blocks and buffer
          if @current_block >= @num_blocks && @buffer_pos >= @buffer.bytesize
            if ENV['DEBUG_BLOCK']
              $stderr.puts "DEBUG BlockReader.read(#{bytes}): Already exhausted, returning empty"
            end
            return +""
          end

          result = +""

          if ENV['DEBUG_BLOCK']
            $stderr.puts "DEBUG BlockReader.read(#{bytes}): buffer_size=#{@buffer.bytesize} buffer_pos=#{@buffer_pos} block=#{@current_block}/#{@num_blocks}"
          end

          while result.bytesize < bytes
            # Read more data if buffer is empty
            if (@buffer_pos >= @buffer.bytesize) && !read_next_block
              if ENV['DEBUG_BLOCK']
                $stderr.puts "DEBUG BlockReader.read: EXHAUSTED at result.bytesize=#{result.bytesize} (wanted #{bytes})"
              end
              break
            end

            # Copy from buffer
            available = @buffer.bytesize - @buffer_pos
            to_copy = [available, bytes - result.bytesize].min

            result << @buffer[@buffer_pos, to_copy]
            @buffer_pos += to_copy
          end

          if ENV['DEBUG_BLOCK']
            $stderr.puts "DEBUG BlockReader.read: returning #{result.bytesize} bytes"
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
          if ENV['DEBUG_BLOCK']
            $stderr.puts "DEBUG read_next_block: current_block=#{@current_block} num_blocks=#{@num_blocks}"
          end

          if @current_block >= @num_blocks
            if ENV['DEBUG_BLOCK']
              $stderr.puts "DEBUG read_next_block: EXHAUSTED (current_block >= num_blocks)"
            end
            return false
          end

          # Read blocks, potentially spanning multiple cabinets
          accumulated_data = +""

          loop do
            # Read CFDATA header
            if ENV['DEBUG_BLOCK']
              handle_pos = @cab_handle.tell
              $stderr.puts "DEBUG read_next_block: About to read CFDATA header at position #{handle_pos}"
            end

            header_data = @cab_handle.read(Constants::CFDATA_SIZE)

            if ENV['DEBUG_BLOCK']
              $stderr.puts "DEBUG read_next_block: Read #{header_data.bytesize} bytes (expected #{Constants::CFDATA_SIZE})"
            end

            if header_data.bytesize != Constants::CFDATA_SIZE
              if ENV['DEBUG_BLOCK']
                $stderr.puts "DEBUG read_next_block: FAILED - header read returned #{header_data.bytesize} bytes"
              end
              return false
            end

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
            if ENV['DEBUG_BLOCK']
              $stderr.puts "DEBUG read_next_block: About to read #{cfdata.compressed_size} bytes of compressed data"
            end

            compressed_data = @cab_handle.read(cfdata.compressed_size)

            if ENV['DEBUG_BLOCK']
              $stderr.puts "DEBUG read_next_block: Read #{compressed_data.bytesize} bytes of compressed data (expected #{cfdata.compressed_size})"
            end

            if compressed_data.bytesize != cfdata.compressed_size
              if ENV['DEBUG_BLOCK']
                $stderr.puts "DEBUG read_next_block: FAILED - compressed data read returned #{compressed_data.bytesize} bytes"
              end
              return false
            end

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
          if ENV['DEBUG_BLOCK']
            $stderr.puts "DEBUG open_current_cabinet: filename=#{@current_data.cabinet.filename} offset=#{@current_data.offset}"
          end

          @cab_handle&.close
          @cab_handle = @io_system.open(@current_data.cabinet.filename, Constants::MODE_READ)
          @cab_handle.seek(@current_data.offset, Constants::SEEK_START)

          if ENV['DEBUG_BLOCK']
            actual_pos = @cab_handle.tell
            $stderr.puts "DEBUG open_current_cabinet: seeked to position #{actual_pos} (expected #{@current_data.offset})"
          end
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
