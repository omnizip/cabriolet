# frozen_string_literal: true

module Cabriolet
  module KWAJ
    # Compressor creates KWAJ compressed files
    #
    # KWAJ files support multiple compression methods:
    # - NONE: Direct copy
    # - XOR: XOR with 0xFF "encryption"
    # - SZDD: LZSS compression
    # - MSZIP: DEFLATE compression
    #
    # KWAJ headers contain optional fields controlled by flag bits:
    # - Uncompressed length (4 bytes)
    # - Filename (up to 9 bytes, null-terminated)
    # - File extension (up to 4 bytes, null-terminated)
    # - Extra data (2 bytes length + variable data)
    class Compressor
      attr_reader :io_system

      # Initialize a new KWAJ compressor
      #
      # @param io_system [System::IOSystem, nil] Custom I/O system or nil for
      #   default
      # @param algorithm_factory [AlgorithmFactory, nil] Custom algorithm factory or nil for default
      def initialize(io_system = nil, algorithm_factory = nil)
        @io_system = io_system || System::IOSystem.new
        @algorithm_factory = algorithm_factory || Cabriolet.algorithm_factory
      end

      # Compress a file to KWAJ format
      #
      # @param input_file [String] Path to input file
      # @param output_file [String] Path to output KWAJ file
      # @param options [Hash] Compression options
      # @option options [Symbol] :compression Compression type (:none, :xor,
      #   :szdd, :mszip), default: :szdd
      # @option options [Boolean] :include_length Include uncompressed length
      #   in header
      # @option options [String] :filename Original filename to embed
      # @option options [String] :extra_data Extra data to include
      # @return [Integer] Bytes written to output file
      # @raise [Error] if compression fails
      def compress(input_file, output_file, **options)
        compression_type = options.fetch(:compression, :szdd)
        include_length = options.fetch(:include_length, false)
        filename = options[:filename]
        extra_data = options[:extra_data]

        validate_compression_type(compression_type)

        input_handle = @io_system.open(input_file, Constants::MODE_READ)
        output_handle = @io_system.open(output_file, Constants::MODE_WRITE)

        begin
          # Get input size
          input_size = @io_system.seek(input_handle, 0, Constants::SEEK_END)
          @io_system.seek(input_handle, 0, Constants::SEEK_START)

          # Write header
          header_bytes = write_header(
            output_handle,
            compression_type,
            input_size,
            include_length,
            filename,
            extra_data,
          )

          # Compress data
          compressed_bytes = compress_data_stream(
            compression_type,
            input_handle,
            output_handle,
          )

          header_bytes + compressed_bytes
        ensure
          @io_system.close(input_handle) if input_handle
          @io_system.close(output_handle) if output_handle
        end
      end

      # Compress data from memory to KWAJ format
      #
      # @param data [String] Input data to compress
      # @param output_file [String] Path to output KWAJ file
      # @param options [Hash] Compression options
      # @option options [Symbol] :compression Compression type (:none, :xor,
      #   :szdd, :mszip), default: :szdd
      # @option options [Boolean] :include_length Include uncompressed length
      #   in header
      # @option options [String] :filename Original filename to embed
      # @option options [String] :extra_data Extra data to include
      # @return [Integer] Bytes written to output file
      # @raise [Error] if compression fails
      def compress_data(data, output_file, **options)
        compression_type = options.fetch(:compression, :szdd)
        include_length = options.fetch(:include_length, false)
        filename = options[:filename]
        extra_data = options[:extra_data]

        validate_compression_type(compression_type)

        input_handle = System::MemoryHandle.new(data)
        output_handle = @io_system.open(output_file, Constants::MODE_WRITE)

        begin
          # Write header
          header_bytes = write_header(
            output_handle,
            compression_type,
            data.bytesize,
            include_length,
            filename,
            extra_data,
          )

          # Compress data
          compressed_bytes = compress_data_stream(
            compression_type,
            input_handle,
            output_handle,
          )

          header_bytes + compressed_bytes
        ensure
          @io_system.close(output_handle) if output_handle
        end
      end

      private

      # Write KWAJ header to output
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param compression_type [Symbol] Compression type
      # @param uncompressed_size [Integer] Size of uncompressed data
      # @param include_length [Boolean] Include length field
      # @param filename [String, nil] Original filename
      # @param extra_data [String, nil] Extra data
      # @return [Integer] Number of bytes written
      def write_header(output_handle, compression_type, uncompressed_size,
                       include_length, filename, extra_data)
        # Build header flags
        flags = 0
        flags |= Constants::KWAJ_HDR_HASLENGTH if include_length

        # Split filename if provided
        name_part = nil
        ext_part = nil
        if filename
          name_part, ext_part = split_filename(filename)
          flags |= Constants::KWAJ_HDR_HASFILENAME if name_part
          flags |= Constants::KWAJ_HDR_HASFILEEXT if ext_part
        end

        # Extra data flag
        flags |= Constants::KWAJ_HDR_HASEXTRATEXT if extra_data

        # Calculate data offset
        data_offset = calculate_data_offset(
          include_length,
          name_part,
          ext_part,
          extra_data,
        )

        # Write base header
        bytes_written = write_base_header(
          output_handle,
          compression_type_to_constant(compression_type),
          data_offset,
          flags,
        )

        # Write optional fields
        if include_length
          bytes_written += write_length_field(output_handle,
                                              uncompressed_size)
        end

        if name_part
          bytes_written += write_filename_field(output_handle,
                                                name_part)
        end

        if ext_part
          bytes_written += write_extension_field(output_handle,
                                                 ext_part)
        end

        if extra_data
          bytes_written += write_extra_data_field(output_handle,
                                                  extra_data)
        end

        bytes_written
      end

      # Write KWAJ base header (14 bytes)
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param comp_method [Integer] Compression method constant
      # @param data_offset [Integer] Offset to compressed data
      # @param flags [Integer] Header flags
      # @return [Integer] Number of bytes written (14)
      def write_base_header(output_handle, comp_method, data_offset, flags)
        header = Binary::KWAJStructures::BaseHeader.new
        header.signature1 = Binary::KWAJStructures::SIGNATURE1
        header.signature2 = Binary::KWAJStructures::SIGNATURE2
        header.comp_method = comp_method
        header.data_offset = data_offset
        header.flags = flags

        header_data = header.to_binary_s
        written = @io_system.write(output_handle, header_data)

        unless written == header_data.bytesize
          raise Error,
                "Failed to write KWAJ base header"
        end

        written
      end

      # Write length field (4 bytes)
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param length [Integer] Uncompressed length
      # @return [Integer] Number of bytes written (4)
      def write_length_field(output_handle, length)
        field = Binary::KWAJStructures::LengthField.new
        field.uncompressed_length = length

        field_data = field.to_binary_s
        written = @io_system.write(output_handle, field_data)

        unless written == field_data.bytesize
          raise Error,
                "Failed to write length field"
        end

        written
      end

      # Write filename field (null-terminated)
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param filename [String] Filename (max 8 chars)
      # @return [Integer] Number of bytes written
      def write_filename_field(output_handle, filename)
        # Truncate to 8 characters and add null terminator
        name = filename[0, 8]
        data = "#{name}\x00"
        written = @io_system.write(output_handle, data)

        unless written == data.bytesize
          raise Error,
                "Failed to write filename field"
        end

        written
      end

      # Write extension field (null-terminated)
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param extension [String] Extension (max 3 chars)
      # @return [Integer] Number of bytes written
      def write_extension_field(output_handle, extension)
        # Truncate to 3 characters and add null terminator
        ext = extension[0, 3]
        data = "#{ext}\x00"
        written = @io_system.write(output_handle, data)

        unless written == data.bytesize
          raise Error,
                "Failed to write extension field"
        end

        written
      end

      # Write extra data field (2 bytes length + data)
      #
      # @param output_handle [System::FileHandle] Output file handle
      # @param extra_data [String] Extra data
      # @return [Integer] Number of bytes written
      def write_extra_data_field(output_handle, extra_data)
        field = Binary::KWAJStructures::ExtraTextField.new
        field.text_length = extra_data.bytesize
        field.data = extra_data

        field_data = field.to_binary_s
        written = @io_system.write(output_handle, field_data)

        unless written == field_data.bytesize
          raise Error,
                "Failed to write extra data field"
        end

        written
      end

      # Compress data stream using selected compression method
      #
      # @param compression_type [Symbol] Compression type
      # @param input_handle [System::FileHandle] Input handle
      # @param output_handle [System::FileHandle] Output handle
      # @return [Integer] Number of bytes written
      def compress_data_stream(compression_type, input_handle, output_handle)
        case compression_type
        when :none
          compress_none(input_handle, output_handle)
        when :xor
          compress_xor(input_handle, output_handle)
        when :szdd
          compress_szdd(input_handle, output_handle)
        when :mszip
          compress_mszip(input_handle, output_handle)
        else
          raise Error,
                "Unsupported compression type: #{compression_type}"
        end
      end

      # Compress with NONE method (direct copy)
      #
      # @param input_handle [System::FileHandle] Input handle
      # @param output_handle [System::FileHandle] Output handle
      # @return [Integer] Number of bytes written
      def compress_none(input_handle, output_handle)
        bytes_written = 0
        buffer_size = 2048

        loop do
          data = @io_system.read(input_handle, buffer_size)
          break if data.empty?

          written = @io_system.write(output_handle, data)
          bytes_written += written
        end

        bytes_written
      end

      # Compress with XOR method (XOR each byte with 0xFF)
      #
      # @param input_handle [System::FileHandle] Input handle
      # @param output_handle [System::FileHandle] Output handle
      # @return [Integer] Number of bytes written
      def compress_xor(input_handle, output_handle)
        bytes_written = 0
        buffer_size = 2048

        loop do
          data = @io_system.read(input_handle, buffer_size)
          break if data.empty?

          # XOR each byte with 0xFF
          xored = data.bytes.map { |b| b ^ 0xFF }.pack("C*")

          written = @io_system.write(output_handle, xored)
          bytes_written += written
        end

        bytes_written
      end

      # Compress with SZDD method (LZSS compression)
      #
      # @param input_handle [System::FileHandle] Input handle
      # @param output_handle [System::FileHandle] Output handle
      # @return [Integer] Number of bytes written
      def compress_szdd(input_handle, output_handle)
        compressor = @algorithm_factory.create(
          :lzss,
          :compressor,
          @io_system,
          input_handle,
          output_handle,
          2048,
          mode: Compressors::LZSS::MODE_QBASIC,
        )
        compressor.compress
      end

      # Compress with MSZIP method (DEFLATE compression)
      #
      # @param input_handle [System::FileHandle] Input handle
      # @param output_handle [System::FileHandle] Output handle
      # @return [Integer] Number of bytes written
      # @raise [Error] MSZIP compressor not yet implemented
      def compress_mszip(_input_handle, _output_handle)
        raise Error,
              "MSZIP compression is not yet implemented. " \
              "Use SZDD compression instead."
      end

      # Calculate data offset based on optional fields
      #
      # @param include_length [Boolean] Whether length field is included
      # @param name_part [String, nil] Filename part
      # @param ext_part [String, nil] Extension part
      # @param extra_data [String, nil] Extra data
      # @return [Integer] Data offset in bytes
      def calculate_data_offset(include_length, name_part, ext_part, extra_data)
        offset = 14 # Base header size

        offset += 4 if include_length

        if name_part
          # Filename is truncated to 8 chars + null terminator
          offset += [name_part.length, 8].min + 1
        end

        if ext_part
          # Extension is truncated to 3 chars + null terminator
          offset += [ext_part.length, 3].min + 1
        end

        if extra_data
          # 2 bytes for length + data
          offset += 2 + extra_data.bytesize
        end

        offset
      end

      # Split filename into name and extension parts
      #
      # @param filename [String] Filename to split
      # @return [Array<String, String>] [name, extension] (extension may be nil)
      def split_filename(filename)
        # Remove directory path if present
        basename = ::File.basename(filename)

        # Split on last dot
        if basename.include?(".")
          parts = basename.rpartition(".")
          name = parts[0]
          ext = parts[2]
          [name, ext.empty? ? nil : ext]
        else
          [basename, nil]
        end
      end

      # Convert compression type symbol to constant
      #
      # @param compression_type [Symbol] Compression type
      # @return [Integer] Compression type constant
      def compression_type_to_constant(compression_type)
        case compression_type
        when :none
          Constants::KWAJ_COMP_NONE
        when :xor
          Constants::KWAJ_COMP_XOR
        when :szdd
          Constants::KWAJ_COMP_SZDD
        when :mszip
          Constants::KWAJ_COMP_MSZIP
        else
          raise ArgumentError, "Unknown compression type: #{compression_type}"
        end
      end

      # Validate compression type parameter
      #
      # @param compression_type [Symbol] Compression type to validate
      # @raise [ArgumentError] if compression type is invalid
      def validate_compression_type(compression_type)
        valid_types = %i[none xor szdd mszip]
        return if valid_types.include?(compression_type)

        raise ArgumentError,
              "Compression type must be one of #{valid_types.inspect}, " \
              "got #{compression_type.inspect}"
      end
    end
  end
end
