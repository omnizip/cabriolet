# frozen_string_literal: true

require_relative "topic_builder"
require_relative "topic_compressor"
require_relative "structure_builder"
require_relative "file_writer"

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
        # @param io_system [System::IOSystem, nil] Custom I/O system or nil for default
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

          if database_name.length > 13
            raise ArgumentError,
                  "Database name too long (max 13 chars)"
          end

          # Prepare topics from files
          topics = prepare_topics

          # Build QuickHelp structure
          structure_builder = StructureBuilder.new(
            version: version,
            database_name: database_name,
            control_char: control_char,
            case_sensitive: case_sensitive,
          )
          qh_structure = structure_builder.build(topics)

          # Write to output file
          output_handle = @io_system.open(output_file, Constants::MODE_WRITE)
          begin
            file_writer = FileWriter.new(@io_system)
            bytes_written = file_writer.write_quickhelp_file(output_handle,
                                                             qh_structure)
            bytes_written
          ensure
            @io_system.close(output_handle)
          end
        end

        private

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
      end
    end
  end
end
