# frozen_string_literal: true

require_relative "directory_builder"

module Cabriolet
  module LIT
    # Builds piece data for LIT files
    class PieceBuilder
      # Build piece 0 data (file size information)
      #
      # @param file_data [Array<Hash>] File data array
      # @return [String] Binary piece 0 data
      def self.build_piece0(file_data)
        # Calculate total content size
        content_size = file_data.sum { |f| f[:uncompressed_size] }

        data = [Binary::LITStructures::Tags::SIZE_PIECE].pack("V")
        data += [content_size].pack("V")
        data += [0, 0].pack("VV") # High bits, reserved
        data
      end

      # Build piece 1 data (directory IFCM structure)
      #
      # @param directory [Hash] Directory structure from DirectoryBuilder
      # @return [String] Binary piece 1 data
      def self.build_piece1(directory)
        builder = DirectoryBuilder.new(chunk_size: directory[:chunk_size])

        # Build IFCM header
        ifcm = Binary::LITStructures::IFCMHeader.new
        ifcm.tag = Binary::LITStructures::Tags::IFCM
        ifcm.version = 1
        ifcm.chunk_size = directory[:chunk_size]
        ifcm.param = 0x100000
        ifcm.reserved1 = 0xFFFFFFFF
        ifcm.reserved2 = 0xFFFFFFFF
        ifcm.num_chunks = directory[:num_chunks]
        ifcm.reserved3 = 0

        data = ifcm.to_binary_s

        # Build AOLL chunk with directory entries
        directory[:entries].each do |entry|
          builder.add_entry(
            name: entry[:name],
            section: entry[:section],
            offset: entry[:offset],
            size: entry[:size],
          )
        end

        aoll_chunk = builder.build_aoll_chunk
        data += aoll_chunk

        # Pad to fill piece (8KB standard)
        target_size = 8192
        if data.bytesize < target_size
          data += "\x00" * (target_size - data.bytesize)
        end

        data
      end

      # Build piece 2 data (index information)
      #
      # @return [String] Binary piece 2 data
      def self.build_piece2
        # Minimal index data for foundation
        "\x00" * 512
      end
    end
  end
end
