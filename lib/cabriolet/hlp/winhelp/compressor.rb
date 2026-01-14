# frozen_string_literal: true

require_relative "zeck_lz77"
require_relative "btree_builder"

module Cabriolet
  module HLP
    module WinHelp
      # Compressor creates Windows Help (.HLP) files
      #
      # Creates WinHelp 3.x and 4.x format files with Zeck LZ77 compression.
      # Supports creating |SYSTEM, |TOPIC, and other internal files.
      class Compressor
        attr_reader :io_system

        # Default block size for WinHelp files (4096 bytes)
        BLOCK_SIZE = 4096

        # Initialize compressor
        #
        # @param io_system [System::IOSystem, nil] Custom I/O system
        def initialize(io_system = nil)
          @io_system = io_system || System::IOSystem.new
          @internal_files = {}
          @version = :winhelp3
        end

        # Add an internal file to the WinHelp archive
        #
        # @param name [String] Internal filename (e.g., "|SYSTEM", "|TOPIC")
        # @param data [String] File data
        # @return [void]
        def add_internal_file(name, data)
          @internal_files[name] = data
        end

        # Add |SYSTEM file with metadata
        #
        # @param options [Hash] System file options
        # @option options [String] :title Help file title
        # @option options [String] :copyright Copyright text
        # @option options [String] :contents Contents file path
        # @return [void]
        def add_system_file(**options)
          system_data = build_system_file(options)
          add_internal_file("|SYSTEM", system_data)
        end

        # Add |TOPIC file with compressed topics
        #
        # @param topics [Array<String>] Array of topic texts
        # @param compress [Boolean] Whether to compress topics
        # @return [void]
        def add_topic_file(topics, compress: true)
          topic_data = build_topic_file(topics, compress)
          add_internal_file("|TOPIC", topic_data)
        end

        # Generate WinHelp file
        #
        # @param output_file [String] Path to output file
        # @param options [Hash] Generation options
        # @option options [Symbol] :version Format version (:winhelp3 or :winhelp4)
        # @return [Integer] Bytes written
        def generate(output_file, **options)
          @version = options.fetch(:version, :winhelp3)

          if @internal_files.empty?
            raise ArgumentError,
                  "No internal files added"
          end
          raise ArgumentError, "Invalid version" unless %i[winhelp3
                                                           winhelp4].include?(@version)

          # Build structure
          structure = build_structure

          # Write to file
          output_handle = @io_system.open(output_file, Constants::MODE_WRITE)
          begin
            write_winhelp_file(output_handle, structure)
          ensure
            @io_system.close(output_handle)
          end
        end

        private

        # Build complete WinHelp structure
        #
        # @return [Hash] Complete structure
        def build_structure
          structure = {
            version: @version,
            internal_files: [],
          }

          # Prepare internal files with block numbers
          block_number = 1 # Block 0 is reserved for header
          @internal_files.each do |name, data|
            # Calculate blocks needed (round up)
            blocks_needed = (data.bytesize.to_f / BLOCK_SIZE).ceil

            structure[:internal_files] << {
              name: name,
              data: data,
              size: data.bytesize,
              starting_block: block_number,
            }

            block_number += blocks_needed
          end

          # Calculate directory offset
          header_size = @version == :winhelp3 ? 28 : 32
          structure[:directory_offset] = header_size

          # Calculate directory size
          dir_size = calculate_directory_size(structure[:internal_files])
          structure[:directory_size] = dir_size

          # Calculate total file size
          structure[:file_size] =
            header_size + dir_size + (block_number * BLOCK_SIZE)

          structure
        end

        # Calculate directory size
        #
        # @param files [Array<Hash>] Internal file list
        # @return [Integer] Directory size in bytes
        def calculate_directory_size(files)
          size = 0
          files.each do |file|
            # 4 bytes size + 2 bytes block + filename + null + padding
            size += 4 + 2 + file[:name].bytesize + 1
            # Align to 2-byte boundary
            size += 1 if size.odd?
          end
          # Add end marker (4 bytes of zeros)
          size + 4
        end

        # Write complete WinHelp file
        #
        # @param output_handle [System::FileHandle] Output handle
        # @param structure [Hash] File structure
        # @return [Integer] Bytes written
        def write_winhelp_file(output_handle, structure)
          bytes_written = 0

          # Write header
          bytes_written += write_header(output_handle, structure)

          # Write directory
          bytes_written += write_directory(output_handle, structure)

          # Pad to first block boundary
          padding_needed = BLOCK_SIZE - (bytes_written % BLOCK_SIZE)
          if padding_needed < BLOCK_SIZE
            bytes_written += @io_system.write(output_handle,
                                              "\x00" * padding_needed)
          end

          # Write file data at block boundaries
          structure[:internal_files].each do |file|
            # Seek to correct block
            target_offset = file[:starting_block] * BLOCK_SIZE
            current_offset = bytes_written

            if target_offset > current_offset
              padding = "\x00" * (target_offset - current_offset)
              bytes_written += @io_system.write(output_handle, padding)
            end

            # Write file data
            bytes_written += @io_system.write(output_handle, file[:data])

            # Pad to block boundary
            remainder = file[:data].bytesize % BLOCK_SIZE
            if remainder.positive?
              padding = "\x00" * (BLOCK_SIZE - remainder)
              bytes_written += @io_system.write(output_handle, padding)
            end
          end

          bytes_written
        end

        # Write file header
        #
        # @param output_handle [System::FileHandle] Output handle
        # @param structure [Hash] File structure
        # @return [Integer] Bytes written
        def write_header(output_handle, structure)
          if structure[:version] == :winhelp3
            write_header_3x(output_handle, structure)
          else
            write_header_4x(output_handle, structure)
          end
        end

        # Write WinHelp 3.x header
        #
        # @param output_handle [System::FileHandle] Output handle
        # @param structure [Hash] File structure
        # @return [Integer] Bytes written
        def write_header_3x(output_handle, structure)
          header = Binary::HLPStructures::WinHelp3Header.new
          header.magic = 0x35F3
          header.unknown = 0x0001
          header.directory_offset = structure[:directory_offset]
          header.free_list_offset = 0
          header.file_size = structure[:file_size]
          header.reserved = "\x00" * 12

          header_data = header.to_binary_s
          @io_system.write(output_handle, header_data)
        end

        # Write WinHelp 4.x header
        #
        # @param output_handle [System::FileHandle] Output handle
        # @param structure [Hash] File structure
        # @return [Integer] Bytes written
        def write_header_4x(output_handle, structure)
          header = Binary::HLPStructures::WinHelp4Header.new
          header.magic = 0x00033F5F # Magic with low 16 bits = 0x3F5F
          header.directory_offset = structure[:directory_offset]
          header.free_list_offset = 0
          header.file_size = structure[:file_size]
          header.reserved = "\x00" * 16

          header_data = header.to_binary_s
          @io_system.write(output_handle, header_data)
        end

        # Write directory
        #
        # @param output_handle [System::FileHandle] Output handle
        # @param structure [Hash] File structure
        # @return [Integer] Bytes written
        def write_directory(output_handle, structure)
          if structure[:version] == :winhelp4
            write_directory_btree(output_handle, structure)
          else
            write_directory_simple(output_handle, structure)
          end
        end

        # Write simple directory (WinHelp 3.x format)
        #
        # @param output_handle [System::FileHandle] Output handle
        # @param structure [Hash] File structure
        # @return [Integer] Bytes written
        def write_directory_simple(output_handle, structure)
          bytes_written = 0

          structure[:internal_files].each do |file|
            # Write file size (4 bytes)
            bytes_written += @io_system.write(output_handle,
                                              [file[:size]].pack("V"))

            # Write starting block (2 bytes)
            bytes_written += @io_system.write(output_handle,
                                              [file[:starting_block]].pack("v"))

            # Write filename with null terminator
            bytes_written += @io_system.write(output_handle,
                                              "#{file[:name]}\u0000")

            # Align to 2-byte boundary
            if bytes_written.odd?
              bytes_written += @io_system.write(output_handle, "\x00")
            end
          end

          # Write end marker
          bytes_written += @io_system.write(output_handle, [0].pack("V"))

          bytes_written
        end

        # Write B+ tree directory (WinHelp 4.x format)
        #
        # @param output_handle [System::FileHandle] Output handle
        # @param structure [Hash] File structure
        # @return [Integer] Bytes written
        def write_directory_btree(output_handle, structure)
          bytes_written = 0

          # Build B+ tree from internal files
          btree = BTreeBuilder.new
          structure[:internal_files].each do |file|
            # Add entry with filename, starting block (offset), and size
            btree.add_entry(file[:name], file[:starting_block] * BLOCK_SIZE,
                            file[:size])
          end

          # Build the tree
          tree = btree.build

          # Write FILEHEADER (9 bytes) before BTREEHEADER
          # FILEHEADER structure:
          # - 4 bytes: reserved_space (reserved space in help file incl. FILEHEADER)
          # - 4 bytes: used_space (used space in help file excl. FILEHEADER)
          # - 1 byte: file_flags (normally 4)
          # For directory, we set these to 0 for now
          file_header = Binary::HLPStructures::WinHelpFileHeader.new
          file_header.reserved_space = 0
          file_header.used_space = 0
          file_header.file_flags = 4
          file_header_data = file_header.to_binary_s
          bytes_written += @io_system.write(output_handle, file_header_data)

          # Write BTREEHEADER (38 bytes)
          header = tree[:header]
          header_data = header.to_binary_s
          bytes_written += @io_system.write(output_handle, header_data)

          # Write pages (sorted by page_num)
          sorted_pages = tree[:pages].sort_by { |p| p[:page_num] }
          sorted_pages.each do |page|
            # Write page data
            bytes_written += @io_system.write(output_handle, page[:data])
          end

          bytes_written
        end

        # Build |SYSTEM file
        #
        # @param options [Hash] System file options
        # @return [String] System file data
        def build_system_file(options)
          data = +""

          # Write title if provided
          if options[:title]
            data << build_system_record(1, options[:title])
          end

          # Write copyright if provided
          if options[:copyright]
            data << build_system_record(2, options[:copyright])
          end

          # Write contents if provided
          if options[:contents]
            data << build_system_record(3, options[:contents])
          end

          data
        end

        # Build a system record
        #
        # @param type [Integer] Record type
        # @param text [String] Record text
        # @return [String] Record data
        def build_system_record(type, text)
          record = +""
          record << [type].pack("v") # Record type (2 bytes)
          record << [text.bytesize + 1].pack("v") # Length including null (2 bytes)
          record << text
          record << "\x00" # Null terminator
          record
        end

        # Build |TOPIC file
        #
        # @param topics [Array<String>] Topic texts
        # @param compress [Boolean] Whether to compress
        # @return [String] Topic file data
        def build_topic_file(topics, compress)
          # Simplified: just concatenate topic data
          # Full implementation would include topic headers and blocks
          data = +""
          zeck = ZeckLZ77.new

          topics.each do |topic_text|
            compressed_data = if compress
                                # Compress using Zeck LZ77
                                zeck.compress(topic_text)
                              else
                                topic_text
                              end

            # Write topic with 2-byte length header
            data << [compressed_data.bytesize].pack("v")
            data << compressed_data
          end

          data
        end
      end
    end
  end
end
