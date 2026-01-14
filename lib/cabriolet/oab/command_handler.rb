# frozen_string_literal: true

require_relative "../cli/base_command_handler"
require_relative "decompressor"
require_relative "compressor"

module Cabriolet
  module OAB
    # Command handler for OAB (Outlook Offline Address Book) format
    #
    # This handler implements the unified command interface for OAB files,
    # wrapping the existing OAB::Decompressor and OAB::Compressor classes.
    # OAB files use LZX compression for address book data.
    #
    # Unlike other formats, OAB is a compressed data format rather than
    # an archive - the "list" command displays header information only.
    #
    class CommandHandler < Commands::BaseCommandHandler
      # List OAB file information
      #
      # Displays information about the OAB file including version,
      # block size, and target size.
      #
      # @param file [String] Path to the OAB file
      # @param options [Hash] Additional options (unused)
      # @return [void]
      def list(file, _options = {})
        validate_file_exists(file)

        display_oab_info(file)
      end

      # Extract/decompress OAB file
      #
      # Decompresses the OAB file to its original form.
      # Auto-detects output filename if not specified.
      #
      # @param file [String] Path to the OAB file
      # @param output_dir [String] Output directory (not typically used for OAB)
      # @param options [Hash] Additional options
      # @option options [String] :output Output file path
      # @option options [String] :base_file Base file for incremental patches
      # @return [void]
      def extract(file, output_dir = nil, options = {})
        validate_file_exists(file)

        output = options[:output]

        # Auto-detect output name if not provided
        if output.nil? && output_dir.nil?
          output = auto_output_filename(file)
        end

        # If output_dir is specified, construct output path
        if output.nil? && output_dir
          base_name = File.basename(file, ".*")
          output = File.join(output_dir, base_name)
        end

        decompressor = Decompressor.new

        # Check if this is an incremental patch
        if options[:base_file]
          base_file = options[:base_file]
          validate_file_exists(base_file)

          puts "Applying incremental patch: #{file} + #{base_file} -> #{output}" if verbose?
          bytes = decompressor.decompress_incremental(file, base_file, output)
          puts "Applied patch to #{output} (#{bytes} bytes)"
        else
          puts "Decompressing #{file} -> #{output}" if verbose?
          bytes = decompressor.decompress(file, output)
          puts "Decompressed #{file} to #{output} (#{bytes} bytes)"
        end
      end

      # Create OAB compressed file
      #
      # Compresses a file using OAB LZX compression.
      #
      # @param output [String] Output OAB file path
      # @param files [Array<String>] Input file (single file for OAB)
      # @param options [Hash] Additional options
      # @option options [Integer] :block_size Block size for compression
      # @option options [String] :base_file Base file for creating incremental patch
      # @return [void]
      # @raise [ArgumentError] if no file specified or multiple files
      def create(output, files = [], options = {})
        raise ArgumentError, "No file specified" if files.empty?

        if files.size > 1
          raise ArgumentError,
                "OAB format supports only one file at a time"
        end

        file = files.first
        unless File.exist?(file)
          raise ArgumentError,
                "File does not exist: #{file}"
        end

        compressor = Compressor.new

        # Auto-generate output name if not provided
        if output.nil?
          output = "#{file}.oab"
        end

        if options[:base_file]
          base_file = options[:base_file]
          unless File.exist?(base_file)
            raise ArgumentError,
                  "Base file does not exist: #{base_file}"
          end

          puts "Creating incremental patch: #{file} - #{base_file} -> #{output}" if verbose?
          bytes = compressor.compress_incremental(file, base_file, output,
                                                  **options)
          puts "Created incremental patch #{output} (#{bytes} bytes)"
        else
          block_size = options[:block_size]
          puts "Compressing #{file} -> #{output} (block_size: #{block_size || 'default'})" if verbose?
          bytes = compressor.compress(file, output, **options)
          puts "Compressed #{file} to #{output} (#{bytes} bytes)"
        end
      end

      # Display detailed OAB file information
      #
      # @param file [String] Path to the OAB file
      # @param options [Hash] Additional options (unused)
      # @return [void]
      def info(file, _options = {})
        validate_file_exists(file)

        display_oab_info(file)
      end

      # Test OAB file integrity
      #
      # Verifies the OAB file structure.
      #
      # @param file [String] Path to the OAB file
      # @param options [Hash] Additional options (unused)
      # @return [void]
      def test(file, _options = {})
        validate_file_exists(file)

        puts "Testing #{file}..."

        # Try to read and validate header
        decompressor = Decompressor.new
        # We can't easily test without decompressing, so we attempt to read the header
        io_system = decompressor.io_system
        handle = io_system.open(file, Constants::MODE_READ)

        begin
          header_data = io_system.read(handle, 16)
          if header_data.length < 16
            puts "ERROR: Failed to read OAB header"
            return
          end

          # Check if it's a full file or patch file
          full_header = Binary::OABStructures::FullHeader.read(header_data)
          if full_header.valid?
            puts "OK: OAB full file structure is valid"
            puts "Version: #{full_header.version_hi}.#{full_header.version_lo}"
            puts "Target size: #{full_header.target_size} bytes"
            puts "Block max: #{full_header.block_max} bytes"
          else
            # Check for patch header
            patch_header = Binary::OABStructures::PatchHeader.read(header_data)
            if patch_header.valid?
              puts "OK: OAB patch file structure is valid"
              puts "Version: #{patch_header.version_hi}.#{patch_header.version_lo}"
              puts "Target size: #{patch_header.target_size} bytes"
              puts "Source size: #{patch_header.source_size} bytes"
            else
              puts "ERROR: Invalid OAB header signature"
            end
          end
        rescue StandardError => e
          puts "ERROR: OAB file validation failed: #{e.message}"
        ensure
          io_system.close(handle)
        end
      end

      private

      # Display OAB file information
      #
      # @param file [String] Path to the OAB file
      # @return [void]
      def display_oab_info(file)
        puts "OAB File Information"
        puts "=" * 50
        puts "Filename: #{file}"

        decompressor = Decompressor.new
        io_system = decompressor.io_system
        handle = io_system.open(file, Constants::MODE_READ)

        begin
          header_data = io_system.read(handle, 28) # Read enough for both header types

          # Try full file header first
          full_header = Binary::OABStructures::FullHeader.read(header_data[0,
                                                                           16])
          if full_header.valid?
            puts "Type: Full OAB file"
            puts "Version: #{full_header.version_hi}.#{full_header.version_lo}"
            puts "Target size: #{full_header.target_size} bytes"
            puts "Block max: #{full_header.block_max} bytes"
            return
          end

          # Try patch file header
          patch_header = Binary::OABStructures::PatchHeader.read(header_data[0,
                                                                             28])
          if patch_header.valid?
            puts "Type: Incremental OAB patch"
            puts "Version: #{patch_header.version_hi}.#{patch_header.version_lo}"
            puts "Target size: #{patch_header.target_size} bytes"
            puts "Source size: #{patch_header.source_size} bytes"
            puts "Source CRC: 0x#{patch_header.source_crc.to_s(16).upcase}"
            puts "Target CRC: 0x#{patch_header.target_crc.to_s(16).upcase}"
            return
          end

          puts "Type: Unknown (invalid header)"
        rescue StandardError => e
          puts "Error reading OAB header: #{e.message}"
        ensure
          io_system.close(handle)
        end
      end

      # Auto-detect output filename from OAB file
      #
      # @param file [String] Original file path
      # @return [String] Detected output filename
      def auto_output_filename(file)
        # Remove .oab extension if present, otherwise just return the basename
        base_name = File.basename(file, ".*")
        # If the file doesn't end with .oab, keep the original name
        if file.end_with?(".oab")
          base_name
        else
          # Return with .dat extension (common for decompressed OAB)
          "#{base_name}.dat"
        end
      end
    end
  end
end
