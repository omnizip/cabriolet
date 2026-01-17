# frozen_string_literal: true

module Cabriolet
  module LIT
    # Writes LIT headers to output
    class HeaderWriter
      # Initialize header writer
      #
      # @param io_system [System::IOSystem] I/O system for writing
      def initialize(io_system)
        @io_system = io_system
      end

      # Write primary header
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param structure [Hash] LIT structure
      # @return [Integer] Bytes written
      def write_primary_header(output_handle, structure)
        header = Binary::LITStructures::PrimaryHeader.new
        header.signature = Binary::LITStructures::SIGNATURE
        header.version = structure[:version]
        header.header_length = 40
        header.num_pieces = 5
        header.secondary_header_length = structure[:secondary_header][:length]
        header.header_guid = structure[:header_guid]

        header_data = header.to_binary_s
        @io_system.write(output_handle, header_data)
      end

      # Write piece structures
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param pieces [Array<Hash>] Pieces array
      # @return [Integer] Bytes written
      def write_piece_structures(output_handle, pieces)
        total_bytes = 0

        pieces.each do |piece|
          piece_struct = Binary::LITStructures::PieceStructure.new
          piece_struct.offset_low = piece[:offset]
          piece_struct.offset_high = 0
          piece_struct.size_low = piece[:size]
          piece_struct.size_high = 0

          piece_data = piece_struct.to_binary_s
          total_bytes += @io_system.write(output_handle, piece_data)
        end

        total_bytes
      end

      # Write secondary header block
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param sec_hdr [Hash] Secondary header metadata
      # @return [Integer] Bytes written
      def write_secondary_header(output_handle, sec_hdr)
        header = Binary::LITStructures::SecondaryHeader.new

        # SECHDR block
        header.sechdr_version = 2
        header.sechdr_length = 152

        # Entry directory info
        header.entry_aoli_idx = 0
        header.entry_aoli_idx_high = 0
        header.entry_reserved1 = 0
        header.entry_last_aoll = 0
        header.entry_reserved2 = 0
        header.entry_chunklen = sec_hdr[:entry_chunklen]
        header.entry_two = 2
        header.entry_reserved3 = 0
        header.entry_depth = sec_hdr[:entry_depth]
        header.entry_reserved4 = 0
        header.entry_entries = sec_hdr[:entry_entries]
        header.entry_reserved5 = 0

        # Count directory info
        header.count_aoli_idx = 0xFFFFFFFF
        header.count_aoli_idx_high = 0xFFFFFFFF
        header.count_reserved1 = 0
        header.count_last_aoll = 0
        header.count_reserved2 = 0
        header.count_chunklen = sec_hdr[:count_chunklen]
        header.count_two = 2
        header.count_reserved3 = 0
        header.count_depth = 1
        header.count_reserved4 = 0
        header.count_entries = sec_hdr[:count_entries]
        header.count_reserved5 = 0

        header.entry_unknown = sec_hdr[:entry_unknown]
        header.count_unknown = sec_hdr[:count_unknown]

        # CAOL block
        header.caol_tag = Binary::LITStructures::Tags::CAOL
        header.caol_version = 2
        header.caol_length = 80 # 48 + 32
        header.creator_id = sec_hdr[:creator_id]
        header.caol_reserved1 = 0
        header.caol_entry_chunklen = sec_hdr[:entry_chunklen]
        header.caol_count_chunklen = sec_hdr[:count_chunklen]
        header.caol_entry_unknown = sec_hdr[:entry_unknown]
        header.caol_count_unknown = sec_hdr[:count_unknown]
        header.caol_reserved2 = 0

        # ITSF block
        header.itsf_tag = Binary::LITStructures::Tags::ITSF
        header.itsf_version = 4
        header.itsf_length = 32
        header.itsf_unknown = 1
        header.content_offset_low = sec_hdr[:content_offset]
        header.content_offset_high = 0
        header.timestamp = sec_hdr[:timestamp]
        header.language_id = sec_hdr[:language_id]

        header_data = header.to_binary_s
        @io_system.write(output_handle, header_data)
      end
    end
  end
end
