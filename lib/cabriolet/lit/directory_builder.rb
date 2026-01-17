# frozen_string_literal: true

module Cabriolet
  module LIT
    # Builds LIT directory structure with AOLL chunks
    class DirectoryBuilder
      # Chunk size for directory entries (8KB)
      DEFAULT_CHUNK_SIZE = 0x2000

      attr_reader :chunk_size, :entries

      # Initialize directory builder
      #
      # @param chunk_size [Integer] Chunk size for directory entries
      def initialize(chunk_size: DEFAULT_CHUNK_SIZE)
        @chunk_size = chunk_size
        @entries = []
      end

      # Add an entry to the directory
      #
      # @param name [String] Entry name
      # @param section [Integer] Section number
      # @param offset [Integer] Offset within section
      # @param size [Integer] Size in bytes
      def add_entry(name:, section:, offset:, size:)
        @entries << {
          name: name,
          section: section,
          offset: offset,
          size: size,
        }
      end

      # Build the directory structure
      #
      # @return [Hash] Directory structure with entries and metadata
      def build
        {
          entries: @entries,
          chunk_size: @chunk_size,
          num_chunks: calculate_num_chunks,
        }
      end

      # Build AOLL (Archive Object List List) chunk
      #
      # @return [String] Binary AOLL chunk data
      def build_aoll_chunk
        # Build all entry data first
        entries_data = @entries.map { |entry| encode_entry(entry) }.join

        # Calculate quickref offset (starts after entries data)
        quickref_offset = entries_data.bytesize

        # Build AOLL header
        header = Binary::LITStructures::AOLLHeader.new
        header.tag = Binary::LITStructures::Tags::AOLL
        header.quickref_offset = quickref_offset
        header.current_chunk_low = 0
        header.current_chunk_high = 0
        header.prev_chunk_low = 0xFFFFFFFF
        header.prev_chunk_high = 0xFFFFFFFF
        header.next_chunk_low = 0xFFFFFFFF
        header.next_chunk_high = 0xFFFFFFFF
        header.entries_so_far = @entries.size
        header.reserved = 0
        header.chunk_distance = 0
        header.reserved2 = 0

        header.to_binary_s + entries_data
      end

      # Calculate total size needed for directory
      #
      # @return [Integer] Size in bytes
      def calculate_size
        # IFCM header + AOLL chunk + padding
        ifcm_size = Binary::LITStructures::IFCMHeader.new.to_binary_s.bytesize
        aoll_size = build_aoll_chunk.bytesize
        target_size = @chunk_size

        [ifcm_size + aoll_size, target_size].max
      end

      private

      # Calculate number of chunks needed
      #
      # @return [Integer] Number of chunks
      def calculate_num_chunks
        return 1 if @entries.empty?

        total_size = @entries.sum { |e| estimate_entry_size(e) }
        [1, (total_size / @chunk_size.to_f).ceil].max
      end

      # Estimate size of a directory entry
      #
      # @param entry [Hash] Directory entry
      # @return [Integer] Estimated size
      def estimate_entry_size(entry)
        name_size = entry[:name].bytesize
        # Name length (1-5 bytes) + name + section (1-5 bytes) + offset (1-5 bytes) + size (1-5 bytes)
        5 + name_size + 15
      end

      # Encode a directory entry with variable-length integers
      #
      # @param entry [Hash] Directory entry
      # @return [String] Encoded entry data
      def encode_entry(entry)
        data = +""

        # Encode name length and name
        name = entry[:name].dup.force_encoding("UTF-8")
        data += encode_vint(name.bytesize)
        data += name

        # Encode section, offset, size
        data += encode_vint(entry[:section])
        data += encode_vint(entry[:offset])
        data += encode_vint(entry[:size])

        data
      end

      # Write a variable-length integer (MSB = continuation bit)
      #
      # @param value [Integer] Value to encode
      # @return [String] Encoded integer
      def encode_vint(value)
        return [0x00].pack("C") if value.zero?

        bytes = []

        # Extract 7-bit chunks from value
        loop do
          bytes.unshift(value & 0x7F)
          value >>= 7
          break if value.zero?
        end

        # Set MSB on all bytes except the last
        (0...(bytes.size - 1)).each do |i|
          bytes[i] |= 0x80
        end

        bytes.pack("C*")
      end
    end
  end
end
