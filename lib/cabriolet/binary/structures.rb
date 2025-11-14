# frozen_string_literal: true

require "bindata"

module Cabriolet
  module Binary
    # CAB file header structure (CFHEADER)
    class CFHeader < BinData::Record
      endian :little

      string :signature, length: 4
      uint32 :reserved1
      uint32 :cabinet_size
      uint32 :reserved2
      uint32 :files_offset
      uint32 :reserved3
      uint8  :minor_version
      uint8  :major_version
      uint16 :num_folders
      uint16 :num_files
      uint16 :flags
      uint16 :set_id
      uint16 :cabinet_index
    end

    # Folder structure (CFFOLDER)
    class CFFolder < BinData::Record
      endian :little

      uint32 :data_offset
      uint16 :num_blocks
      uint16 :comp_type
    end

    # File structure (CFFILE)
    class CFFile < BinData::Record
      endian :little

      uint32 :uncompressed_size
      uint32 :folder_offset
      uint16 :folder_index
      uint16 :date
      uint16 :time
      uint16 :attribs
    end

    # Data block structure (CFDATA)
    class CFData < BinData::Record
      endian :little

      uint32 :checksum
      uint16 :compressed_size
      uint16 :uncompressed_size
    end
  end
end
