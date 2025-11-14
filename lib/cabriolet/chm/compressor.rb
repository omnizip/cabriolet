# frozen_string_literal: true

require_relative "../binary/chm_structures"
require_relative "../compressors/lzx"
require_relative "../system/io_system"
require_relative "../system/memory_handle"
require_relative "../errors"

module Cabriolet
  module CHM
    # Compressor for CHM (Compiled HTML Help) files
    class Compressor
      # GUIDs used in CHM headers (same as parser)
      GUID1 = [0x10, 0xFD, 0x01, 0x7C, 0xAA, 0x7B, 0xD0, 0x11,
               0x9E, 0x0C, 0x00, 0xA0, 0xC9, 0x22, 0xE6, 0xEC].pack("C*")
      GUID2 = [0x11, 0xFD, 0x01, 0x7C, 0xAA, 0x7B, 0xD0, 0x11,
               0x9E, 0x0C, 0x00, 0xA0, 0xC9, 0x22, 0xE6, 0xEC].pack("C*")

      # System file names
      CONTENT_NAME = "::DataSpace/Storage/MSCompressed/Content"
      CONTROL_NAME = "::DataSpace/Storage/MSCompressed/ControlData"
      SPANINFO_NAME = "::DataSpace/Storage/MSCompressed/SpanInfo"
      RTABLE_NAME = "::DataSpace/Storage/MSCompressed/Transform/" \
                    "{7FC28940-9D31-11D0-9B27-00A0C91E9C7C}/InstanceData/ResetTable"

      # LZX constants
      LZX_FRAME_SIZE = 32_768

      # Default chunk size for directory
      DEFAULT_CHUNK_SIZE = 4096

      attr_reader :io_system, :files

      # Initialize CHM compressor
      #
      # @param io_system [System::IOSystem] I/O system for file operations
      def initialize(io_system = nil)
        @io_system = io_system || System::IOSystem.new
        @files = []
        @timestamp = Time.now.to_i
        @language_id = 0x0409 # English (US)
        @window_bits = 16
        @window_size = 1 << @window_bits
      end

      # Add a file to the CHM
      #
      # @param source_path [String] Path to source file
      # @param chm_path [String] Path within CHM (must start with /)
      # @param section [Symbol] :uncompressed or :compressed
      # @return [void]
      def add_file(source_path, chm_path, section: :compressed)
        unless chm_path.start_with?("/")
          raise ArgumentError,
                "CHM path must start with /"
        end
        unless File.exist?(source_path)
          raise ArgumentError,
                "Source file not found: #{source_path}"
        end

        @files << {
          source: source_path,
          chm_path: chm_path,
          section: section,
        }
      end

      # Generate the CHM file
      #
      # @param output_file [String] Path to output CHM file
      # @param options [Hash] Options
      # @option options [Integer] :timestamp Custom timestamp
      # @option options [Integer] :language_id Language ID
      # @option options [Integer] :window_bits LZX window size (15-21)
      # @return [Integer] Bytes written
      def generate(output_file, **options)
        raise ArgumentError, "No files to compress" if @files.empty?

        @timestamp = options[:timestamp] || @timestamp
        @language_id = options[:language_id] || @language_id
        @window_bits = options[:window_bits] || 16
        @window_size = 1 << @window_bits

        # Validate window bits
        unless (15..21).cover?(@window_bits)
          raise ArgumentError,
                "window_bits must be 15-21, got #{@window_bits}"
        end

        # Open output file
        output_handle = @io_system.open(output_file, Constants::MODE_WRITE)

        begin
          # Organize files into sections
          organize_sections

          # Compress section 1 files
          compress_section1

          # Build directory structure
          build_directory

          # Calculate offsets
          calculate_offsets

          # Write CHM file
          write_chm(output_handle)

          bytes_written = output_handle.tell
          output_handle.close
          bytes_written
        rescue StandardError => e
          output_handle&.close
          FileUtils.rm_f(output_file)
          raise e
        end
      end

      private

      # Organize files into sections
      def organize_sections
        @section0_files = []
        @section1_files = []

        @files.each do |file_info|
          if file_info[:section] == :uncompressed
            @section0_files << file_info
          else
            @section1_files << file_info
          end
        end

        # Sort files by name for consistent directory ordering
        @section0_files.sort_by! { |f| f[:chm_path] }
        @section1_files.sort_by! { |f| f[:chm_path] }
      end

      # Compress section 1 files using LZX
      def compress_section1
        return if @section1_files.empty?

        # Read all section 1 files into memory
        uncompressed_data = +""
        @section1_files.each do |file_info|
          file_info[:offset] = uncompressed_data.bytesize
          data = File.binread(file_info[:source])
          file_info[:length] = data.bytesize
          uncompressed_data << data
        end

        @uncompressed_length = uncompressed_data.bytesize

        # Compress data using LZX
        input_handle = System::MemoryHandle.new(uncompressed_data, Constants::MODE_READ)
        output_handle = System::MemoryHandle.new("", Constants::MODE_WRITE)

        compressor = Compressors::LZX.new(
          @io_system,
          input_handle,
          output_handle,
          4096,
          window_bits: @window_bits,
        )

        compressor.compress
        @compressed_data = output_handle.buffer
        @compressed_length = @compressed_data.bytesize

        # Calculate reset interval
        @reset_interval = LZX_FRAME_SIZE * 2
      end

      # Build directory structure with PMGL chunks
      def build_directory
        @directory_entries = []

        # Add section 0 files
        offset = 0
        @section0_files.each do |file_info|
          file_info[:offset] = offset
          file_info[:length] = File.size(file_info[:source])

          @directory_entries << {
            name: file_info[:chm_path],
            section: 0,
            offset: file_info[:offset],
            length: file_info[:length],
          }

          offset += file_info[:length]
        end

        @section0_length = offset

        # Add section 1 files
        @section1_files.each do |file_info|
          @directory_entries << {
            name: file_info[:chm_path],
            section: 1,
            offset: file_info[:offset],
            length: file_info[:length],
          }
        end

        # Add system files if section 1 exists
        add_system_files if @section1_files.any?

        # Sort entries by name
        @directory_entries.sort_by! { |e| e[:name] }

        # Build PMGL chunks
        build_pmgl_chunks
      end

      # Add system files to directory
      def add_system_files
        # Content file (compressed data)
        @directory_entries << {
          name: CONTENT_NAME,
          section: 0,
          offset: @section0_length,
          length: @compressed_length,
        }

        # ControlData file
        @control_data = build_control_data
        @directory_entries << {
          name: CONTROL_NAME,
          section: 0,
          offset: @section0_length + @compressed_length,
          length: @control_data.bytesize,
        }

        # ResetTable file
        @reset_table = build_reset_table
        @directory_entries << {
          name: RTABLE_NAME,
          section: 0,
          offset: @section0_length + @compressed_length + @control_data.bytesize,
          length: @reset_table.bytesize,
        }

        # SpanInfo file
        @span_info = build_span_info
        @directory_entries << {
          name: SPANINFO_NAME,
          section: 0,
          offset: @section0_length + @compressed_length + @control_data.bytesize +
            @reset_table.bytesize,
          length: @span_info.bytesize,
        }
      end

      # Build control data for LZX
      def build_control_data
        control = Binary::LZXControlData.new
        control.len = 28
        control.signature = "LZXC"
        control.version = 2
        control.reset_interval = @reset_interval / LZX_FRAME_SIZE
        control.window_size = @window_size / LZX_FRAME_SIZE
        control.cache_size = 0
        control.unknown1 = 0
        control.to_binary_s
      end

      # Build reset table
      def build_reset_table
        rtable = Binary::LZXResetTableHeader.new
        rtable.unknown1 = 0
        rtable.num_entries = 1
        rtable.entry_size = 8
        rtable.table_offset = 40
        rtable.uncomp_len = @uncompressed_length
        rtable.comp_len = @compressed_length
        rtable.frame_len = LZX_FRAME_SIZE

        # Build table with single entry (offset 0)
        table_data = [0].pack("Q<")

        rtable.to_binary_s + table_data
      end

      # Build span info
      def build_span_info
        [@uncompressed_length].pack("Q<")
      end

      # Build PMGL chunks from directory entries
      def build_pmgl_chunks
        @chunks = []
        chunk_data = +""
        entries_in_chunk = 0

        @directory_entries.each do |entry|
          # Encode entry
          entry_data = encode_directory_entry(entry)

          # Check if this entry fits in current chunk
          # PMGL header (20 bytes) + entry data + quickref (2 bytes per entry) + count (2 bytes)
          chunk_overhead = 20 + ((entries_in_chunk + 1) * 2) + 2
          if chunk_data.bytesize + entry_data.bytesize + chunk_overhead > DEFAULT_CHUNK_SIZE && entries_in_chunk.positive?
            # Finalize current chunk
            @chunks << finalize_pmgl_chunk(chunk_data, entries_in_chunk)
            chunk_data = +""
            entries_in_chunk = 0
          end

          chunk_data << entry_data
          entries_in_chunk += 1
        end

        # Finalize last chunk
        if entries_in_chunk.positive?
          @chunks << finalize_pmgl_chunk(chunk_data,
                                         entries_in_chunk)
        end
      end

      # Encode a directory entry
      def encode_directory_entry(entry)
        name_utf8 = entry[:name].encode("UTF-8")
        name_bytes = name_utf8.b

        data = +""
        data << Cabriolet::Binary::ENCINTWriter.encode(name_bytes.bytesize)
        data << name_bytes
        data << Cabriolet::Binary::ENCINTWriter.encode(entry[:section])
        data << Cabriolet::Binary::ENCINTWriter.encode(entry[:offset])
        data << Cabriolet::Binary::ENCINTWriter.encode(entry[:length])
        data
      end

      # Finalize a PMGL chunk
      def finalize_pmgl_chunk(data, num_entries)
        # Build quickref section (empty for simplicity)
        quickref = ""

        # Build chunk
        chunk = +""

        # Write PMGL header
        header = Binary::PMGLChunkHeader.new
        header.signature = "PMGL"
        header.quickref_size = quickref.bytesize
        header.unknown1 = 0
        header.prev_chunk = -1
        header.next_chunk = -1
        chunk << header.to_binary_s

        # Write entries
        chunk << data

        # Write quickref
        chunk << quickref

        # Pad to (chunk_size - 2) to leave room for entry count
        padding_size = DEFAULT_CHUNK_SIZE - chunk.bytesize - 2
        chunk << ("\0" * padding_size) if padding_size.positive?

        # Write entry count in last 2 bytes
        chunk << [num_entries].pack("v")

        chunk
      end

      # Calculate all offsets in the CHM file
      def calculate_offsets
        # ITSF header: 56 bytes (BinData structure size)
        @itsf_offset = 0
        @itsf_size = 56

        # Header section table: 40 bytes (version 3+)
        @section_table_offset = @itsf_offset + @itsf_size
        @section_table_size = 40

        # Header section 0: 24 bytes
        @hs0_offset = @section_table_offset + @section_table_size
        @hs0_size = 24

        # Header section 1 (ITSP): 84 bytes
        @hs1_offset = @hs0_offset + @hs0_size
        @hs1_size = 84

        # Directory chunks
        @dir_offset = @hs1_offset + @hs1_size
        @dir_size = @chunks.length * DEFAULT_CHUNK_SIZE

        # Content section 0
        @cs0_offset = @dir_offset + @dir_size

        # Calculate section 0 total size
        @cs0_size = @section0_length
        @cs0_size += @compressed_length if @section1_files.any?
        @cs0_size += @control_data.bytesize if @section1_files.any?
        @cs0_size += @reset_table.bytesize if @section1_files.any?
        @cs0_size += @span_info.bytesize if @section1_files.any?

        # Total file size
        @total_size = @cs0_offset + @cs0_size
      end

      # Write CHM file
      def write_chm(output)
        write_itsf_header(output)
        write_section_table(output)
        write_header_section0(output)
        write_header_section1(output)
        write_directory(output)
        write_content_section0(output)
      end

      # Write ITSF header
      def write_itsf_header(output)
        header = Binary::CHMITSFHeader.new
        header.signature = "ITSF"
        header.version = 3
        header.header_len = 96
        header.unknown1 = 1
        header.timestamp = @timestamp
        header.language_id = @language_id
        header.guid1 = GUID1
        header.guid2 = GUID2

        output.write(header.to_binary_s)
      end

      # Write header section table
      def write_section_table(output)
        # Manually pack instead of using BinData (BinData doesn't preserve assigned values)
        data = [
          @hs0_offset,
          @hs0_size,
          @hs1_offset,
          @hs1_size,
          @cs0_offset,
        ].pack("Q<Q<Q<Q<Q<")

        output.write(data)
      end

      # Write header section 0
      def write_header_section0(output)
        hs0 = Binary::CHMHeaderSection0.new
        hs0.unknown1 = 0
        hs0.unknown2 = 0
        hs0.file_len = @total_size
        hs0.unknown3 = 0
        hs0.unknown4 = 0

        output.write(hs0.to_binary_s)
      end

      # Write header section 1 (directory header)
      def write_header_section1(output)
        hs1 = Binary::CHMHeaderSection1.new
        hs1.signature = "ITSP"
        hs1.version = 1
        hs1.header_len = 84
        hs1.unknown1 = 10
        hs1.chunk_size = DEFAULT_CHUNK_SIZE
        hs1.density = 2
        hs1.depth = 1
        hs1.index_root = -1
        hs1.first_pmgl = 0
        hs1.last_pmgl = @chunks.length - 1
        hs1.unknown2 = -1
        hs1.num_chunks = @chunks.length
        hs1.language_id = @language_id
        hs1.guid = GUID1
        hs1.unknown3 = 0
        hs1.unknown4 = 0
        hs1.unknown5 = 0
        hs1.unknown6 = 0

        output.write(hs1.to_binary_s)
      end

      # Write directory chunks
      def write_directory(output)
        @chunks.each do |chunk|
          output.write(chunk)
        end
      end

      # Write content section 0
      def write_content_section0(output)
        # Write section 0 files
        @section0_files.each do |file_info|
          data = File.binread(file_info[:source])
          output.write(data)
        end

        # Write system files if section 1 exists
        return unless @section1_files.any?

        # Write compressed content
        output.write(@compressed_data)

        # Write control data
        output.write(@control_data)

        # Write reset table
        output.write(@reset_table)

        # Write span info
        output.write(@span_info)
      end
    end
  end
end
