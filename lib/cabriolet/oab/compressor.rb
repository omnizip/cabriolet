# frozen_string_literal: true

require "zlib"

module Cabriolet
  module OAB
    # Compressor for OAB (Outlook Offline Address Book) files
    #
    # OAB files use LZX compression. This compressor can create:
    # - Full files (version 3.1): Complete address book data
    # - Incremental patches (version 3.2): Binary patches (simplified)
    #
    # NOTE: This implementation is based on the OAB format specification
    # derived from libmspack's decompressor. The original libmspack does not
    # implement OAB compression. This is a best-effort implementation that
    # may not produce files identical to Microsoft's OAB generator.
    class Compressor
      attr_reader :io_system
      attr_accessor :buffer_size, :block_size

      # Default buffer size for I/O operations
      DEFAULT_BUFFER_SIZE = 4096

      # Default block size (use 32KB like LZX frames)
      DEFAULT_BLOCK_SIZE = 32_768

      # OAB version numbers
      VERSION_HI = 3
      VERSION_LO_FULL = 1
      VERSION_LO_PATCH = 2

      # Initialize OAB compressor
      #
      # @param io_system [System::IOSystem, nil] I/O system or nil for default
      # @param algorithm_factory [AlgorithmFactory, nil] Custom algorithm factory or nil for default
      def initialize(io_system = nil, algorithm_factory = nil)
        @io_system = io_system || System::IOSystem.new
        @algorithm_factory = algorithm_factory || Cabriolet.algorithm_factory
        @buffer_size = DEFAULT_BUFFER_SIZE
        @block_size = DEFAULT_BLOCK_SIZE
      end

      # Compress a full OAB file
      #
      # @param input_file [String] Input file path
      # @param output_file [String] Compressed OAB output path
      # @param options [Hash] Compression options
      # @option options [Integer] :block_size Block size (default: 32KB)
      # @return [Integer] Bytes written
      # @raise [Error] if compression fails
      def compress(input_file, output_file, **options)
        block_size = options.fetch(:block_size, @block_size)

        input_handle = @io_system.open(input_file, Constants::MODE_READ)
        output_handle = @io_system.open(output_file, Constants::MODE_WRITE)

        begin
          # Get input size
          input_size = @io_system.seek(input_handle, 0, Constants::SEEK_END)
          @io_system.seek(input_handle, 0, Constants::SEEK_START)

          # Write header
          header = Binary::OABStructures::FullHeader.new
          header.version_hi = VERSION_HI
          header.version_lo = VERSION_LO_FULL
          header.block_max = block_size
          header.target_size = input_size

          header_data = header.to_binary_s
          bytes_written = @io_system.write(output_handle, header_data)

          # Compress data in blocks
          remaining = input_size
          while remaining.positive?
            block_bytes = compress_block(
              input_handle, output_handle, block_size, remaining
            )
            bytes_written += block_bytes
            remaining -= [block_size, remaining].min
          end

          bytes_written
        ensure
          @io_system.close(input_handle) if input_handle
          @io_system.close(output_handle) if output_handle
        end
      end

      # Compress data from memory to OAB format
      #
      # @param data [String] Input data to compress
      # @param output_file [String] Compressed OAB output path
      # @param options [Hash] Compression options
      # @option options [Integer] :block_size Block size (default: 32KB)
      # @return [Integer] Bytes written
      # @raise [Error] if compression fails
      def compress_data(data, output_file, **options)
        block_size = options.fetch(:block_size, @block_size)

        input_handle = System::MemoryHandle.new(data, Constants::MODE_READ)
        output_handle = @io_system.open(output_file, Constants::MODE_WRITE)

        begin
          # Write header
          header = Binary::OABStructures::FullHeader.new
          header.version_hi = VERSION_HI
          header.version_lo = VERSION_LO_FULL
          header.block_max = block_size
          header.target_size = data.bytesize

          header_data = header.to_binary_s
          bytes_written = @io_system.write(output_handle, header_data)

          # Compress data in blocks
          remaining = data.bytesize
          while remaining.positive?
            block_bytes = compress_block(
              input_handle, output_handle, block_size, remaining
            )
            bytes_written += block_bytes
            remaining -= [block_size, remaining].min
          end

          bytes_written
        ensure
          @io_system.close(output_handle) if output_handle
        end
      end

      # Create an incremental patch (simplified implementation)
      #
      # This is a simplified patch format that just stores the new data
      # compressed. A full implementation would generate binary diffs.
      #
      # @param input_file [String] New version file path
      # @param base_file [String] Base version file path
      # @param output_file [String] Patch output path
      # @param options [Hash] Compression options
      # @option options [Integer] :block_size Block size (default: 32KB)
      # @return [Integer] Bytes written
      # @raise [Error] if compression fails
      def compress_incremental(input_file, base_file, output_file, **options)
        block_size = options.fetch(:block_size, @block_size)

        # For now, just compress the new file with patch header
        # A full implementation would generate binary diffs
        input_handle = @io_system.open(input_file, Constants::MODE_READ)
        base_handle = @io_system.open(base_file, Constants::MODE_READ)
        output_handle = @io_system.open(output_file, Constants::MODE_WRITE)

        begin
          # Get file sizes
          input_size = @io_system.seek(input_handle, 0, Constants::SEEK_END)
          @io_system.seek(input_handle, 0, Constants::SEEK_START)

          base_size = @io_system.seek(base_handle, 0, Constants::SEEK_END)
          @io_system.seek(base_handle, 0, Constants::SEEK_START)

          # Read base data for CRC
          base_data = @io_system.read(base_handle, base_size)
          base_crc = Zlib.crc32(base_data)

          # Read target data for CRC
          target_data = @io_system.read(input_handle, input_size)
          @io_system.seek(input_handle, 0, Constants::SEEK_START)
          target_crc = Zlib.crc32(target_data)

          # Write patch header
          header = Binary::OABStructures::PatchHeader.new
          header.version_hi = VERSION_HI
          header.version_lo = VERSION_LO_PATCH
          header.block_max = [block_size, 16].max
          header.source_size = base_size
          header.target_size = input_size
          header.source_crc = base_crc
          header.target_crc = target_crc

          header_data = header.to_binary_s
          bytes_written = @io_system.write(output_handle, header_data)

          # Compress data in blocks (simplified - not true patches)
          remaining = input_size
          while remaining.positive?
            block_bytes = compress_patch_block(
              input_handle, output_handle, block_size, remaining, 0
            )
            bytes_written += block_bytes
            remaining -= [block_size, remaining].min
          end

          bytes_written
        ensure
          @io_system.close(input_handle) if input_handle
          @io_system.close(base_handle) if base_handle
          @io_system.close(output_handle) if output_handle
        end
      end

      private

      # Compress a single block
      #
      # @param input_handle [System::FileHandle] Input file handle
      # @param output_handle [System::FileHandle] Output file handle
      # @param block_max [Integer] Maximum block size
      # @param remaining [Integer] Remaining bytes
      # @return [Integer] Bytes written
      def compress_block(input_handle, output_handle, block_max, remaining)
        # Read block data
        block_size = [block_max, remaining].min
        block_data = @io_system.read(input_handle, block_size)

        if block_data.length < block_size
          raise Error,
                "Failed to read block data"
        end

        # Try LZX compression
        compressed_data = compress_with_lzx(block_data)

        # Use uncompressed if compression doesn't help
        if compressed_data.nil? || compressed_data.bytesize >= block_data.bytesize
          # Write uncompressed block
          write_uncompressed_block(output_handle, block_data)
        else
          # Write compressed block
          write_compressed_block(output_handle, block_data, compressed_data)
        end
      end

      # Compress a single patch block (simplified)
      #
      # @param input_handle [System::FileHandle] Input file handle
      # @param output_handle [System::FileHandle] Output file handle
      # @param block_max [Integer] Maximum block size
      # @param remaining [Integer] Remaining bytes
      # @param source_size [Integer] Source block size (0 for simplified)
      # @return [Integer] Bytes written
      def compress_patch_block(input_handle, output_handle, block_max,
                               remaining, source_size)
        # Read block data
        block_size = [block_max, remaining].min
        block_data = @io_system.read(input_handle, block_size)

        if block_data.length < block_size
          raise Error,
                "Failed to read patch block data"
        end

        # Try LZX compression
        compressed_data = compress_with_lzx(block_data)

        # Use compressed data (or original if compression fails)
        patch_data = compressed_data && compressed_data.bytesize < block_data.bytesize ? compressed_data : block_data
        patch_size = patch_data.bytesize

        # Calculate CRC
        crc = Zlib.crc32(block_data)

        # Write patch block header
        block_header = Binary::OABStructures::PatchBlockHeader.new
        block_header.patch_size = patch_size
        block_header.target_size = block_size
        block_header.source_size = source_size
        block_header.crc = crc

        header_data = block_header.to_binary_s
        bytes_written = @io_system.write(output_handle, header_data)

        # Write patch data
        bytes_written += @io_system.write(output_handle, patch_data)

        bytes_written
      end

      # Compress data using LZX
      #
      # @param data [String] Data to compress
      # @return [String, nil] Compressed data or nil if compression failed
      def compress_with_lzx(data)
        return nil if data.empty?

        # Calculate window bits for this block
        window_bits = 17
        window_bits += 1 while window_bits < 25 && (1 << window_bits) < data.bytesize

        # Create memory handles
        input_mem = System::MemoryHandle.new(data, Constants::MODE_READ)
        output_mem = System::MemoryHandle.new("", Constants::MODE_WRITE)

        # Compress with LZX
        compressor = @algorithm_factory.create(
          Constants::COMP_TYPE_LZX,
          :compressor,
          @io_system,
          input_mem,
          output_mem,
          @buffer_size,
          window_bits: window_bits
        )

        compressor.compress

        output_mem.data
      rescue StandardError => e
        warn "[Cabriolet] LZX compression failed: #{e.message}" if Cabriolet.verbose
        nil
      end

      # Write uncompressed block
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param block_data [String] Block data
      # @return [Integer] Bytes written
      def write_uncompressed_block(output_handle, block_data)
        crc = Zlib.crc32(block_data)

        # Write block header
        block_header = Binary::OABStructures::BlockHeader.new
        block_header.flags = 0 # Uncompressed
        block_header.compressed_size = block_data.bytesize
        block_header.uncompressed_size = block_data.bytesize
        block_header.crc = crc

        header_data = block_header.to_binary_s
        bytes_written = @io_system.write(output_handle, header_data)

        # Write block data
        bytes_written += @io_system.write(output_handle, block_data)

        bytes_written
      end

      # Write compressed block
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param original_data [String] Original uncompressed data
      # @param compressed_data [String] Compressed data
      # @return [Integer] Bytes written
      def write_compressed_block(output_handle, original_data, compressed_data)
        crc = Zlib.crc32(original_data)

        # Write block header
        block_header = Binary::OABStructures::BlockHeader.new
        block_header.flags = 1 # LZX compressed
        block_header.compressed_size = compressed_data.bytesize
        block_header.uncompressed_size = original_data.bytesize
        block_header.crc = crc

        header_data = block_header.to_binary_s
        bytes_written = @io_system.write(output_handle, header_data)

        # Write compressed data
        bytes_written += @io_system.write(output_handle, compressed_data)

        bytes_written
      end
    end
  end
end
