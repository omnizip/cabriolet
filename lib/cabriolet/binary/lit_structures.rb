# frozen_string_literal: true

require "bindata"

module Cabriolet
  module Binary
    # Microsoft Reader LIT file format binary structures
    #
    # Based on the openclit/SharpLit reference implementation.
    # LIT files use a complex structure with pieces, directory chunks,
    # and section-based storage with LZX compression.
    #
    # NOTE: DES-encrypted (DRM-protected) LIT files are not supported.
    module LITStructures
      # LIT file signature: "ITOLITLS"
      SIGNATURE = "ITOLITLS"

      # Primary Header (40 bytes)
      #
      # Structure:
      # - 8 bytes: signature "ITOLITLS"
      # - 4 bytes: version (typically 1)
      # - 4 bytes: primary header length (40)
      # - 4 bytes: number of pieces (typically 5)
      # - 4 bytes: secondary header length
      # - 16 bytes: header GUID
      class PrimaryHeader < BinData::Record
        endian :little

        string :signature, length: 8
        uint32 :version
        uint32 :header_length
        uint32 :num_pieces
        uint32 :secondary_header_length
        string :header_guid, length: 16
      end

      # Piece Structure (16 bytes each)
      #
      # Points to various data pieces in the file:
      # Piece 0: File size information
      # Piece 1: Internal directory (IFCM structure)
      # Piece 2: Index information for directory
      # Piece 3: GUID {0A9007C3-7640-D311-87890000F8105754}
      # Piece 4: GUID {0A9007C4-7640-D311-87890000F8105754}
      class PieceStructure < BinData::Record
        endian :little

        uint32 :offset_low
        uint32 :offset_high
        uint32 :size_low
        uint32 :size_high

        def offset
          (offset_high << 32) | offset_low
        end

        def size
          (size_high << 32) | size_low
        end
      end

      # Secondary Header Block (variable size)
      #
      # Contains three sub-blocks:
      # 1. SECHDR: Directory structure information
      # 2. CAOL: Additional directory parameters
      # 3. ITSF: Content offset and metadata
      class SecondaryHeader < BinData::Record
        endian :little

        # SECHDR block (152 bytes, no tag field)
        uint32 :sechdr_version        # Should be 2
        uint32 :sechdr_length          # Should be 152

        # Entry directory information
        uint32 :entry_aoli_idx
        uint32 :entry_aoli_idx_high
        uint64 :entry_reserved1
        uint32 :entry_last_aoll
        uint64 :entry_reserved2
        uint32 :entry_chunklen         # Typically 0x2000
        uint32 :entry_two              # Always 2
        uint32 :entry_reserved3
        uint32 :entry_depth            # 1 or 2 (with AOLI)
        uint64 :entry_reserved4
        uint32 :entry_entries
        uint32 :entry_reserved5

        # Count directory information
        uint32 :count_aoli_idx         # Typically 0xFFFFFFFF
        uint32 :count_aoli_idx_high    # Typically 0xFFFFFFFF
        uint64 :count_reserved1
        uint32 :count_last_aoll
        uint64 :count_reserved2
        uint32 :count_chunklen         # Typically 0x200
        uint32 :count_two              # Always 2
        uint32 :count_reserved3
        uint32 :count_depth            # Always 1
        uint64 :count_reserved4
        uint32 :count_entries
        uint32 :count_reserved5

        uint32 :entry_unknown          # 0x100000
        uint32 :count_unknown          # 0x20000

        # CAOL block (48 bytes)
        uint32 :caol_tag               # 0x4C4F4143 ('CAOL')
        uint32 :caol_version           # Should be 2
        uint32 :caol_length            # 48 + 32 (includes ITSF)
        uint32 :creator_id
        uint32 :caol_reserved1
        uint32 :caol_entry_chunklen    # Same as entry_chunklen
        uint32 :caol_count_chunklen    # Same as count_chunklen
        uint32 :caol_entry_unknown     # Same as entry_unknown
        uint32 :caol_count_unknown     # Same as count_unknown
        uint64 :caol_reserved2

        # ITSF block (32 bytes)
        uint32 :itsf_tag               # 0x46535449 ('ITSF')
        uint32 :itsf_version           # Should be 4
        uint32 :itsf_length            # 32
        uint32 :itsf_unknown           # Always 1
        uint32 :content_offset_low
        uint32 :content_offset_high
        uint32 :timestamp
        uint32 :language_id            # Typically 0x409 (English)

        def content_offset
          (content_offset_high << 32) | content_offset_low
        end
      end

      # IFCM Header - Internal File Collection Manager (32 bytes)
      #
      # Container for directory chunks (AOLL/AOLI)
      class IFCMHeader < BinData::Record
        endian :little

        uint32 :tag                    # 0x4D434649 ('IFCM')
        uint32 :version                # Typically 1
        uint32 :chunk_size            # Chunk size (0x2000 or 0x200)
        uint32 :param                  # 0x100000 or 0x20000
        uint32 :reserved1              # 0xFFFFFFFF
        uint32 :reserved2              # 0xFFFFFFFF
        uint32 :num_chunks
        uint32 :reserved3
      end

      # AOLL Header - Archive Object List List (48 bytes)
      #
      # List chunk containing actual directory entries
      class AOLLHeader < BinData::Record
        endian :little

        uint32 :tag                    # 0x4C4C4F41 ('AOLL')
        uint32 :quickref_offset        # Offset to quickref area
        uint32 :current_chunk_low
        uint32 :current_chunk_high
        uint32 :prev_chunk_low
        uint32 :prev_chunk_high
        uint32 :next_chunk_low
        uint32 :next_chunk_high
        uint32 :entries_so_far
        uint32 :reserved
        uint32 :chunk_distance         # Distance to next chunk
        uint32 :reserved2
      end

      # AOLI Header - Archive Object List Index (16 bytes)
      #
      # Index chunk for faster directory lookup
      class AOLIHeader < BinData::Record
        endian :little

        uint32 :tag                    # 0x494C4F41 ('AOLI')
        uint32 :quickref_offset        # Offset to quickref area
        uint32 :param
        uint32 :reserved
      end

      # LZX Control Data (32 bytes)
      #
      # Compression parameters for LZX algorithm
      class LZXControlData < BinData::Record
        endian :little

        uint32 :num_dwords             # Always 7
        uint32 :tag                    # 0x43585A4C ('LZXC')
        uint32 :constant               # Always 3
        uint32 :window_size_code       # 15-21 (actual window = 1 << (code+14))
        uint32 :window_size_code_dup   # Same as window_size_code
        uint32 :constant2              # Always 2
        uint64 :reserved
      end

      # Reset Table Header (40 bytes)
      #
      # Provides reset points for LZX decompression
      class ResetTableHeader < BinData::Record
        endian :little

        uint32 :version                # Should be 3
        uint32 :num_entries
        uint32 :unknown                # Always 8
        uint32 :header_length          # Should be 0x28 (40)
        uint32 :uncompressed_length_low
        uint32 :uncompressed_length_high
        uint32 :compressed_length_low
        uint32 :compressed_length_high
        uint32 :reset_interval
        uint32 :padding

        def uncompressed_length
          (uncompressed_length_high << 32) | uncompressed_length_low
        end

        def compressed_length
          (compressed_length_high << 32) | compressed_length_low
        end
      end

      # Manifest Entry
      #
      # Maps internal filenames to original filenames and content types
      class ManifestEntry < BinData::Record
        endian :little

        uint32 :offset
        uint8 :internal_length
        string :internal_name, read_length: :internal_length
        uint8 :original_length
        string :original_name, read_length: :original_length
        uint8 :content_type_length
        string :content_type, read_length: :content_type_length
        uint8 :terminator              # Always 0
      end

      # Constants
      module Tags
        IFCM = 0x4D434649
        AOLL = 0x4C4C4F41
        AOLI = 0x494C4F41
        CAOL = 0x4C4F4143
        ITSF = 0x46535449
        LZXC = 0x43585A4C
        SIZE_PIECE = 0x1FE
      end

      # GUIDs
      module GUIDs
        DESENCRYPT = "{67F6E4A2-60BF-11D3-8540-00C04F58C3CF}".freeze
        LZXCOMPRESS = "{0A9007C6-4076-11D3-8789-0000F8105754}".freeze
        IDENTITY = "{00000020-1000-FF00-FFFF-FFFFFFFFFF01}".freeze # No-op/identity transform
        PIECE3 = [0xC3, 0x07, 0x90, 0x0A, 0x40, 0x76, 0x11, 0xD3,
                  0x87, 0x89, 0x00, 0x00, 0xF8, 0x10, 0x57, 0x54].pack("C*").freeze
        PIECE4 = [0xC4, 0x07, 0x90, 0x0A, 0x40, 0x76, 0x11, 0xD3,
                  0x87, 0x89, 0x00, 0x00, 0xF8, 0x10, 0x57, 0x54].pack("C*").freeze
      end

      # Path constants
      module Paths
        NAMELIST = "::DataSpace/NameList"
        STORAGE = "::DataSpace/Storage/"
        TRANSFORM_LIST = "/Transform/List"
        CONTENT = "/Content"
        CONTROL_DATA = "/ControlData"
        RESET_TABLE = "/Transform/List/#{GUIDs::LZXCOMPRESS}/InstanceData/ResetTable"
        MANIFEST = "/manifest"
      end
    end
  end
end
