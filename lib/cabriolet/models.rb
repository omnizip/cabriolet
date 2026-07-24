# frozen_string_literal: true

module Cabriolet
  module Models
    autoload :Cabinet, "cabriolet/models/cabinet"
    autoload :Folder, "cabriolet/models/folder"
    autoload :FolderData, "cabriolet/models/folder_data"
    autoload :File, "cabriolet/models/file"

    autoload :CHMHeader, "cabriolet/models/chm_header"
    autoload :CHMSection, "cabriolet/models/chm_section"
    autoload :CHMSecUncompressed, "cabriolet/models/chm_section"
    autoload :CHMSecMSCompressed, "cabriolet/models/chm_section"
    autoload :CHMFile, "cabriolet/models/chm_file"

    autoload :SZDDHeader, "cabriolet/models/szdd_header"
    autoload :KWAJHeader, "cabriolet/models/kwaj_header"

    autoload :HLPHeader, "cabriolet/models/hlp_header"
    autoload :HLPTopic, "cabriolet/models/hlp_file"
    autoload :HLPLine, "cabriolet/models/hlp_file"
    autoload :TextAttribute, "cabriolet/models/hlp_file"

    autoload :WinHelpHeader, "cabriolet/models/winhelp_header"

    autoload :LITFile, "cabriolet/models/lit_header"
    autoload :LITSection, "cabriolet/models/lit_header"
    autoload :LITDirectory, "cabriolet/models/lit_header"
    autoload :LITDirectoryEntry, "cabriolet/models/lit_header"
    autoload :LITManifest, "cabriolet/models/lit_header"
    autoload :LITManifestMapping, "cabriolet/models/lit_header"

    autoload :OABHeader, "cabriolet/models/oab_header"
    autoload :OABBlockHeader, "cabriolet/models/oab_header"
    autoload :OABPatchBlockHeader, "cabriolet/models/oab_header"
  end
end
