# frozen_string_literal: true

require_relative "parser"
require_relative "zeck_lz77"

module Cabriolet
  module HLP
    module WinHelp
      # Decompressor for Windows Help files
      #
      # Extracts and decompresses content from WinHelp files using:
      # - WinHelp::Parser for file structure
      # - ZeckLZ77 for topic decompression
      #
      # Handles both WinHelp 3.x and 4.x formats.
      class Decompressor
        attr_reader :io_system, :header

        # Initialize decompressor
        #
        # @param filename [String] Path to WinHelp file
        # @param io_system [System::IOSystem, nil] Custom I/O system
        def initialize(filename, io_system = nil)
          @filename = filename
          @io_system = io_system || System::IOSystem.new
          @parser = Parser.new(@io_system)
          @zeck = ZeckLZ77.new
          @header = nil
        end

        # Parse the WinHelp file structure
        #
        # @return [Models::WinHelpHeader] Parsed header
        def parse
          @header = @parser.parse(@filename)
        end

        # Extract a specific internal file by name
        #
        # @param filename [String] Internal filename (e.g., "|SYSTEM", "|TOPIC")
        # @return [String, nil] Raw file data or nil if not found
        def extract_internal_file(filename)
          parse unless @header

          file_entry = @header.find_file(filename)
          return nil unless file_entry

          # Open the WinHelp file and seek to file data
          handle = @io_system.open(@filename, Constants::MODE_READ)
          begin
            # Calculate file offset from starting block
            # Block size is typically 4096 bytes
            block_size = 4096
            file_offset = file_entry[:starting_block] * block_size

            @io_system.seek(handle, file_offset, Constants::SEEK_START)
            @io_system.read(handle, file_entry[:file_size])
          ensure
            @io_system.close(handle)
          end
        end

        # Extract |SYSTEM file data
        #
        # @return [String, nil] System file data
        def extract_system_file
          extract_internal_file("|SYSTEM")
        end

        # Extract |TOPIC file data
        #
        # @return [String, nil] Topic file data (compressed)
        def extract_topic_file
          extract_internal_file("|TOPIC")
        end

        # Decompress topic data using Zeck LZ77
        #
        # @param compressed_data [String] Compressed topic data
        # @param output_size [Integer] Expected decompressed size
        # @return [String] Decompressed topic text
        def decompress_topic(compressed_data, output_size)
          @zeck.decompress(compressed_data, output_size)
        end

        # Extract all topics from |TOPIC file
        #
        # This is a simplified implementation that returns raw topic data.
        # Full implementation would parse topic headers and extract individual topics.
        #
        # @return [Array<Hash>] Array of topic hashes with :data key
        def extract_topics
          parse unless @header

          topic_data = extract_topic_file
          return [] unless topic_data

          # For now, return the raw topic data
          # Full implementation would parse topic block headers
          [{
            index: 0,
            data: topic_data,
            compressed: true,
          }]
        end

        # Extract all files to a directory
        #
        # @param output_dir [String] Output directory path
        # @return [Integer] Number of files extracted
        def extract_all(output_dir)
          parse unless @header

          FileUtils.mkdir_p(output_dir)

          count = 0
          @header.internal_files.each do |file_entry|
            data = extract_internal_file(file_entry[:filename])
            next unless data

            # Sanitize filename for file system
            safe_name = file_entry[:filename].gsub("|", "_pipe_")
            output_path = File.join(output_dir, safe_name)

            File.binwrite(output_path, data)
            count += 1
          end

          count
        end

        # Get list of internal filenames
        #
        # @return [Array<String>] Internal file names
        def internal_filenames
          parse unless @header
          @header.internal_filenames
        end

        # Check if |SYSTEM file exists
        #
        # @return [Boolean] true if |SYSTEM present
        def has_system_file?
          parse unless @header
          @header.has_system_file?
        end

        # Check if |TOPIC file exists
        #
        # @return [Boolean] true if |TOPIC present
        def has_topic_file?
          parse unless @header
          @header.has_topic_file?
        end
      end
    end
  end
end
