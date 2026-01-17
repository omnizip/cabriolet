# frozen_string_literal: true

require_relative "../checksum"
require_relative "../errors"

module Cabriolet
  module CAB
    # Compressor creates CAB files from source files
    # rubocop:disable Metrics/ClassLength
    class Compressor
      attr_reader :io_system, :files, :compression, :set_id, :cabinet_index,
                  :workers

      # Initialize a new compressor
      #
      # @param io_system [System::IOSystem] I/O system for writing
      # @param algorithm_factory [AlgorithmFactory, nil] Custom algorithm factory or nil for default
      # @param workers [Integer] Number of parallel worker threads (default: 1 for sequential)
      def initialize(io_system = nil, algorithm_factory = nil, workers: 1)
        @io_system = io_system || System::IOSystem.new
        @algorithm_factory = algorithm_factory || Cabriolet.algorithm_factory
        @files = []
        @compression = :mszip
        @set_id = rand(0xFFFF)
        @cabinet_index = 0
        @workers = workers
      end

      # Add a file to the cabinet
      #
      # @param source_path [String] Path to source file
      # @param cab_path [String] Path within cabinet (optional)
      # @return [void]
      def add_file(source_path, cab_path = nil)
        unless ::File.exist?(source_path)
          raise ArgumentError,
                "File does not exist: #{source_path}"
        end
        unless ::File.file?(source_path)
          raise ArgumentError,
                "Not a file: #{source_path}"
        end

        @files << {
          source: source_path,
          cab_path: cab_path || ::File.basename(source_path),
        }
      end

      # Generate the cabinet file
      #
      # @param output_file [String] Path to output CAB file
      # @param options [Hash] Options
      # @option options [Symbol] :compression Compression type (:none, :mszip, :lzx, :quantum)
      # @option options [Integer] :set_id Cabinet set ID
      # @option options [Integer] :cabinet_index Cabinet index in set
      # @return [Integer] Bytes written
      def generate(output_file, **options)
        raise ArgumentError, "No files to compress" if @files.empty?

        @compression = options[:compression] || @compression
        @set_id = options[:set_id] || @set_id
        @cabinet_index = options[:cabinet_index] || @cabinet_index

        # Validate and cache compression method value to avoid repeated hash lookups
        @compression_method = compression_type_value

        # Collect file information
        file_infos = collect_file_infos

        # Calculate offsets and sizes
        offsets = calculate_offsets(file_infos)

        # Compress files and collect data blocks
        compressed_data = compress_files(file_infos)

        # Write cabinet file
        write_cabinet(output_file, file_infos, offsets, compressed_data)
      end

      private

      # Collect information about all files to be compressed
      def collect_file_infos
        @files.map do |file_entry|
          source_path = file_entry[:source]
          stat = ::File.stat(source_path)

          {
            source_path: source_path,
            cab_path: file_entry[:cab_path],
            size: stat.size,
            mtime: stat.mtime,
            attribs: calculate_attributes(stat),
          }
        end
      end

      # Calculate file attributes based on file stats
      def calculate_attributes(stat)
        attribs = Constants::ATTRIB_ARCH # Default to archived

        # Read-only
        attribs |= Constants::ATTRIB_READONLY unless stat.writable?

        # Executable (Unix systems)
        attribs |= Constants::ATTRIB_EXEC if stat.executable?

        attribs
      end

      # Calculate all offsets in the cabinet file
      def calculate_offsets(file_infos)
        offset = Constants::CFHEADER_SIZE
        num_folders = 1 # Single folder for now
        file_infos.size

        # Folder entries
        folders_offset = offset
        offset += Constants::CFFOLDER_SIZE * num_folders

        # File entries
        files_offset = offset
        file_infos.each do |info|
          offset += Constants::CFFILE_SIZE
          offset += info[:cab_path].bytesize + 1 # null-terminated
        end

        # Data blocks
        data_offset = offset

        {
          folders_offset: folders_offset,
          files_offset: files_offset,
          data_offset: data_offset,
        }
      end

      # Compress all files and return block data
      def compress_files(file_infos)
        return compress_files_sequential(file_infos) if @workers <= 1

        compress_files_parallel(file_infos)
      end

      # Compress files using parallel workers via Fractor
      def compress_files_parallel(file_infos)
        require_relative "file_compression_work"
        require_relative "file_compression_worker"

        compression_method = @compression_method || compression_type_value

        # Create work items for each file
        work_items = file_infos.map do |info|
          FileCompressionWork.new(
            source_path: info[:source_path],
            compression_method: compression_method,
            block_size: Constants::BLOCK_MAX,
            io_system: @io_system,
            algorithm_factory: @algorithm_factory,
          )
        end

        # Create worker pool
        worker_pool = Fractor::WorkerPool.new(
          FileCompressionWorker,
          num_workers: @workers,
        )

        # Submit all work items and wait for completion
        results = worker_pool.process_work(work_items)

        # Aggregate results in original order
        file_result_map = {}
        total_uncompressed = 0
        all_blocks = []

        results.each do |result|
          if result.error
            raise DecompressionError,
                  "Failed to compress #{result.error[:source_path]}: #{result.error[:message]}"
          end

          file_result_map[result.result[:source_path]] = result.result
          total_uncompressed += result.result[:total_uncompressed]
        end

        # Reorder blocks to match original file order
        file_infos.each do |info|
          file_result = file_result_map[info[:source_path]]
          all_blocks.concat(file_result[:blocks])
        end

        {
          blocks: all_blocks,
          total_uncompressed: total_uncompressed,
        }
      end

      # Compress files sequentially (original implementation)
      def compress_files_sequential(file_infos)
        blocks = []
        total_uncompressed = 0

        file_infos.each do |info|
          file_data = ::File.binread(info[:source_path])
          file_size = file_data.bytesize
          total_uncompressed += file_size

          # Split into blocks of max 32KB
          offset = 0
          while offset < file_size
            remaining = file_size - offset
            chunk_size = [Constants::BLOCK_MAX, remaining].min
            chunk = file_data[offset, chunk_size]

            # Compress chunk
            compressed_chunk = compress_chunk(chunk)

            blocks << {
              uncompressed_size: chunk.bytesize,
              compressed_size: compressed_chunk.bytesize,
              data: compressed_chunk,
            }

            offset += chunk_size
          end
        end

        {
          blocks: blocks,
          total_uncompressed: total_uncompressed,
        }
      end

      # Compress a single chunk of data
      def compress_chunk(data)
        return data if @compression == :none

        # Create temporary handles for compression
        input = System::MemoryHandle.new(data)
        output = System::MemoryHandle.new("", Constants::MODE_WRITE)

        # Use cached compression method value (calculated in generate)
        # Fallback to calculation if not yet cached
        compression_method = @compression_method || compression_type_value

        # Determine window bits based on compression type
        window_bits = case @compression
                      when :lzx then 15
                      when :quantum then 10
                      end

        compressor = @algorithm_factory.create(
          compression_method,
          :compressor,
          @io_system,
          input,
          output,
          data.bytesize,
          window_bits: window_bits,
        )

        compressor.compress
        output.rewind
        output.read
      end

      # Write the complete cabinet file
      def write_cabinet(output_file, file_infos, offsets, compressed_data)
        handle = @io_system.open(output_file, Constants::MODE_WRITE)

        begin
          # Calculate total cabinet size
          cabinet_size = offsets[:data_offset]
          compressed_data[:blocks].each do |block|
            cabinet_size += Constants::CFDATA_SIZE + block[:compressed_size]
          end

          # Write CFHEADER
          write_header(handle, file_infos.size, compressed_data[:blocks].size,
                       offsets[:files_offset], cabinet_size)

          # Write CFFOLDER
          write_folder(handle, compressed_data[:blocks].size,
                       offsets[:data_offset])

          # Write CFFILE entries
          folder_offset = 0
          file_infos.each do |info|
            write_file_entry(handle, info, folder_offset)
            folder_offset += info[:size]
          end

          # Write CFDATA blocks
          compressed_data[:blocks].each do |block|
            write_data_block(handle, block)
          end

          cabinet_size
        ensure
          @io_system.close(handle)
        end
      end

      # Write CFHEADER
      def write_header(handle, num_files, _num_blocks, files_offset,
cabinet_size)
        header = Binary::CFHeader.new
        header.signature = "MSCF"
        header.reserved1 = 0
        header.cabinet_size = cabinet_size
        header.reserved2 = 0
        header.files_offset = files_offset
        header.reserved3 = 0
        header.minor_version = 3
        header.major_version = 1
        header.num_folders = 1 # Single folder for now
        header.num_files = num_files
        header.flags = 0 # No reserved space, no prev/next cabinet
        header.set_id = @set_id
        header.cabinet_index = @cabinet_index

        @io_system.write(handle, header.to_binary_s)
      end

      # Write CFFOLDER
      def write_folder(handle, num_blocks, data_offset)
        folder = Binary::CFFolder.new
        folder.data_offset = data_offset
        folder.num_blocks = num_blocks
        folder.comp_type = compression_type_value

        @io_system.write(handle, folder.to_binary_s)
      end

      # Get compression type value
      def compression_type_value
        {
          none: Constants::COMP_TYPE_NONE,
          mszip: Constants::COMP_TYPE_MSZIP,
          lzx: Constants::COMP_TYPE_LZX,
          quantum: Constants::COMP_TYPE_QUANTUM,
        }.fetch(@compression) do
          raise ArgumentError,
                "Unsupported compression type: #{@compression}"
        end
      end

      # Write CFFILE entry
      def write_file_entry(handle, info, folder_offset)
        file_entry = Binary::CFFile.new
        file_entry.uncompressed_size = info[:size]
        file_entry.folder_offset = folder_offset
        file_entry.folder_index = 0 # Single folder
        file_entry.date, file_entry.time = encode_datetime(info[:mtime])
        file_entry.attribs = info[:attribs]

        @io_system.write(handle, file_entry.to_binary_s)
        @io_system.write(handle, info[:cab_path])
        @io_system.write(handle, "\x00") # null terminator
      end

      # Encode Time object to CAB date/time format
      def encode_datetime(time)
        date_bits = (time.day & 0x1F) |
          ((time.month & 0x0F) << 5) |
          (((time.year - 1980) & 0x7F) << 9)

        time_bits = ((time.sec / 2) & 0x1F) |
          ((time.min & 0x3F) << 5) |
          ((time.hour & 0x1F) << 11)

        [date_bits, time_bits]
      end

      # Write CFDATA block
      def write_data_block(handle, block)
        # Calculate checksum
        checksum = calculate_checksum(block[:data])

        # Create CFDATA header
        cfdata = Binary::CFData.new
        cfdata.checksum = checksum
        cfdata.compressed_size = block[:compressed_size]
        cfdata.uncompressed_size = block[:uncompressed_size]

        # Add header checksum
        header_data = cfdata.to_binary_s
        cfdata.checksum = calculate_checksum(header_data[4, 4], checksum)

        @io_system.write(handle, cfdata.to_binary_s)
        @io_system.write(handle, block[:data])
      end

      # Calculate checksum for data
      # Same algorithm as used in Extractor
      # rubocop:disable Metrics/MethodLength
      def calculate_checksum(data, initial = 0)
        Checksum.calculate(data, initial)
      end
      # rubocop:enable Metrics/MethodLength
    end
    # rubocop:enable Metrics/ClassLength
  end
end
