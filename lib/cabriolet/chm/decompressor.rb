# frozen_string_literal: true

require_relative "parser"
require_relative "../decompressors/lzx"
require_relative "../system/file_handle"
require_relative "../system/memory_handle"

module Cabriolet
  module CHM
    # Decompressor for CHM (Compiled HTML Help) files
    class Decompressor
      LZX_FRAME_SIZE = 32_768

      attr_reader :io_system, :chm

      def initialize(io_system = nil, algorithm_factory = nil)
        @io_system = io_system || System::IOSystem.new
        @algorithm_factory = algorithm_factory || Cabriolet.algorithm_factory
        @chm = nil
        @input_handle = nil
        @lzx_state = nil
        @lzx_offset = 0
        @lzx_length = 0
      end

      # Open a CHM file
      # @param filename [String] Path to CHM file
      # @param entire [Boolean] If true, parse all file entries
      # @return [Models::CHMHeader] CHM header
      def open(filename, entire: true)
        @input_handle = @io_system.open(filename, Constants::MODE_READ)
        @chm = Parser.new(@input_handle).parse(entire: entire)
        @chm.filename = filename
        @chm
      rescue StandardError => e
        @input_handle&.close
        @input_handle = nil
        raise e
      end

      # Open a CHM file quickly (without parsing file entries)
      # @param filename [String] Path to CHM file
      # @return [Models::CHMHeader] CHM header
      def fast_open(filename)
        open(filename, entire: false)
      end

      # Close the CHM file
      def close
        cleanup_lzx
        @input_handle&.close
        @input_handle = nil
        @chm = nil
      end

      # Extract a file from the CHM archive
      # @param file [Models::CHMFile] File to extract
      # @param output_path [String] Output path for extracted file
      # @return [void]
      def extract(file, output_path)
        raise ArgumentError, "File is nil" if file.nil?
        raise ArgumentError, "File section is nil" if file.section.nil?

        # Handle empty files
        if file.empty?
          @io_system.open(output_path, Constants::MODE_WRITE).close
          return
        end

        case file.section.id
        when 0
          extract_uncompressed(file, output_path)
        when 1
          extract_compressed(file, output_path)
        else
          raise Cabriolet::FormatError, "Invalid section ID: #{file.section.id}"
        end
      end

      # Find a file by name using fast_find
      # @param filename [String] Name of the file to find
      # @return [Models::CHMFile, nil] The file if found, nil otherwise
      def fast_find(filename)
        raise ArgumentError, "CHM not opened" unless @chm

        # Use fast index search if available
        if @chm.index_root < @chm.num_chunks
          fast_search_pmgi(filename)
        else
          # Linear search through PMGL chunks
          fast_search_pmgl(filename)
        end
      end

      private

      # Extract uncompressed file (section 0)
      def extract_uncompressed(file, output_path)
        output_handle = @io_system.open(output_path, Constants::MODE_WRITE)

        # Seek to file data
        offset = @chm.sec0.offset + file.offset
        @input_handle.seek(offset, Constants::SEEK_START)

        # Copy data in chunks
        remaining = file.length
        buffer_size = 4096

        while remaining.positive?
          chunk_size = [buffer_size, remaining].min
          data = @input_handle.read(chunk_size)
          if data.nil?
            raise Cabriolet::ReadError,
                  "Unexpected end of file"
          end

          # It's OK if we read less than chunk_size (e.g., last chunk or EOF)
          # Only raise an error if we read nothing when we expected data
          if data.empty? && remaining.positive?
            raise Cabriolet::ReadError,
                  "Unexpected end of file"
          end

          output_handle.write(data)
          remaining -= data.length
        end

        output_handle.close
      end

      # Extract compressed file (section 1, MSCompressed/LZX)
      def extract_compressed(file, output_path)
        # Initialize LZX decompressor if needed
        init_lzx(file) unless lzx_ready?(file)

        # Seek to correct position in input
        @input_handle.seek(@lzx_input_offset, Constants::SEEK_START)

        # Skip to file offset if needed
        skip_amount = file.offset - @lzx_offset
        if skip_amount.positive?
          # Decompress and discard to a dummy memory handle
          dummy_output = System::MemoryHandle.new("", Constants::MODE_WRITE)
          saved_output = @lzx_state.instance_variable_get(:@output)
          @lzx_state.instance_variable_set(:@output, dummy_output)
          @lzx_state.decompress(skip_amount)
          @lzx_state.instance_variable_set(:@output, saved_output)
          @lzx_offset += skip_amount
        end

        # Decompress to memory buffer
        memory_output = System::MemoryHandle.new("", Constants::MODE_WRITE)
        @lzx_state.instance_variable_set(:@output, memory_output)
        @lzx_state.decompress(file.length)
        @lzx_offset += file.length

        # Save input position for next extraction
        @lzx_input_offset = @input_handle.tell

        # Write buffer to file
        output_handle = @io_system.open(output_path, Constants::MODE_WRITE)
        output_handle.write(memory_output.buffer)
        output_handle.close
      end

      # Check if LZX state is ready for this file
      def lzx_ready?(file)
        return false unless @lzx_state
        return false if file.offset < @lzx_offset

        true
      end

      # Initialize LZX decompressor for section 1
      def init_lzx(file)
        cleanup_lzx

        sec = @chm.sec1

        # Find required system files
        content = sec.content || find_system_file(Parser::CONTENT_NAME)
        control = sec.control || find_system_file(Parser::CONTROL_NAME)

        unless content
          raise Cabriolet::FormatError,
                "MSCompressed Content file not found"
        end
        unless control
          raise Cabriolet::FormatError,
                "ControlData file not found"
        end

        # Read control data
        control_data = read_system_file(control)
        unless control_data.length == 28
          raise Cabriolet::FormatError,
                "ControlData wrong size"
        end

        window_size, reset_interval = parse_control_data(control_data)

        # Calculate window bits
        window_bits = case window_size
                      when 0x008000 then 15
                      when 0x010000 then 16
                      when 0x020000 then 17
                      when 0x040000 then 18
                      when 0x080000 then 19
                      when 0x100000 then 20
                      when 0x200000 then 21
                      else
                        raise Cabriolet::FormatError,
                              "Invalid window size: #{window_size}"
                      end

        # Validate reset interval
        if reset_interval.zero? || (reset_interval % LZX_FRAME_SIZE) != 0
          raise Cabriolet::FormatError,
                "Invalid reset interval: #{reset_interval}"
        end

        # Find reset table entry for this file
        entry = file.offset / reset_interval
        entry *= reset_interval / LZX_FRAME_SIZE

        length, offset = read_reset_table(sec, entry, reset_interval)

        # Calculate input offset
        @lzx_input_offset = @chm.sec0.offset + content.offset + offset

        # Set start offset and length
        @lzx_offset = entry * LZX_FRAME_SIZE
        @lzx_length = length

        # Seek to input position
        @input_handle.seek(@lzx_input_offset, Constants::SEEK_START)

        # Create output handle (will be set per extraction)
        output_handle = System::MemoryHandle.new("")

        # Initialize LZX decompressor
        @lzx_state = @algorithm_factory.create(
          Constants::COMP_TYPE_LZX,
          :decompressor,
          @io_system,
          @input_handle,
          output_handle,
          4096,
          window_bits: window_bits,
          reset_interval: reset_interval / LZX_FRAME_SIZE,
          output_length: length - @lzx_offset,
        )
      end

      # Parse control data to get window size and reset interval
      def parse_control_data(data)
        signature = data[4, 4]
        unless signature == "LZXC"
          raise Cabriolet::SignatureError,
                "Invalid LZXC signature"
        end

        version = data[8, 4].unpack1("V")
        reset_interval = data[12, 4].unpack1("V")
        window_size = data[16, 4].unpack1("V")

        # Adjust for version 2
        if version == 2
          reset_interval *= LZX_FRAME_SIZE
          window_size *= LZX_FRAME_SIZE
        elsif version != 1
          raise Cabriolet::FormatError,
                "Unknown ControlData version: #{version}"
        end

        [window_size, reset_interval]
      end

      # Read reset table entry
      def read_reset_table(sec, entry, reset_interval)
        rtable = sec.rtable || find_system_file(Parser::RTABLE_NAME)

        if rtable
          # Read from reset table
          read_reset_table_entry(rtable, entry, reset_interval)
        else
          # Fall back to SpanInfo
          spaninfo = sec.spaninfo || find_system_file(Parser::SPANINFO_NAME)
          unless spaninfo
            raise Cabriolet::FormatError,
                  "Neither ResetTable nor SpanInfo found"
          end

          length = read_spaninfo(spaninfo)
          [length, 0]
        end
      end

      # Read an entry from the reset table
      def read_reset_table_entry(rtable, entry, reset_interval)
        data = read_system_file(rtable)
        raise Cabriolet::FormatError, "ResetTable too short" if data.length < 40

        # Check frame length
        frame_len = data[32, 8].unpack1("Q<")
        unless frame_len == LZX_FRAME_SIZE
          raise Cabriolet::FormatError,
                "Invalid frame length"
        end

        # Get uncompressed length
        uncomp_len = data[16, 8].unpack1("Q<")

        # Get entry info
        num_entries = data[4, 4].unpack1("V")
        entry_size = data[8, 4].unpack1("V")
        table_offset = data[12, 4].unpack1("V")

        if entry < num_entries && table_offset + (entry * entry_size) + entry_size <= data.length
          pos = table_offset + (entry * entry_size)
          offset = case entry_size
                   when 4 then data[pos, 4].unpack1("V")
                   when 8 then data[pos, 8].unpack1("Q<")
                   else
                     raise Cabriolet::FormatError,
                           "Invalid entry size: #{entry_size}"
                   end

          # Pad length to next reset interval
          length = uncomp_len + reset_interval - 1
          length &= -reset_interval

          [length, offset]
        else
          # Invalid entry, fall back
          [uncomp_len, 0]
        end
      end

      # Read SpanInfo to get uncompressed length
      def read_spaninfo(spaninfo)
        data = read_system_file(spaninfo)
        unless data.length == 8
          raise Cabriolet::FormatError,
                "SpanInfo wrong size"
        end

        length = data.unpack1("Q<")
        unless length.positive?
          raise Cabriolet::FormatError,
                "Invalid SpanInfo length"
        end

        length
      end

      # Find a system file by name
      def find_system_file(name)
        file = @chm.sysfiles
        while file
          return file if file.filename == name

          file = file.next_file
        end
        nil
      end

      # Read a system file's contents
      def read_system_file(file)
        unless file.section.id.zero?
          raise Cabriolet::FormatError,
                "System file must be in section 0"
        end

        offset = @chm.sec0.offset + file.offset
        @input_handle.seek(offset, Constants::SEEK_START)
        @input_handle.read(file.length)
      end

      # Fast search using PMGI index
      def fast_search_pmgi(filename)
        # TODO: Implement PMGI-based binary search
        # For now, fall back to PMGL linear search
        fast_search_pmgl(filename)
      end

      # Fast search using PMGL chunks
      def fast_search_pmgl(filename)
        original_pos = @input_handle.tell

        (@chm.first_pmgl..@chm.last_pmgl).each do |chunk_num|
          offset = @chm.dir_offset + (chunk_num * @chm.chunk_size)
          @input_handle.seek(offset, Constants::SEEK_START)
          chunk = @input_handle.read(@chm.chunk_size)

          next unless chunk && chunk.length == @chm.chunk_size
          next unless chunk[0, 4] == "PMGL"

          file = search_chunk(chunk, filename)
          if file
            @input_handle.seek(original_pos, Constants::SEEK_START)
            return file
          end
        end

        @input_handle.seek(original_pos, Constants::SEEK_START)
        nil
      end

      # Search a chunk for a filename
      def search_chunk(chunk, filename)
        num_entries = chunk[-2, 2].unpack1("v")
        pos = 20
        chunk_end = chunk.length - 2

        num_entries.times do
          break if pos >= chunk_end

          begin
            name_len, pos = Binary::ENCINTReader.read_from_string(chunk, pos)
            break if pos + name_len > chunk_end

            name = chunk[pos, name_len].force_encoding("UTF-8")
            pos += name_len

            section, pos = Binary::ENCINTReader.read_from_string(chunk, pos)
            offset, pos = Binary::ENCINTReader.read_from_string(chunk, pos)
            length, pos = Binary::ENCINTReader.read_from_string(chunk, pos)

            if name == filename
              file = Models::CHMFile.new
              file.filename = name
              file.section = (section.zero? ? @chm.sec0 : @chm.sec1)
              file.offset = offset
              file.length = length
              return file
            end
          rescue Cabriolet::FormatError
            break
          end
        end

        nil
      end

      # Clean up LZX state
      def cleanup_lzx
        @lzx_state = nil
        @lzx_offset = 0
        @lzx_length = 0
      end
    end
  end
end
