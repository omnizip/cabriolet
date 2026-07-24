# frozen_string_literal: true

module Cabriolet
  module Binary
    autoload :Bitstream, "cabriolet/binary/bitstream"
    autoload :BitstreamWriter, "cabriolet/binary/bitstream_writer"

    autoload :CFHeader, "cabriolet/binary/structures"
    autoload :CFFolder, "cabriolet/binary/structures"
    autoload :CFFile, "cabriolet/binary/structures"
    autoload :CFData, "cabriolet/binary/structures"

    autoload :CHMITSFHeader, "cabriolet/binary/chm_structures"
    autoload :CHMHeaderSectionTable, "cabriolet/binary/chm_structures"
    autoload :CHMHeaderSection0, "cabriolet/binary/chm_structures"
    autoload :CHMHeaderSection1, "cabriolet/binary/chm_structures"
    autoload :PMGLChunkHeader, "cabriolet/binary/chm_structures"
    autoload :PMGIChunkHeader, "cabriolet/binary/chm_structures"
    autoload :CHMLZXControlData, "cabriolet/binary/chm_structures"
    autoload :LZXResetTableHeader, "cabriolet/binary/chm_structures"
    autoload :ENCINTReader, "cabriolet/binary/chm_structures"
    autoload :ENCINTWriter, "cabriolet/binary/chm_structures"

    autoload :SZDDStructures, "cabriolet/binary/szdd_structures"
    autoload :KWAJStructures, "cabriolet/binary/kwaj_structures"
    autoload :HLPStructures, "cabriolet/binary/hlp_structures"
    autoload :LITStructures, "cabriolet/binary/lit_structures"
    autoload :OABStructures, "cabriolet/binary/oab_structures"
  end
end
