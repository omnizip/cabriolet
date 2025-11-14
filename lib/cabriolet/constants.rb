# frozen_string_literal: true

module Cabriolet
  # CAB format constants
  module Constants
    # CAB signature
    CAB_SIGNATURE = 0x4643534D # "MSCF"

    # Compression types
    COMP_TYPE_NONE = 0
    COMP_TYPE_MSZIP = 1
    COMP_TYPE_QUANTUM = 2
    COMP_TYPE_LZX = 3

    # Compression type mask
    COMP_TYPE_MASK = 0x000F

    # CAB header flags
    FLAG_PREV_CABINET = 0x0001
    FLAG_NEXT_CABINET = 0x0002
    FLAG_RESERVE_PRESENT = 0x0004

    # File attribute flags
    ATTRIB_READONLY = 0x01
    ATTRIB_HIDDEN = 0x02
    ATTRIB_SYSTEM = 0x04
    ATTRIB_ARCH = 0x20
    ATTRIB_EXEC = 0x40
    ATTRIB_UTF_NAME = 0x80

    # Folder index special values
    FOLDER_CONTINUED_FROM_PREV = 0xFFFD
    FOLDER_CONTINUED_TO_NEXT = 0xFFFE
    FOLDER_CONTINUED_PREV_AND_NEXT = 0xFFFF

    # Block and folder limits
    BLOCK_MAX = 32_768 # Maximum uncompressed block size
    INPUT_MAX = BLOCK_MAX + 6144 # Maximum compressed block size (LZX worst case)
    FOLDER_MAX = 65_535 # Maximum number of data blocks per folder
    LENGTH_MAX = BLOCK_MAX * FOLDER_MAX # Maximum file size

    # Structure sizes
    CFHEADER_SIZE = 36
    CFHEADER_EXT_SIZE = 4
    CFFOLDER_SIZE = 8
    CFFILE_SIZE = 16
    CFDATA_SIZE = 8

    # I/O modes
    MODE_READ = 0
    MODE_WRITE = 1
    MODE_UPDATE = 2
    MODE_APPEND = 3

    # Seek modes
    SEEK_START = 0
    SEEK_CUR = 1
    SEEK_END = 2

    # KWAJ compression types
    KWAJ_COMP_NONE = 0
    KWAJ_COMP_XOR = 1
    KWAJ_COMP_SZDD = 2
    KWAJ_COMP_LZH = 3
    KWAJ_COMP_MSZIP = 4

    # KWAJ header flags
    KWAJ_HDR_HASLENGTH = 0x01
    KWAJ_HDR_HASUNKNOWN1 = 0x02
    KWAJ_HDR_HASUNKNOWN2 = 0x04
    KWAJ_HDR_HASFILENAME = 0x08
    KWAJ_HDR_HASFILEEXT = 0x10
    KWAJ_HDR_HASEXTRATEXT = 0x20
  end
end
