# frozen_string_literal: true

require_relative "../../system/io_system"
require_relative "../../constants"

module Cabriolet
  module HLP
    module QuickHelp
      # Parser for QuickHelp (.HLP) files
      #
      # Parses the QuickHelp binary format as specified in the DosHelp project.
      # Structure:
      # - Signature (2 bytes)
      # - File Header (68 bytes)
      # - Topic Index (variable)
      # - Context Strings (variable)
      # - Context Map (variable)
      # - Keywords (optional)
      # - Huffman Tree (optional)
      # - Topic Texts (compressed)
      class Parser
        attr_reader :io_system

        # Initialize parser
        #
        # @param io_system [System::IOSystem, nil] Custom I/O system or nil for default
        def initialize(io_system = nil)
          @io_system = io_system || System::IOSystem.new
        end

        # Parse a QuickHelp file
        #
        # @param filename [String] Path to HLP file
        # @return [Models::HLPHeader] Parsed header with metadata
        # @raise [Cabriolet::ParseError] if file is not valid QuickHelp
        def parse(filename)
          handle = @io_system.open(filename, Constants::MODE_READ)

          begin
            header = parse_file(handle)
            header.filename = filename
            header
          ensure
            @io_system.close(handle)
          end
        end

        private

        # Parse complete QuickHelp file structure
        #
        # @param handle [System::FileHandle] Open file handle
        # @return [Models::HLPHeader] Parsed header
        # @raise [Cabriolet::ParseError] if parsing fails
        def parse_file(handle)
          # Check signature first
          check_signature(handle)

          # Parse file header
          header = parse_header(handle)

          # Parse topic index
          topic_offsets = parse_topic_index(handle, header)

          # Parse context strings and map
          parse_contexts(handle, header)

          # Parse keywords if present
          parse_keywords(handle, header) if header.keywords_offset.positive?

          # Parse Huffman tree if present
          if header.huffman_tree_offset.positive?
            parse_huffman_tree(handle,
                               header)
          end

          # Calculate topic sizes from offsets
          populate_topics(header, topic_offsets)

          header
        end

        # Check file signature
        #
        # @param handle [System::FileHandle] Open file handle
        # @raise [Cabriolet::ParseError] if signature is invalid
        def check_signature(handle)
          sig_data = @io_system.read(handle, 2)

          unless sig_data == Binary::HLPStructures::SIGNATURE
            raise Cabriolet::ParseError,
                  "Invalid QuickHelp signature: expected 'LN' (0x4C 0x4E), " \
                  "got #{sig_data.bytes.map do |b|
                    format('0x%02X', b)
                  end.join(' ')}"
          end
        end

        # Parse file header
        #
        # @param handle [System::FileHandle] Open file handle positioned after signature
        # @return [Models::HLPHeader] Parsed header
        # @raise [Cabriolet::ParseError] if header is invalid
        def parse_header(handle)
          header_data = @io_system.read(handle, 68)
          if header_data.bytesize < 68
            raise Cabriolet::ParseError,
                  "File too small for QuickHelp header"
          end

          binary_header = Binary::HLPStructures::FileHeader.read(
            Binary::HLPStructures::SIGNATURE + header_data,
          )

          # Validate version
          unless binary_header.version == 2
            raise Cabriolet::ParseError,
                  "Unsupported QuickHelp version: #{binary_header.version}"
          end

          # Create header model
          Models::HLPHeader.new(
            magic: binary_header.signature,
            version: binary_header.version,
            attributes: binary_header.attributes,
            control_character: binary_header.control_character,
            topic_count: binary_header.topic_count,
            context_count: binary_header.context_count,
            display_width: binary_header.display_width,
            predefined_ctx_count: binary_header.predefined_ctx_count,
            database_name: binary_header.database_name,
            topic_index_offset: binary_header.topic_index_offset,
            context_strings_offset: binary_header.context_strings_offset,
            context_map_offset: binary_header.context_map_offset,
            keywords_offset: binary_header.keywords_offset,
            huffman_tree_offset: binary_header.huffman_tree_offset,
            topic_text_offset: binary_header.topic_text_offset,
            database_size: binary_header.database_size,
          )
        end

        # Parse topic index section
        #
        # @param handle [System::FileHandle] Open file handle
        # @param header [Models::HLPHeader] Header with offset information
        # @return [Array<Integer>] Topic offsets (including end marker)
        # @raise [Cabriolet::ParseError] if topic index is invalid
        def parse_topic_index(handle, header)
          # Seek to topic index
          @io_system.seek(handle, header.topic_index_offset, Constants::SEEK_START)

          # Read (topic_count + 1) DWORDs
          count = header.topic_count + 1
          index_data = @io_system.read(handle, count * 4)

          if index_data.bytesize < count * 4
            raise Cabriolet::ParseError, "Cannot read complete topic index"
          end

          # Unpack as array of little-endian 32-bit integers
          index_data.unpack("V#{count}")
        end

        # Parse context strings and context map
        #
        # @param handle [System::FileHandle] Open file handle
        # @param header [Models::HLPHeader] Header with offset information
        # @raise [Cabriolet::ParseError] if context data is invalid
        def parse_contexts(handle, header)
          return if header.context_count.zero?

          # Read context strings
          @io_system.seek(handle, header.context_strings_offset, Constants::SEEK_START)
          strings_size = header.context_map_offset - header.context_strings_offset
          strings_data = @io_system.read(handle, strings_size)

          # Split by null terminators
          header.contexts = strings_data.force_encoding(Encoding::ASCII).split("\x00")

          # Read context map
          @io_system.seek(handle, header.context_map_offset, Constants::SEEK_START)
          map_data = @io_system.read(handle, header.context_count * 2)

          if map_data.bytesize < header.context_count * 2
            raise Cabriolet::ParseError, "Cannot read complete context map"
          end

          # Unpack as array of little-endian 16-bit integers
          header.context_map = map_data.unpack("v#{header.context_count}")
        end

        # Parse keywords dictionary
        #
        # @param handle [System::FileHandle] Open file handle
        # @param header [Models::HLPHeader] Header with offset information
        # @raise [Cabriolet::ParseError] if keywords section is invalid
        def parse_keywords(handle, header)
          @io_system.seek(handle, header.keywords_offset, Constants::SEEK_START)

          # Calculate section size
          next_offset = header.huffman_tree_offset.positive? ? header.huffman_tree_offset : header.topic_text_offset
          section_size = next_offset - header.keywords_offset

          return if section_size <= 0

          section_data = @io_system.read(handle, section_size)

          # Parse length-prefixed strings
          header.keywords = []
          pos = 0

          while pos < section_data.bytesize
            length = section_data.getbyte(pos)
            break if length.nil? || length.zero?

            pos += 1
            break if pos + length > section_data.bytesize

            keyword = section_data[pos, length]
            header.keywords << keyword
            pos += length
          end
        end

        # Parse Huffman tree
        #
        # @param handle [System::FileHandle] Open file handle
        # @param header [Models::HLPHeader] Header with offset information
        # @raise [Cabriolet::ParseError] if Huffman tree is invalid
        def parse_huffman_tree(handle, header)
          @io_system.seek(handle, header.huffman_tree_offset, Constants::SEEK_START)

          # Read nodes until we hit terminating 0x0000
          nodes = []
          loop do
            node_data = @io_system.read(handle, 2)
            break if node_data.bytesize < 2

            node_value = node_data.unpack1("v")
            break if node_value.zero? # Terminating null

            nodes << node_value
          end

          # Validate node count (must be odd, representing a proper binary tree)
          if nodes.length.even? && !nodes.empty?
            raise Cabriolet::ParseError,
                  "Invalid Huffman tree: expected odd number of nodes"
          end

          # Store raw node values (will be decoded during decompression)
          header.huffman_tree = nodes
        end

        # Populate topic metadata from offset array
        #
        # @param header [Models::HLPHeader] Header to populate
        # @param offsets [Array<Integer>] Topic offsets
        def populate_topics(header, offsets)
          header.topics = []

          header.topic_count.times do |i|
            topic = Models::HLPTopic.new(
              index: i,
              offset: offsets[i],
              size: offsets[i + 1] - offsets[i],
            )
            header.topics << topic
          end
        end
      end
    end
  end
end
