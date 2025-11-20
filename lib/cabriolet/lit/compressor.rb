# frozen_string_literal: true

module Cabriolet
  module LIT
    # Compressor creates LIT eBook files
    #
    # LIT files are Microsoft Reader eBook files that use LZX compression.
    # The compressor allows adding multiple files to create a LIT archive.
    #
    # NOTE: This implementation creates non-encrypted LIT files only.
    # DES encryption (DRM protection) is not implemented.
    class Compressor
      attr_reader :io_system
      attr_accessor :files

      # Initialize a new LIT compressor
      #
      # @param io_system [System::IOSystem, nil] Custom I/O system or nil for
      #   default
      # @param algorithm_factory [AlgorithmFactory, nil] Custom algorithm factory or nil for default
      def initialize(io_system = nil, algorithm_factory = nil)
        @io_system = io_system || System::IOSystem.new
        @algorithm_factory = algorithm_factory || Cabriolet.algorithm_factory
        @files = []
      end

      # Add a file to the LIT archive
      #
      # @param source_path [String] Path to the source file
      # @param lit_path [String] Path within the LIT archive
      # @param options [Hash] Options for the file
      # @option options [Boolean] :compress Whether to compress the file
      #   (default: true)
      # @return [void]
      def add_file(source_path, lit_path, **options)
        compress = options.fetch(:compress, true)

        @files << {
          source: source_path,
          lit_path: lit_path,
          compress: compress,
        }
      end

      # Generate the LIT archive
      #
      # @param output_file [String] Path to output LIT file
      # @param options [Hash] Generation options
      # @option options [Integer] :version LIT format version (default: 1)
      # @option options [Integer] :language_id Language ID (default: 0x409 English)
      # @option options [Integer] :creator_id Creator ID (default: 0)
      # @return [Integer] Bytes written to output file
      # @raise [Errors::CompressionError] if compression fails
      def generate(output_file, **options)
        version = options.fetch(:version, 1)
        language_id = options.fetch(:language_id, 0x409) # English
        creator_id = options.fetch(:creator_id, 0)

        raise ArgumentError, "No files added to archive" if @files.empty?
        raise ArgumentError, "Version must be 1" unless version == 1

        # Prepare file data
        file_data = prepare_files

        # Build LIT structure
        lit_structure = build_lit_structure(file_data, version, language_id, creator_id)

        # Write to output file
        output_handle = @io_system.open(output_file, Constants::MODE_WRITE)
        begin
          bytes_written = write_lit_file(output_handle, lit_structure)
          bytes_written
        ensure
          @io_system.close(output_handle)
        end
      end

      private

      # Build complete LIT structure
      def build_lit_structure(file_data, version, language_id, creator_id)
        structure = {}

        # Generate GUIDs
        structure[:header_guid] = generate_guid
        structure[:piece3_guid] = Binary::LITStructures::GUIDs::PIECE3
        structure[:piece4_guid] = Binary::LITStructures::GUIDs::PIECE4

        # Build directory
        structure[:directory] = build_directory(file_data)

        # Build sections
        structure[:sections] = build_sections(file_data)

        # Build manifest
        structure[:manifest] = build_manifest(file_data)

        # Build secondary header first (needed for piece calculation)
        structure[:secondary_header] = build_secondary_header_metadata(
          language_id,
          creator_id,
        )

        # Calculate piece offsets and sizes (uses secondary header length)
        structure[:pieces] = calculate_pieces(structure)

        # Update secondary header with content offset
        update_secondary_header_content_offset(structure)

        # Store metadata
        structure[:version] = version
        structure[:file_data] = file_data

        structure
      end

      # Write complete LIT file
      def write_lit_file(output_handle, structure)
        # Write primary header (40 bytes)
        bytes_written = write_primary_header(output_handle, structure)

        # Write piece structures (5 * 16 bytes = 80 bytes)
        bytes_written += write_piece_structures(output_handle, structure[:pieces])

        # Write secondary header
        bytes_written += write_secondary_header_block(
          output_handle,
          structure[:secondary_header],
        )

        # Write piece data
        bytes_written += write_piece_data(output_handle, structure)

        bytes_written
      end

      # Generate a random GUID
      def generate_guid
        require "securerandom"
        SecureRandom.random_bytes(16)
      end

      # Write primary header
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
      def write_secondary_header_block(output_handle, sec_hdr)
        # Build secondary header using Binary::LITStructures::SecondaryHeader
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

      # Build directory structure
      def build_directory(file_data)
        # Create directory entries for all files
        entries = []
        section = 0 # All files go in section 0 for now (uncompressed)
        offset = 0

        file_data.each do |file_info|
          entry = {
            name: file_info[:lit_path],
            section: section,
            offset: offset,
            size: file_info[:uncompressed_size],
          }
          entries << entry
          offset += file_info[:uncompressed_size]
        end

        # Calculate NameList size
        namelist_size = calculate_namelist_size(file_data)

        # Calculate manifest size
        manifest_size = calculate_manifest_size(file_data)

        # Add special entries for LIT structure
        # ::DataSpace/NameList entry
        entries << {
          name: Binary::LITStructures::Paths::NAMELIST,
          section: 0,
          offset: offset,
          size: namelist_size,
        }
        offset += namelist_size

        # Add manifest entry
        entries << {
          name: Binary::LITStructures::Paths::MANIFEST,
          section: 0,
          offset: offset,
          size: manifest_size,
        }

        {
          entries: entries,
          chunk_size: 0x2000, # 8KB chunks
          num_chunks: 1,      # Simple single-chunk directory for now
        }
      end

      # Calculate NameList size (estimate)
      def calculate_namelist_size(_file_data)
        # Simple estimate: ~100 bytes for minimal NameList
        100
      end

      # Calculate manifest size (estimate)
      def calculate_manifest_size(file_data)
        # Rough estimate: directory header + entries
        size = 10 # Directory header

        file_data.each do |file_info|
          # Per entry: offset (4) + 3 length bytes + names + content type + terminator
          size += 4 + 3
          size += (file_info[:lit_path].bytesize * 2) + 20 + 1
        end

        size
      end

      # Build sections
      def build_sections(_file_data)
        # For simple implementation: single uncompressed section
        # Advanced: could have multiple sections with different compression
        sections = []

        # Section 0 is always uncompressed content
        section = {
          name: "Uncompressed",
          transforms: [],
          compressed: false,
          encrypted: false,
        }
        sections << section

        sections
      end

      # Build manifest
      def build_manifest(file_data)
        mappings = []

        file_data.each_with_index do |file_info, index|
          mapping = {
            offset: index, # Simple sequential offset
            internal_name: file_info[:lit_path],
            original_name: file_info[:lit_path],
            content_type: guess_content_type(file_info[:lit_path]),
            group: guess_file_group(file_info[:lit_path]),
          }
          mappings << mapping
        end

        {
          mappings: mappings,
        }
      end

      # Guess content type from filename
      def guess_content_type(filename)
        ext = File.extname(filename).downcase
        case ext
        when ".html", ".htm"
          "text/html"
        when ".css"
          "text/css"
        when ".jpg", ".jpeg"
          "image/jpeg"
        when ".png"
          "image/png"
        when ".gif"
          "image/gif"
        when ".txt"
          "text/plain"
        else
          "application/octet-stream"
        end
      end

      # Guess file group (0=HTML spine, 1=HTML other, 2=CSS, 3=Images)
      def guess_file_group(filename)
        ext = File.extname(filename).downcase
        case ext
        when ".html", ".htm"
          0 # HTML spine (simplification - could be group 1 for non-spine)
        when ".css"
          2 # CSS
        when ".jpg", ".jpeg", ".png", ".gif"
          3 # Images
        else
          1 # Other
        end
      end

      # Calculate piece offsets and sizes
      def calculate_pieces(structure)
        pieces = []

        # Calculate starting offset (after headers and pieces)
        # Primary header: 40 bytes
        # Piece structures: 5 * 16 = 80 bytes
        # Secondary header: variable
        sec_hdr_length = structure[:secondary_header][:length]
        current_offset = 40 + 80 + sec_hdr_length

        # Piece 0: File size information (small, typically ~16 bytes)
        piece0_size = 16
        pieces << { offset: current_offset, size: piece0_size }
        current_offset += piece0_size

        # Piece 1: Directory (IFCM structure)
        # For foundation: minimal size
        piece1_size = 8192 # Typical directory size
        pieces << { offset: current_offset, size: piece1_size }
        current_offset += piece1_size

        # Piece 2: Index information (typically empty or minimal)
        piece2_size = 512
        pieces << { offset: current_offset, size: piece2_size }
        current_offset += piece2_size

        # Piece 3: Standard GUID (fixed 16 bytes)
        pieces << { offset: current_offset, size: 16 }
        current_offset += 16

        # Piece 4: Standard GUID (fixed 16 bytes)
        pieces << { offset: current_offset, size: 16 }
        current_offset + 16

        pieces
      end

      # Build secondary header structure (initial metadata)
      def build_secondary_header_metadata(language_id, creator_id)
        # Calculate actual secondary header length from BinData structure
        temp_header = Binary::LITStructures::SecondaryHeader.new
        sec_hdr_length = temp_header.to_binary_s.bytesize

        {
          length: sec_hdr_length,
          entry_chunklen: 0x2000, # 8KB chunks for entry directory
          count_chunklen: 0x200,      # 512B chunks for count directory
          entry_unknown: 0x100000,
          count_unknown: 0x20000,
          entry_depth: 1,             # No AOLI index layer
          entry_entries: 0,           # Will be set when directory built
          count_entries: 0,           # Will be set when directory built
          content_offset: 0,          # Will be calculated after pieces
          timestamp: Time.now.to_i,
          language_id: language_id,
          creator_id: creator_id,
        }
      end

      # Update secondary header with final content offset
      def update_secondary_header_content_offset(structure)
        pieces = structure[:pieces]
        last_piece = pieces.last
        content_offset = last_piece[:offset] + last_piece[:size]

        structure[:secondary_header][:content_offset] = content_offset
      end

      # Write piece data
      def write_piece_data(output_handle, structure)
        total_bytes = 0

        # Write piece 0: File size information
        piece0_data = build_piece0_data(structure)
        total_bytes += @io_system.write(output_handle, piece0_data)

        # Write piece 1: Directory (IFCM structure)
        piece1_data = build_piece1_data(structure)
        total_bytes += @io_system.write(output_handle, piece1_data)

        # Write piece 2: Index information
        piece2_data = build_piece2_data(structure)
        total_bytes += @io_system.write(output_handle, piece2_data)

        # Write piece 3: GUID
        total_bytes += @io_system.write(output_handle, structure[:piece3_guid])

        # Write piece 4: GUID
        total_bytes += @io_system.write(output_handle, structure[:piece4_guid])

        # Write actual content data (after pieces, this is where files go)
        total_bytes += write_content_data(output_handle, structure)

        total_bytes
      end

      # Write content data (actual file contents)
      def write_content_data(output_handle, structure)
        total_bytes = 0

        # Write each file's content
        structure[:file_data].each do |file_info|
          total_bytes += @io_system.write(output_handle, file_info[:data])
        end

        # Write NameList
        namelist_data = build_namelist_data(structure[:sections])
        total_bytes += @io_system.write(output_handle, namelist_data)

        # Write manifest
        manifest_data = build_manifest_data(structure[:manifest])
        total_bytes += @io_system.write(output_handle, manifest_data)

        total_bytes
      end

      # Build NameList data
      def build_namelist_data(sections)
        data = +""
        data += [0].pack("v") # Initial field

        # Write number of sections
        data += [sections.size].pack("v")

        # Write each section name
        null_terminator = [0].pack("v")
        sections.each do |section|
          name = section[:name]
          # Convert to UTF-16LE
          name_utf16 = name.encode("UTF-16LE").force_encoding("ASCII-8BIT")
          name_length = name_utf16.bytesize / 2

          data += [name_length].pack("v")
          data += name_utf16
          data += null_terminator
        end

        data
      end

      # Build manifest data
      def build_manifest_data(manifest)
        data = +""

        # For simplicity: single directory entry
        data += [0].pack("C") # Empty directory name = end of directories

        # Write 4 groups
        terminator = [0].pack("C")
        4.times do |group|
          # Get mappings for this group
          group_mappings = manifest[:mappings].select { |m| m[:group] == group }

          data += [group_mappings.size].pack("V")

          group_mappings.each do |mapping|
            data += [mapping[:offset]].pack("V")

            # Internal name
            data += [mapping[:internal_name].bytesize].pack("C")
            data += mapping[:internal_name]

            # Original name
            data += [mapping[:original_name].bytesize].pack("C")
            data += mapping[:original_name]

            # Content type
            data += [mapping[:content_type].bytesize].pack("C")
            data += mapping[:content_type]

            # Terminator
            data += terminator
          end
        end

        data
      end

      # Build piece 0 data (file size information)
      def build_piece0_data(structure)
        # Calculate total content size
        content_size = 0
        structure[:file_data].each do |file_info|
          content_size += file_info[:uncompressed_size]
        end

        data = [Binary::LITStructures::Tags::SIZE_PIECE].pack("V")
        data += [content_size].pack("V")
        data += [0, 0].pack("VV") # High bits, reserved
        data
      end

      # Build piece 1 data (directory IFCM structure)
      def build_piece1_data(structure)
        # Build IFCM header
        ifcm = Binary::LITStructures::IFCMHeader.new
        ifcm.tag = Binary::LITStructures::Tags::IFCM
        ifcm.version = 1
        ifcm.chunk_size = structure[:directory][:chunk_size]
        ifcm.param = 0x100000
        ifcm.reserved1 = 0xFFFFFFFF
        ifcm.reserved2 = 0xFFFFFFFF
        ifcm.num_chunks = structure[:directory][:num_chunks]
        ifcm.reserved3 = 0

        data = ifcm.to_binary_s

        # Build AOLL chunk with directory entries
        aoll_chunk = build_aoll_chunk(structure[:directory][:entries])
        data += aoll_chunk

        # Pad to fill piece (8KB standard)
        target_size = 8192
        if data.bytesize < target_size
          data += "\x00" * (target_size - data.bytesize)
        end

        data
      end

      # Build AOLL (Archive Object List List) chunk
      def build_aoll_chunk(entries)
        # First, build all entry data to know the size
        entries_data = +""
        entries.each do |entry|
          entries_data += encode_directory_entry(entry)
        end

        # Calculate quickref offset (starts after entries data)
        quickref_offset = entries_data.bytesize

        # AOLL header (48 bytes)
        header = Binary::LITStructures::AOLLHeader.new
        header.tag = Binary::LITStructures::Tags::AOLL
        header.quickref_offset = quickref_offset
        header.current_chunk_low = 0
        header.current_chunk_high = 0
        header.prev_chunk_low = 0xFFFFFFFF
        header.prev_chunk_high = 0xFFFFFFFF
        header.next_chunk_low = 0xFFFFFFFF
        header.next_chunk_high = 0xFFFFFFFF
        header.entries_so_far = entries.size
        header.reserved = 0
        header.chunk_distance = 0
        header.reserved2 = 0

        chunk_data = header.to_binary_s

        # Write directory entries
        chunk_data += entries_data

        chunk_data
      end

      # Encode a directory entry with variable-length integers
      def encode_directory_entry(entry)
        data = +""

        # Encode name length and name
        name = entry[:name].dup.force_encoding("UTF-8")
        data += write_encoded_int(name.bytesize)
        data += name

        # Encode section, offset, size
        data += write_encoded_int(entry[:section])
        data += write_encoded_int(entry[:offset])
        data += write_encoded_int(entry[:size])

        data
      end

      # Write an encoded integer (variable length, MSB = continuation bit)
      def write_encoded_int(value)
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

      # Build piece 2 data (index information)
      def build_piece2_data(_structure)
        # Minimal index data for foundation
        "\x00" * 512
      end

      # Prepare file data for archiving
      #
      # @return [Array<Hash>] Array of file information hashes
      def prepare_files
        @files.map do |file_info|
          source = file_info[:source]
          lit_path = file_info[:lit_path]
          compress = file_info[:compress]

          # Read source file
          handle = @io_system.open(source, Constants::MODE_READ)
          begin
            size = @io_system.seek(handle, 0, Constants::SEEK_END)
            @io_system.seek(handle, 0, Constants::SEEK_START)
            data = @io_system.read(handle, size)
          ensure
            @io_system.close(handle)
          end

          {
            lit_path: lit_path,
            data: data,
            uncompressed_size: data.bytesize,
            compress: compress,
          }
        end
      end

      # Write LIT header
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param version [Integer] LIT format version
      # @param file_count [Integer] Number of files
      # @return [Integer] Number of bytes written
      def write_header(output_handle, version, _file_count)
        # NOTE: This is a simplified header format and does not match the actual LIT PrimaryHeader structure
        # TODO: Implement proper LIT PrimaryHeader usage
        header = Binary::LITStructures::PrimaryHeader.new
        header.signature = Binary::LITStructures::SIGNATURE
        header.version = version
        header.header_length = 40 # PrimaryHeader is 40 bytes
        header.num_pieces = 5 # Standard for LIT files
        header.secondary_header_length = 0 # Simplified for now
        header.header_guid = "\x00" * 16 # Placeholder GUID

        header_data = header.to_binary_s
        written = @io_system.write(output_handle, header_data)

        unless written == header_data.bytesize
          raise Errors::CompressionError,
                "Failed to write LIT header"
        end

        written
      end

      # Write file entries directory
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param file_data [Array<Hash>] Array of file information
      # @return [Integer] Number of bytes written
      def write_file_entries(output_handle, file_data)
        total_bytes = 0
        current_offset = calculate_header_size(file_data)

        file_data.each do |file_info|
          # Compress or store data
          if file_info[:compress]
            compressed = compress_data(file_info[:data])
            compressed_size = compressed.bytesize
            flags = Binary::LITStructures::FileFlags::COMPRESSED
          else
            compressed = file_info[:data]
            compressed_size = compressed.bytesize
            flags = 0
          end

          # Store compressed data for later writing
          file_info[:compressed_data] = compressed
          file_info[:compressed_size] = compressed_size
          file_info[:offset] = current_offset

          # Write file entry
          entry = Binary::LITStructures::LITFileEntry.new
          entry.filename_length = file_info[:lit_path].bytesize
          entry.filename = file_info[:lit_path]
          entry.offset = current_offset
          entry.compressed_size = compressed_size
          entry.uncompressed_size = file_info[:uncompressed_size]
          entry.flags = flags

          entry_data = entry.to_binary_s
          written = @io_system.write(output_handle, entry_data)
          total_bytes += written

          current_offset += compressed_size
        end

        total_bytes
      end

      # Write file contents
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param file_data [Array<Hash>] Array of file information with
      #   compressed data
      # @return [Integer] Number of bytes written
      def write_file_contents(output_handle, file_data)
        total_bytes = 0

        file_data.each do |file_info|
          written = @io_system.write(
            output_handle,
            file_info[:compressed_data],
          )
          total_bytes += written
        end

        total_bytes
      end

      # Calculate total header size (header + all file entries)
      #
      # @param file_data [Array<Hash>] Array of file information
      # @return [Integer] Total header size in bytes
      def calculate_header_size(file_data)
        # Header: 24 bytes
        header_size = 24

        # File entries: variable size
        file_data.each do |file_info|
          # 4 bytes filename length + filename + 28 bytes metadata
          header_size += 4 + file_info[:lit_path].bytesize + 28
        end

        header_size
      end

      # Compress data using LZX
      #
      # @param data [String] Data to compress
      # @return [String] Compressed data
      def compress_data(data)
        input_handle = System::MemoryHandle.new(data)
        output_handle = System::MemoryHandle.new("", Constants::MODE_WRITE)

        begin
          compressor = @algorithm_factory.create(
            Constants::COMP_TYPE_LZX,
            :compressor,
            @io_system,
            input_handle,
            output_handle,
            32_768,
          )

          compressor.compress

          output_handle.data

          # Memory handles don't need closing but maintain consistency
        end
      end
    end
  end
end
