# frozen_string_literal: true

module Cabriolet
  module HLP
    module QuickHelp
      # Compressor creates QuickHelp (.HLP) compressed archives
      #
      # QuickHelp files (DOS format) contain topics with Huffman encoding
      # and optional keyword compression using LZSS MODE_MSHELP.
      #
      # NOTE: This implementation is based on the DosHelp project specification
      # for the QuickHelp format used in DOS-era development tools.
      class Compressor
        attr_reader :io_system

        # Default buffer size for I/O operations
        DEFAULT_BUFFER_SIZE = 2048

        # Initialize a new QuickHelp compressor
        #
        # @param io_system [System::IOSystem, nil] Custom I/O system or nil for
        #   default
        # @param algorithm_factory [AlgorithmFactory, nil] Custom algorithm factory or nil for default
        def initialize(io_system = nil, algorithm_factory = nil)
          @io_system = io_system || System::IOSystem.new
          @algorithm_factory = algorithm_factory || Cabriolet.algorithm_factory
          @files = []
        end

        # Add a file to the QuickHelp archive
        #
        # @param source_path [String] Path to source file
        # @param hlp_path [String] Path within QuickHelp archive
        # @param compress [Boolean] Whether to compress the file
        # @return [void]
        def add_file(source_path, hlp_path, compress: true)
          @files << {
            source: source_path,
            hlp_path: hlp_path,
            compress: compress,
          }
        end

        # Add data from memory to the QuickHelp archive
        #
        # @param data [String] Data to add
        # @param hlp_path [String] Path within QuickHelp archive
        # @param compress [Boolean] Whether to compress the data
        # @return [void]
        def add_data(data, hlp_path, compress: true)
          @files << {
            data: data,
            hlp_path: hlp_path,
            compress: compress,
          }
        end

        # Generate HLP archive
        #
        # @param output_file [String] Path to output HLP file
        # @param options [Hash] Compression options
        # @option options [Integer] :version QuickHelp format version (default: 2)
        # @option options [String] :database_name Database name for external links (max 13 chars)
        # @option options [Integer] :control_character Control character (default: 0x3A ':')
        # @option options [Boolean] :case_sensitive Case-sensitive contexts (default: false)
        # @return [Integer] Bytes written to output file
        # @raise [Cabriolet::CompressionError] if compression fails
        def generate(output_file, **options)
          version = options.fetch(:version, 2)
          database_name = options.fetch(:database_name, "")
          control_char = options.fetch(:control_character, 0x3A) # ':'
          case_sensitive = options.fetch(:case_sensitive, false)

          raise ArgumentError, "No files added to archive" if @files.empty?
          raise ArgumentError, "Version must be 2" unless version == 2
          raise ArgumentError, "Database name too long (max 13 chars)" if database_name.length > 13

          # Prepare topics from files
          topics = prepare_topics

          # Build QuickHelp structure
          qh_structure = build_quickhelp_structure(
            topics,
            version,
            database_name,
            control_char,
            case_sensitive,
          )

          # Write to output file
          output_handle = @io_system.open(output_file, Constants::MODE_WRITE)
          begin
            bytes_written = write_quickhelp_file(output_handle, qh_structure)
            bytes_written
          ensure
            @io_system.close(output_handle)
          end
        end

        private

        # Compress all files and collect metadata
        #
        # @return [Array<Hash>] Array of file information hashes
        def compress_all_files
          @files.map do |file_spec|
            compress_file_spec(file_spec)
          end
        end

        # Compress a single file specification
        #
        # @param file_spec [Hash] File specification
        # @return [Hash] File information with compressed data
        def compress_file_spec(file_spec)
          # Get source data
          data = file_spec[:data] || read_file_data(file_spec[:source])

          # Compress if requested
          compressed_data = if file_spec[:compress]
                              compress_data_lzss(data)
                            else
                              data
                            end

          {
            hlp_path: file_spec[:hlp_path],
            uncompressed_size: data.bytesize,
            compressed_data: compressed_data,
            compressed: file_spec[:compress],
          }
        end

        # Read file data from disk
        #
        # @param filename [String] Path to file
        # @return [String] File contents
        def read_file_data(filename)
          handle = @io_system.open(filename, Constants::MODE_READ)
          begin
            data = +""
            loop do
              chunk = @io_system.read(handle, DEFAULT_BUFFER_SIZE)
              break if chunk.empty?

              data << chunk
            end
            data
          ensure
            @io_system.close(handle)
          end
        end

        # Compress data using LZSS MODE_MSHELP
        #
        # @param data [String] Data to compress
        # @return [String] Compressed data
        def compress_data_lzss(data)
          input_handle = System::MemoryHandle.new(data)
          output_handle = System::MemoryHandle.new("", Constants::MODE_WRITE)

          compressor = @algorithm_factory.create(
            :lzss,
            :compressor,
            @io_system,
            input_handle,
            output_handle,
            DEFAULT_BUFFER_SIZE,
            mode: Compressors::LZSS::MODE_MSHELP,
          )

          compressor.compress
          output_handle.data
        end

        # Calculate directory size
        #
        # @param compressed_files [Array<Hash>] Compressed file information
        # @return [Integer] Directory size in bytes
        def calculate_directory_size(compressed_files)
          size = 0
          compressed_files.each do |file_info|
            # 4 bytes for filename length
            # N bytes for filename
            # 4 + 4 + 4 + 1 = 13 bytes for file metadata
            size += 4 + file_info[:hlp_path].bytesize + 13
          end
          size
        end

        # Write QuickHelp header
        #
        # @param output_handle [System::FileHandle] Output file handle
        # @param version [Integer] Format version
        # @param file_count [Integer] Number of files
        # @param directory_offset [Integer] Offset to directory
        # @return [Integer] Number of bytes written
        def write_header(output_handle, version, file_count, directory_offset)
          # NOTE: This is a simplified header format and does not match the actual QuickHelp FileHeader structure
          # TODO: Implement proper QuickHelp FileHeader usage
          header = Binary::HLPStructures::FileHeader.new
          header.signature = Binary::HLPStructures::SIGNATURE
          header.version = version
          header.file_count = file_count
          header.directory_offset = directory_offset

          header_data = header.to_binary_s
          written = @io_system.write(output_handle, header_data)

          unless written == header_data.bytesize
            raise Errors::CompressionError,
                  "Failed to write QuickHelp header"
          end

          written
        end

        # Write file directory
        #
        # @param output_handle [System::FileHandle] Output file handle
        # @param compressed_files [Array<Hash>] Compressed file information
        # @return [Integer] Number of bytes written
        def write_directory(output_handle, compressed_files)
          bytes_written = 0

          compressed_files.each do |file_info|
            # Write filename length
            filename = file_info[:hlp_path].b
            length_data = [filename.bytesize].pack("V")
            bytes_written += @io_system.write(output_handle, length_data)

            # Write filename
            bytes_written += @io_system.write(output_handle, filename)

            # Write file metadata
            metadata = [
              file_info[:offset],
              file_info[:uncompressed_size],
              file_info[:compressed_data].bytesize,
              file_info[:compressed] ? 1 : 0,
            ].pack("V3C")
            bytes_written += @io_system.write(output_handle, metadata)
          end

          bytes_written
        end

        # Write file data
        #
        # @param output_handle [System::FileHandle] Output file handle
        # @param compressed_files [Array<Hash>] Compressed file information
        # @return [Integer] Number of bytes written
        def write_file_data(output_handle, compressed_files)
          bytes_written = 0

          compressed_files.each do |file_info|
            written = @io_system.write(
              output_handle,
              file_info[:compressed_data],
            )
            bytes_written += written
          end

          bytes_written
        end

        # Prepare topics from added files
        #
        # @return [Array<Hash>] Topic information
        def prepare_topics
          @files.map.with_index do |file_spec, index|
            # Get source data
            data = file_spec[:data] || read_file_data(file_spec[:source])

            {
              index: index,
              text: data,
              context: file_spec[:hlp_path],
              compress: file_spec[:compress],
            }
          end
        end

        # Build complete QuickHelp structure
        #
        # @param topics [Array<Hash>] Topic data
        # @param version [Integer] Format version
        # @param database_name [String] Database name
        # @param control_char [Integer] Control character
        # @param case_sensitive [Boolean] Case-sensitive contexts
        # @return [Hash] Complete structure ready for writing
        def build_quickhelp_structure(topics, version, database_name, control_char, case_sensitive)
          structure = {}

          # Compress topics
          structure[:topics] = compress_topics(topics)

          # Build context data
          structure[:contexts] = topics.map { |t| t[:context] }
          structure[:context_map] = topics.map.with_index { |_t, i| i }

          # Calculate offsets
          structure[:offsets] = calculate_offsets(structure)

          # Build header
          structure[:header] = build_header(
            structure,
            version,
            database_name,
            control_char,
            case_sensitive,
          )

          structure
        end

        # Compress all topics
        #
        # @param topics [Array<Hash>] Topic data
        # @return [Array<Hash>] Compressed topics
        def compress_topics(topics)
          topics.map do |topic|
            compressed = if topic[:compress]
                           compress_topic_text(topic[:text])
                         else
                           topic[:text]
                         end

            {
              text: topic[:text],
              compressed: compressed,
              decompressed_length: topic[:text].bytesize,
              compressed_length: compressed.bytesize,
              compress: topic[:compress],
            }
          end
        end

        # Compress topic text using LZSS MODE_MSHELP
        #
        # @param text [String] Topic text
        # @return [String] Compressed data with length header
        def compress_topic_text(text)
          # Compress using LZSS
          input_handle = System::MemoryHandle.new(text)
          output_handle = System::MemoryHandle.new("", Constants::MODE_WRITE)

          compressor = @algorithm_factory.create(
            :lzss,
            :compressor,
            @io_system,
            input_handle,
            output_handle,
            DEFAULT_BUFFER_SIZE,
            mode: Compressors::LZSS::MODE_MSHELP,
          )

          compressor.compress

          # Prepend decompressed length (2 bytes)
          length_header = [text.bytesize].pack("v")
          length_header + output_handle.data
        end

        # Calculate all offsets in the file
        #
        # @param structure [Hash] QuickHelp structure
        # @return [Hash] Calculated offsets
        def calculate_offsets(structure)
          offsets = {}

          # Start after file header (70 bytes = 2 signature + 68 header)
          current_offset = 70

          # Topic index: (topic_count + 1) * 4 bytes
          offsets[:topic_index] = current_offset
          topic_count = structure[:topics].size
          current_offset += (topic_count + 1) * 4

          # Context strings: sum of string lengths + null terminators
          offsets[:context_strings] = current_offset
          structure[:contexts].each do |ctx|
            current_offset += ctx.bytesize + 1 # +1 for null terminator
          end

          # Context map: context_count * 2 bytes
          offsets[:context_map] = current_offset
          current_offset += structure[:context_map].size * 2

          # Keywords: not implemented yet, set to 0
          offsets[:keywords] = 0

          # Huffman tree: not implemented yet, set to 0
          offsets[:huffman_tree] = 0

          # Topic text: starts after context map
          offsets[:topic_text] = current_offset

          # Calculate topic text offsets
          offsets[:topic_offsets] = []
          structure[:topics].each do |topic|
            offsets[:topic_offsets] << (current_offset - offsets[:topic_text])
            current_offset += topic[:compressed_length]
          end
          # Add end marker
          offsets[:topic_offsets] << (current_offset - offsets[:topic_text])

          # Total database size
          offsets[:database_size] = current_offset

          offsets
        end

        # Build file header
        #
        # @param structure [Hash] QuickHelp structure
        # @param version [Integer] Format version
        # @param database_name [String] Database name
        # @param control_char [Integer] Control character
        # @param case_sensitive [Boolean] Case-sensitive contexts
        # @return [Hash] Header information
        def build_header(structure, version, database_name, control_char, case_sensitive)
          attributes = 0
          attributes |= Binary::HLPStructures::Attributes::CASE_SENSITIVE if case_sensitive

          {
            version: version,
            attributes: attributes,
            control_character: control_char,
            topic_count: structure[:topics].size,
            context_count: structure[:contexts].size,
            display_width: 80,
            predefined_ctx_count: 0,
            database_name: database_name.ljust(14, "\x00")[0, 14],
            offsets: structure[:offsets],
          }
        end

        # Write complete QuickHelp file
        #
        # @param output_handle [System::FileHandle] Output file handle
        # @param structure [Hash] QuickHelp structure
        # @return [Integer] Bytes written
        def write_quickhelp_file(output_handle, structure)
          bytes_written = 0

          # Write file header
          bytes_written += write_file_header(output_handle, structure[:header])

          # Write topic index
          bytes_written += write_topic_index(output_handle, structure[:header][:offsets])

          # Write context strings
          bytes_written += write_context_strings(output_handle, structure[:contexts])

          # Write context map
          bytes_written += write_context_map(output_handle, structure[:context_map])

          # Write topic texts
          bytes_written += write_topic_texts(output_handle, structure[:topics])

          bytes_written
        end

        # Write file header
        #
        # @param output_handle [System::FileHandle] Output file handle
        # @param header_info [Hash] Header information
        # @return [Integer] Bytes written
        def write_file_header(output_handle, header_info)
          header = Binary::HLPStructures::FileHeader.new
          header.signature = Binary::HLPStructures::SIGNATURE
          header.version = header_info[:version]
          header.attributes = header_info[:attributes]
          header.control_character = header_info[:control_character]
          header.padding1 = 0
          header.topic_count = header_info[:topic_count]
          header.context_count = header_info[:context_count]
          header.display_width = header_info[:display_width]
          header.padding2 = 0
          header.predefined_ctx_count = header_info[:predefined_ctx_count]
          header.database_name = header_info[:database_name]
          header.reserved1 = 0
          header.topic_index_offset = header_info[:offsets][:topic_index]
          header.context_strings_offset = header_info[:offsets][:context_strings]
          header.context_map_offset = header_info[:offsets][:context_map]
          header.keywords_offset = header_info[:offsets][:keywords]
          header.huffman_tree_offset = header_info[:offsets][:huffman_tree]
          header.topic_text_offset = header_info[:offsets][:topic_text]
          header.reserved2 = 0
          header.reserved3 = 0
          header.database_size = header_info[:offsets][:database_size]

          header_data = header.to_binary_s
          @io_system.write(output_handle, header_data)
        end

        # Write topic index
        #
        # @param output_handle [System::FileHandle] Output file handle
        # @param offsets [Hash] Offset information
        # @return [Integer] Bytes written
        def write_topic_index(output_handle, offsets)
          # Write all topic offsets including end marker
          index_data = offsets[:topic_offsets].pack("V*")
          @io_system.write(output_handle, index_data)
        end

        # Write context strings
        #
        # @param output_handle [System::FileHandle] Output file handle
        # @param contexts [Array<String>] Context strings
        # @return [Integer] Bytes written
        def write_context_strings(output_handle, contexts)
          data = contexts.map { |ctx| "#{ctx}\u0000" }.join
          @io_system.write(output_handle, data)
        end

        # Write context map
        #
        # @param output_handle [System::FileHandle] Output file handle
        # @param context_map [Array<Integer>] Topic indices
        # @return [Integer] Bytes written
        def write_context_map(output_handle, context_map)
          map_data = context_map.pack("v*")
          @io_system.write(output_handle, map_data)
        end

        # Write topic texts
        #
        # @param output_handle [System::FileHandle] Output file handle
        # @param topics [Array<Hash>] Compressed topics
        # @return [Integer] Bytes written
        def write_topic_texts(output_handle, topics)
          total_bytes = 0

          topics.each do |topic|
            total_bytes += @io_system.write(output_handle, topic[:compressed])
          end

          total_bytes
        end
      end
    end
  end
end
