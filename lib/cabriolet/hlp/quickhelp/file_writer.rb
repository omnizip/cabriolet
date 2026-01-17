# frozen_string_literal: true

module Cabriolet
  module HLP
    module QuickHelp
      # Writes QuickHelp files to disk
      class FileWriter
        # Initialize file writer
        #
        # @param io_system [System::IOSystem] I/O system for writing
        def initialize(io_system)
          @io_system = io_system
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
          bytes_written += write_topic_index(output_handle,
                                             structure[:header][:offsets])

          # Write context strings
          bytes_written += write_context_strings(output_handle,
                                                 structure[:contexts])

          # Write context map
          bytes_written += write_context_map(output_handle,
                                             structure[:context_map])

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
