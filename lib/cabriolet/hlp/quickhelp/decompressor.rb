# frozen_string_literal: true

require_relative "huffman_tree"
require_relative "huffman_stream"
require_relative "compression_stream"

module Cabriolet
  module HLP
    module QuickHelp
      # Decompressor for QuickHelp (.HLP) files
      #
      # Extracts and decompresses topics from QuickHelp databases.
      # Topics can be extracted by index or context string.
      #
      # Each topic contains formatted text lines with:
      # - Text content
      # - Style attributes (bold, italic, underline)
      # - Hyperlinks to other topics or external contexts
      # - Control commands (title, popup, etc.)
      class Decompressor
        attr_reader :io_system, :parser
        attr_accessor :buffer_size

        # Input buffer size for decompression
        DEFAULT_BUFFER_SIZE = 2048

        # Initialize a new HLP decompressor
        #
        # @param io_system [System::IOSystem, nil] Custom I/O system or nil for
        #   default
        # @param algorithm_factory [AlgorithmFactory, nil] Custom algorithm factory or nil for default
        def initialize(io_system = nil, algorithm_factory = nil)
          @io_system = io_system || System::IOSystem.new
          @algorithm_factory = algorithm_factory || Cabriolet.algorithm_factory
          @parser = Parser.new(@io_system)
          @buffer_size = DEFAULT_BUFFER_SIZE
        end

        # Open and parse an HLP file
        #
        # @param filename [String] Path to the HLP file
        # @return [Models::HLPHeader] Parsed header with topics
        # @raise [Errors::ParseError] if the file is not a valid HLP
        def open(filename)
          header = @parser.parse(filename)
          header.filename = filename
          header
        end

        # Close an HLP file (no-op for compatibility)
        #
        # @param _header [Models::HLPHeader] Header to close
        # @return [void]
        def close(_header)
          # No resources to free in the header itself
          # File handles are managed separately during extraction
          nil
        end

        # Extract a file (topic) from HLP archive
        #
        # This is a wrapper around extract_topic_text for API consistency
        # with other format decompressors.
        #
        # @param header [Models::HLPHeader] HLP header from open()
        # @param hlp_file [Models::HLPFile] File entry to extract
        # @param output_path [String] Path to write extracted content
        # @return [void]
        # @raise [ArgumentError] if parameters are invalid
        # @raise [Errors::DecompressionError] if extraction fails
        def extract_file(header, hlp_file, output_path)
          raise ArgumentError, "Header must not be nil" unless header
          raise ArgumentError, "HLP file must not be nil" unless hlp_file
          raise ArgumentError, "Output path must not be nil" unless output_path

          # Find topic by file index
          topic = header.files[hlp_file.index] if hlp_file.respond_to?(:index)
          topic ||= header.topics.find { |t| t.offset == hlp_file.offset } if hlp_file.respond_to?(:offset)

          unless topic
            raise Errors::DecompressionError, "Topic not found for file"
          end

          # Extract topic text
          content = extract_topic_text(header, topic)

          # Write to output file
          File.write(output_path, content)
        end

        # Extract a file (topic) to memory
        #
        # This is a wrapper around extract_topic_text for API consistency
        # with other format decompressors.
        #
        # @param header [Models::HLPHeader] HLP header from open()
        # @param hlp_file [Models::HLPFile] File entry to extract
        # @return [String] Extracted content
        # @raise [ArgumentError] if parameters are invalid
        # @raise [Errors::DecompressionError] if extraction fails
        def extract_file_to_memory(header, hlp_file)
          raise ArgumentError, "Header must not be nil" unless header
          raise ArgumentError, "HLP file must not be nil" unless hlp_file

          # Find topic by file index
          topic = header.files[hlp_file.index] if hlp_file.respond_to?(:index)
          topic ||= header.topics.find { |t| t.offset == hlp_file.offset } if hlp_file.respond_to?(:offset)

          unless topic
            raise Errors::DecompressionError, "Topic not found for file"
          end

          # Extract and return topic text
          extract_topic_text(header, topic)
        end

        # Extract topic text by topic index
        #
        # @param header [Models::HLPHeader] HLP header from open()
        # @param topic_index [Integer] Zero-based topic index
        # @return [String] Plain text content of the topic
        # @raise [Errors::DecompressionError] if extraction fails
        def extract_topic_by_index(header, topic_index)
          raise ArgumentError, "Header must not be nil" unless header
          raise ArgumentError, "Topic index out of range" if topic_index.negative? || topic_index >= header.topic_count

          topic = header.topics[topic_index]
          extract_topic_text(header, topic)
        end

        # Extract topic text by context string
        #
        # @param header [Models::HLPHeader] HLP header from open()
        # @param context_string [String] Context string to look up
        # @return [String, nil] Plain text content of the topic, or nil if not found
        # @raise [Errors::DecompressionError] if extraction fails
        def extract_topic_by_context(header, context_string)
          raise ArgumentError, "Header must not be nil" unless header
          raise ArgumentError, "Context string must not be nil" unless context_string

          # Find topic index from context map
          topic_index = find_topic_index(header, context_string)
          return nil unless topic_index

          extract_topic_by_index(header, topic_index)
        end

        # Extract and parse topic text with formatting
        #
        # @param header [Models::HLPHeader] HLP header from open()
        # @param topic [Models::HLPTopic] Topic to extract
        # @return [String] Plain text content of the topic
        # @raise [Errors::DecompressionError] if extraction fails
        def extract_topic_text(header, topic)
          raise ArgumentError, "Header must not be nil" unless header
          raise ArgumentError, "Topic must not be nil" unless topic

          # Decompress and parse topic
          decompressed_data = decompress_topic(header, topic)
          parse_topic_text(topic, decompressed_data, header.control_char)

          topic.plain_text
        end

        # Extract all topics to a directory
        #
        # @param header [Models::HLPHeader] HLP header from open()
        # @param output_dir [String] Directory to extract topics to
        # @return [Integer] Number of topics extracted
        # @raise [Errors::DecompressionError] if extraction fails
        def extract_all(header, output_dir)
          raise ArgumentError, "Header must not be nil" unless header
          raise ArgumentError, "Output directory must not be nil" unless output_dir

          # Create output directory if needed
          FileUtils.mkdir_p(output_dir)

          extracted = 0
          header.topics.each_with_index do |topic, index|
            # Decompress and parse topic
            decompressed_data = decompress_topic(header, topic)
            parse_topic_text(topic, decompressed_data, header.control_char)

            # Write topic to file
            output_path = ::File.join(output_dir, "topic_#{index.to_s.rjust(4, '0')}.txt")
            File.write(output_path, topic.plain_text)
            extracted += 1
          end

          extracted
        end

        private

        # Find topic index from context string
        #
        # @param header [Models::HLPHeader] Header with context data
        # @param context_string [String] Context string to look up
        # @return [Integer, nil] Topic index or nil if not found
        def find_topic_index(header, context_string)
          # Case-sensitive or case-insensitive comparison
          comparer = header.case_sensitive? ? ->(a, b) { a == b } : ->(a, b) { a.downcase == b.downcase }

          header.contexts.each_with_index do |ctx, idx|
            return header.context_map[idx] if comparer.call(ctx, context_string)
          end

          nil
        end

        # Decompress a topic from the HLP file
        #
        # @param header [Models::HLPHeader] HLP header with compression info
        # @param topic [Models::HLPTopic] Topic to decompress
        # @return [String] Binary decompressed topic data
        # @raise [Cabriolet::DecompressionError] if decompression fails
        def decompress_topic(header, topic)
          handle = @io_system.open(header.filename, Constants::MODE_READ)

          begin
            # Seek to topic data
            @io_system.seek(handle, header.topic_text_offset + topic.offset, Constants::SEEK_START)

            # Read compressed topic data
            compressed_data = @io_system.read(handle, topic.size)

            # Parse decompressed length (first 2 bytes)
            if compressed_data.bytesize < 2
              raise Cabriolet::DecompressionError, "Topic data too short for decompressed length"
            end

            decompressed_length = compressed_data[0, 2].unpack1("v")
            encoded_data = compressed_data[2..]

            # Step 1: Huffman decoding (if tree present)
            compact_data = if header.has_huffman?
                             huffman_decode(encoded_data, header)
                           else
                             encoded_data
                           end

            # Step 2: Keyword decompression (if keywords present)
            decompress_data(compact_data, decompressed_length, header)
          ensure
            @io_system.close(handle) if handle
          end
        end

        # Huffman decode compressed data
        #
        # @param data [String] Binary Huffman-encoded data
        # @param header [Models::HLPHeader] Header with Huffman tree
        # @return [String] Binary Huffman-decoded data
        def huffman_decode(data, header)
          tree = HuffmanTree.deserialize(header.huffman_tree)
          huffman_stream = HuffmanStream.new(data, tree)

          # Read until EOF
          result = String.new(encoding: Encoding::BINARY)
          loop do
            chunk = huffman_stream.read(1024)
            break if chunk.empty?

            result << chunk
          end

          result
        end

        # Decompress data using keyword compression
        #
        # @param data [String] Binary compact data
        # @param output_length [Integer] Expected decompressed length
        # @param header [Models::HLPHeader] Header with keywords
        # @return [String] Binary decompressed data
        def decompress_data(data, output_length, header)
          if header.has_keywords?
            compression_stream = CompressionStream.new(data, header.keywords)
            compression_stream.read(output_length)
          else
            # No keyword compression, return as-is
            data[0, output_length]
          end
        end

        # Parse topic text from decompressed binary data
        #
        # @param topic [Models::HLPTopic] Topic to populate
        # @param data [String] Binary decompressed topic data
        # @param control_char [String] Control character for commands
        # @return [void]
        def parse_topic_text(topic, data, control_char)
          topic.lines = []
          topic.source_data = data
          pos = 0

          while pos < data.bytesize
            # Parse a line
            line, bytes_read = parse_line(data, pos)
            pos += bytes_read

            # Check if line is a command
            unless process_command(line, control_char, topic)
              # Not a command, add to topic
              topic.add_line(line)
            end
          end
        end

        # Parse a single line from topic data
        #
        # @param data [String] Binary topic data
        # @param offset [Integer] Offset to start reading
        # @return [Array<Models::HLPLine, Integer>] Parsed line and bytes read
        # @raise [Cabriolet::DecompressionError] if parsing fails
        def parse_line(data, offset)
          pos = offset

          # Read text length byte
          text_length = data.getbyte(pos)
          raise Cabriolet::DecompressionError, "Unexpected EOF reading text length" if text_length.nil?

          pos += 1

          # Read text (length-1 bytes for the text, last byte is for newline/terminator)
          text_bytes = text_length - 1
          if pos + text_bytes > data.bytesize
            raise Cabriolet::DecompressionError, "Unexpected EOF reading text"
          end

          text = data[pos, text_bytes].force_encoding(Encoding::ASCII)
          pos += text_bytes

          # Create line with text
          line = Models::HLPLine.new(text)

          # Read attribute length byte
          attr_length = data.getbyte(pos)
          raise Cabriolet::DecompressionError, "Unexpected EOF reading attribute length" if attr_length.nil?

          pos += 1

          # Read attribute data (length-1 bytes)
          attr_bytes = attr_length - 1
          if pos + attr_bytes > data.bytesize
            raise Cabriolet::DecompressionError, "Unexpected EOF reading attributes"
          end

          attr_data = data[pos, attr_bytes]
          pos += attr_bytes

          # Parse attributes and hyperlinks
          parse_line_attributes(line, attr_data)

          bytes_read = pos - offset
          [line, bytes_read]
        end

        # Parse line attributes and hyperlinks
        #
        # @param line [Models::HLPLine] Line to populate with attributes
        # @param attr_data [String] Binary attribute data
        # @return [void]
        def parse_line_attributes(line, attr_data)
          pos = 0
          char_index = 0

          # Parse style attributes
          while pos < attr_data.bytesize
            # Check for end of attributes marker (0xFF)
            break if attr_data.getbyte(pos) == 0xFF

            # Read style byte (default for first chunk)
            style = if char_index.zero?
                      Binary::HLPStructures::TextStyle::NONE
                    else
                      attr_data.getbyte(pos)
                      pos += 1
                      break if pos >= attr_data.bytesize # No length byte

                      attr_data.getbyte(pos - 1)
                    end

            # Read chunk length
            if pos >= attr_data.bytesize
              break
            end

            chunk_length = attr_data.getbyte(pos)
            pos += 1

            # Apply style to characters
            chunk_length = [chunk_length, line.length - char_index].min
            line.apply_style(char_index, char_index + chunk_length - 1, style)
            char_index += chunk_length
          end

          # Skip 0xFF marker if present
          pos += 1 if pos < attr_data.bytesize && attr_data.getbyte(pos) == 0xFF

          # Parse hyperlinks
          while pos < attr_data.bytesize
            # Read link start (1-based)
            link_start = attr_data.getbyte(pos)
            pos += 1
            break if pos >= attr_data.bytesize

            # Read link end (1-based)
            link_end = attr_data.getbyte(pos)
            pos += 1

            # Validate link position
            if link_start.zero? || link_start > link_end
              raise Cabriolet::DecompressionError, "Invalid hyperlink position"
            end

            # Read NULL-terminated context string
            context_end = attr_data.index("\x00", pos)
            if context_end.nil?
              # No more data
              break
            end

            context_string = attr_data[pos, context_end - pos]
            pos = context_end + 1

            # Check for numeric link
            if context_string.empty? && pos + 1 < attr_data.bytesize
              # Read WORD for numeric topic index
              numeric_context = attr_data[pos, 2].unpack1("v")
              pos += 2
              context_string = "@L#{format('%04X', numeric_context)}"
            end

            # Apply link to line
            line.apply_link(link_start, link_end, context_string)
          end
        end

        # Process command line
        #
        # @param line [Models::HLPLine] Line to check
        # @param control_char [String] Control character
        # @param topic [Models::HLPTopic] Topic being parsed
        # @return [Boolean] true if line was a command
        def process_command(line, control_char, topic)
          text = line.text
          return false if text.empty?
          return false unless text[0] == control_char

          # Parse command
          return false if text.length < 2

          command_char = text[1]
          parameter = text.length > 2 ? text[2..] : ""

          # Execute command
          case command_char
          when "n" # :n - Topic title
            topic.metadata[:title] = parameter
          when "l" # :l - Window length
            topic.metadata[:window_height] = parameter.to_i
          when "z" # :z - Freeze height
            topic.metadata[:freeze_height] = parameter.to_i
          when "g" # :g - Popup
            topic.metadata[:popup] = true
          when "i" # :i - List
            topic.metadata[:list] = true
          when "x" # :x - Hidden/Command
            topic.metadata[:hidden] = true
          when "u" # :u - Raw
            topic.metadata[:raw] = true
          when "c" # :c - Category
            topic.metadata[:category] = parameter
          when ">" # :> - Next topic
            topic.metadata[:next] = parameter
          when "<" # :< - Previous topic
            topic.metadata[:previous] = parameter
          when "r" # :r - References
            topic.metadata[:references] = parameter.split(",").map(&:strip)
          when "y" # :y - Execute command
            topic.metadata[:execute] = parameter
          when "p" # :p - Paste section
            topic.metadata[:paste] = parameter
          when "e" # :e - End paste section
            topic.metadata[:end_paste] = true
          when "m" # :m - Mark
            topic.metadata[:mark] = parameter
          else
            # Unknown command, treat as text
            return false
          end

          true # Command was processed
        end
      end
    end
  end
end
