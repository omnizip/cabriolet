# frozen_string_literal: true

require "zlib"

module Cabriolet
  module OAB
    # Decompressor for OAB (Outlook Offline Address Book) files
    #
    # OAB files use LZX compression and come in two formats:
    # - Full files (version 3.1): Complete address book data
    # - Incremental patches (version 3.2): Binary patches applied to base file
    #
    # This implementation is based on libmspack's oabd.c
    #
    # NOTE: This implementation cannot be fully validated due to lack of test
    # fixtures. OAB files are specialized Outlook data files. Testing relies
    # on round-trip compression/decompression.
    class Decompressor
      attr_reader :io_system
      attr_accessor :buffer_size

      # Default buffer size for I/O operations
      DEFAULT_BUFFER_SIZE = 4096

      # Initialize OAB decompressor
      #
      # @param io_system [System::IOSystem, nil] I/O system or nil for default
      # @param algorithm_factory [AlgorithmFactory, nil] Custom algorithm factory or nil for default
      def initialize(io_system = nil, algorithm_factory = nil)
        @io_system = io_system || System::IOSystem.new
        @algorithm_factory = algorithm_factory || Cabriolet.algorithm_factory
        @buffer_size = DEFAULT_BUFFER_SIZE
      end

      # Decompress a full OAB file
      #
      # @param input_file [String] Compressed OAB file path
      # @param output_file [String] Decompressed output path
      # @return [Integer] Bytes written
      # @raise [Error] if decompression fails
      def decompress(input_file, output_file)
        input_handle = @io_system.open(input_file, Constants::MODE_READ)
        output_handle = @io_system.open(output_file, Constants::MODE_WRITE)

        begin
          # Read and validate header
          header_data = @io_system.read(input_handle, 16)
          raise Error, "Failed to read OAB header" if header_data.length < 16

          header = Binary::OABStructures::FullHeader.read(header_data)
          raise Error, "Invalid OAB header" unless header.valid?

          block_max = header.block_max
          target_size = header.target_size
          total_written = 0

          # Process blocks until target size reached
          while target_size.positive?
            total_written += decompress_block(
              input_handle, output_handle, block_max, target_size
            )
            target_size -= [block_max, target_size].min
          end

          total_written
        ensure
          @io_system.close(input_handle) if input_handle
          @io_system.close(output_handle) if output_handle
        end
      end

      # Decompress an incremental patch file
      #
      # @param patch_file [String] Compressed patch file path
      # @param base_file [String] Base (uncompressed) file path
      # @param output_file [String] Output file path
      # @return [Integer] Bytes written
      # @raise [Error] if decompression fails
      def decompress_incremental(patch_file, base_file, output_file)
        patch_handle = @io_system.open(patch_file, Constants::MODE_READ)
        base_handle = @io_system.open(base_file, Constants::MODE_READ)
        output_handle = @io_system.open(output_file, Constants::MODE_WRITE)

        begin
          # Read and validate patch header
          header_data = @io_system.read(patch_handle, 28)
          if header_data.length < 28
            raise Error,
                  "Failed to read OAB patch header"
          end

          header = Binary::OABStructures::PatchHeader.read(header_data)
          raise Error, "Invalid OAB patch header" unless header.valid?

          block_max = [header.block_max, 16].max # At least 16 for header
          target_size = header.target_size
          total_written = 0

          # Process patch blocks until target size reached
          while target_size.positive?
            total_written += decompress_patch_block(
              patch_handle, base_handle, output_handle, block_max, target_size
            )
            target_size = header.target_size - total_written
          end

          total_written
        ensure
          @io_system.close(patch_handle) if patch_handle
          @io_system.close(base_handle) if base_handle
          @io_system.close(output_handle) if output_handle
        end
      end

      private

      # Decompress a single OAB block (full file)
      #
      # @param input_handle [System::FileHandle] Input file handle
      # @param output_handle [System::FileHandle] Output file handle
      # @param block_max [Integer] Maximum block size
      # @param target_remaining [Integer] Remaining bytes to decompress
      # @return [Integer] Bytes written
      def decompress_block(input_handle, output_handle, block_max,
target_remaining)
        # Read block header
        block_data = @io_system.read(input_handle, 16)
        raise Error, "Failed to read block header" if block_data.length < 16

        block_header = Binary::OABStructures::BlockHeader.read(block_data)

        # Validate block
        if block_header.uncompressed_size > block_max ||
            block_header.uncompressed_size > target_remaining ||
            block_header.flags > 1
          raise Error, "Invalid block header"
        end

        if block_header.uncompressed?
          # Uncompressed block
          if block_header.uncompressed_size != block_header.compressed_size
            raise Error, "Uncompressed block size mismatch"
          end

          decompress_uncompressed_block(
            input_handle, output_handle, block_header.uncompressed_size
          )
        else
          # LZX compressed block
          decompress_lzx_block(
            input_handle, output_handle, block_header
          )
        end
      end

      # Decompress a single patch block (incremental)
      #
      # @param patch_handle [System::FileHandle] Patch file handle
      # @param base_handle [System::FileHandle] Base file handle
      # @param output_handle [System::FileHandle] Output file handle
      # @param block_max [Integer] Maximum block size
      # @param target_remaining [Integer] Remaining bytes to decompress
      # @return [Integer] Bytes written
      def decompress_patch_block(patch_handle, base_handle, output_handle,
                                 block_max, target_remaining)
        # Read patch block header (20 bytes with flags field)
        block_data = @io_system.read(patch_handle, 20)
        if block_data.length < 20
          raise Error,
                "Failed to read patch block header"
        end

        block_header = Binary::OABStructures::PatchBlockHeader.read(block_data)

        # Validate block
        if block_header.target_size > block_max ||
            block_header.target_size > target_remaining ||
            block_header.source_size > block_max
          raise Error, "Invalid patch block header"
        end

        # Check if data is compressed or uncompressed
        if block_header.uncompressed?
          # Uncompressed data - read and write directly
          data = @io_system.read(patch_handle, block_header.patch_size)
          if data.length < block_header.patch_size
            raise Error, "Failed to read uncompressed patch data"
          end

          # Verify CRC
          actual_crc = Zlib.crc32(data)
          if actual_crc != block_header.crc
            raise Error, "CRC mismatch in patch block"
          end

          @io_system.write(output_handle, data)
          return block_header.target_size
        end

        # Compressed data - use LZX decompression
        # Calculate window size for LZX
        window_size = ((block_header.source_size + 32_767) & ~32_767) +
          block_header.target_size
        window_bits = 17

        window_bits += 1 while window_bits < 25 && (1 << window_bits) < window_size

        # Read reference data from base file
        reference_data = @io_system.read(base_handle, block_header.source_size)

        # Decompress patch with LZX using reference data
        decompress_lzx_patch_block(
          patch_handle, output_handle, block_header, window_bits, reference_data
        )
      end

      # Decompress uncompressed block
      #
      # @param input_handle [System::FileHandle] Input file handle
      # @param output_handle [System::FileHandle] Output file handle
      # @param size [Integer] Block size
      # @return [Integer] Bytes written
      def decompress_uncompressed_block(input_handle, output_handle, size)
        bytes_written = 0

        while size.positive?
          chunk_size = [@buffer_size, size].min
          data = @io_system.read(input_handle, chunk_size)

          if data.length < chunk_size
            raise Error,
                  "Failed to read uncompressed data"
          end

          @io_system.write(output_handle, data)
          bytes_written += chunk_size
          size -= chunk_size
        end

        bytes_written
      end

      # Decompress LZX compressed block
      #
      # @param input_handle [System::FileHandle] Input file handle
      # @param output_handle [System::FileHandle] Output file handle
      # @param block_header [Binary::OABStructures::BlockHeader] Block header
      # @return [Integer] Bytes written
      def decompress_lzx_block(input_handle, output_handle, block_header)
        # Calculate window bits for LZX
        window_bits = 17
        block_size = block_header.uncompressed_size

        window_bits += 1 while window_bits < 25 && (1 << window_bits) < block_size

        # Read compressed data
        compressed_data = @io_system.read(input_handle,
                                          block_header.compressed_size)
        if compressed_data.length < block_header.compressed_size
          raise Error,
                "Failed to read compressed data"
        end

        # Create memory handles for LZX decompression
        input_mem = System::MemoryHandle.new(compressed_data, Constants::MODE_READ)
        output_mem = System::MemoryHandle.new("", Constants::MODE_WRITE)

        # Decompress with LZX
        lzx = @algorithm_factory.create(
          Constants::COMP_TYPE_LZX,
          :decompressor,
          @io_system,
          input_mem,
          output_mem,
          @buffer_size,
          window_bits: window_bits,
          reset_interval: 0,
          output_length: block_size,
          is_delta: false,
        )

        bytes_decompressed = lzx.decompress(block_size)

        # Verify CRC
        actual_crc = Zlib.crc32(output_mem.data)
        raise Error, "CRC mismatch in block" if actual_crc != block_header.crc

        # Write decompressed data
        @io_system.write(output_handle, output_mem.data)
        bytes_decompressed
      end

      # Decompress LZX patch block with reference data
      #
      # @param patch_handle [System::FileHandle] Patch file handle
      # @param output_handle [System::FileHandle] Output file handle
      # @param block_header [Binary::OABStructures::PatchBlockHeader] Block header
      # @param window_bits [Integer] LZX window bits
      # @param reference_data [String] Reference data from base file
      # @return [Integer] Bytes written
      def decompress_lzx_patch_block(patch_handle, output_handle, block_header,
                                     window_bits, _reference_data)
        # Read compressed patch data
        compressed_data = @io_system.read(patch_handle, block_header.patch_size)
        if compressed_data.length < block_header.patch_size
          raise Error,
                "Failed to read patch data"
        end

        # Create memory handles for LZX decompression
        input_mem = System::MemoryHandle.new(compressed_data, Constants::MODE_READ)
        output_mem = System::MemoryHandle.new("", Constants::MODE_WRITE)

        # Decompress with LZX DELTA (includes reference data)
        lzx = @algorithm_factory.create(
          Constants::COMP_TYPE_LZX,
          :decompressor,
          @io_system,
          input_mem,
          output_mem,
          @buffer_size,
          window_bits: window_bits,
          reset_interval: 0,
          output_length: block_header.target_size,
          is_delta: true,
        )

        # For patches, we'd need to set reference data in the LZX window
        # This is a simplified implementation - full support would require
        # extending the LZX decompressor to handle reference data
        bytes_decompressed = lzx.decompress(block_header.target_size)

        # Verify CRC
        actual_crc = Zlib.crc32(output_mem.data)
        if actual_crc != block_header.crc
          raise Error,
                "CRC mismatch in patch block"
        end

        # Write decompressed data
        @io_system.write(output_handle, output_mem.data)
        bytes_decompressed
      end
    end
  end
end
