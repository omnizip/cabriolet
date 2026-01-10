# frozen_string_literal: true

require_relative "quickhelp/decompressor"
require_relative "winhelp/decompressor"

module Cabriolet
  module HLP
    # Main decompressor for HLP files
    #
    # Detects the HLP format variant and delegates to the appropriate decompressor:
    # - QuickHelp (DOS format)
    # - Windows Help (WinHelp 3.x/4.x format)
    class Decompressor
      attr_reader :io_system, :parser

      # Initialize decompressor
      #
      # @param io_system [System::IOSystem, nil] Custom I/O system or nil for default
      def initialize(io_system = nil)
        @io_system = io_system || System::IOSystem.new
        @parser = Parser.new(@io_system)
        @delegate = nil
        @current_format = nil
      end

      # Open and parse HLP file
      #
      # @param filename [String] Path to HLP file
      # @return [Models::HLPHeader, Models::WinHelpHeader] Parsed header
      def open(filename)
        @current_format = detect_format(filename)

        case @current_format
        when :quickhelp
          @delegate = QuickHelp::Decompressor.new(@io_system)
          @delegate.open(filename)
        when :winhelp
          @delegate = WinHelp::Decompressor.new(filename, @io_system)
          @delegate.parse
        else
          raise Cabriolet::ParseError, "Unknown HLP format"
        end
      end

      # Close HLP file
      #
      # @param header [Models::HLPHeader, Models::WinHelpHeader] Header to close
      # @return [nil]
      def close(header)
        @delegate&.close(header) if @delegate.respond_to?(:close)
        nil
      end

      # Extract a file
      #
      # @param header [Models::HLPHeader, Models::WinHelpHeader] Parsed header
      # @param hlp_file [Models::HLPFile] File to extract
      # @param output_path [String] Output file path
      # @return [Integer] Bytes written
      def extract_file(header, hlp_file, output_path)
        raise ArgumentError, "Header must not be nil" if header.nil?
        raise ArgumentError, "HLP file must not be nil" if hlp_file.nil?
        raise ArgumentError, "Output path must not be nil" if output_path.nil?

        case @current_format
        when :quickhelp
          @delegate.extract_file(header, hlp_file, output_path)
        when :winhelp
          # WinHelp uses different extraction model
          raise NotImplementedError, "WinHelp file extraction not yet implemented via this API"
        end
      end

      # Extract file to memory
      #
      # @param header [Models::HLPHeader, Models::WinHelpHeader] Parsed header
      # @param hlp_file [Models::HLPFile] File to extract
      # @return [String] File contents
      def extract_file_to_memory(header, hlp_file)
        raise ArgumentError, "Header must not be nil" if header.nil?
        raise ArgumentError, "HLP file must not be nil" if hlp_file.nil?

        case @current_format
        when :quickhelp
          @delegate.extract_file_to_memory(header, hlp_file)
        when :winhelp
          raise NotImplementedError, "WinHelp memory extraction not yet implemented via this API"
        end
      end

      # Extract all files
      #
      # @param header [Models::HLPHeader, Models::WinHelpHeader] Parsed header
      # @param output_dir [String] Output directory
      # @return [Integer] Number of files extracted
      def extract_all(header, output_dir)
        raise ArgumentError, "Header must not be nil" if header.nil?
        raise ArgumentError, "Output directory must not be nil" if output_dir.nil?

        case @current_format
        when :quickhelp
          @delegate.extract_all(header, output_dir)
        when :winhelp
          @delegate.extract_all(output_dir)
        end
      end

      # Extract (alternate API taking filename directly)
      #
      # @param filename [String] Path to HLP file
      # @param output_dir [String] Output directory
      # @return [Integer] Number of files extracted
      def self.extract(filename, output_dir, io_system = nil)
        io_sys = io_system || System::IOSystem.new
        decompressor = new(io_sys)
        header = decompressor.open(filename)
        decompressor.extract_all(header, output_dir)
      end

      private

      # Detect HLP format
      #
      # @param filename [String] Path to file
      # @return [Symbol] :quickhelp or :winhelp
      def detect_format(filename)
        handle = @io_system.open(filename, Constants::MODE_READ)

        begin
          sig_data = @io_system.read(handle, 4)

          # Check QuickHelp signature ("LN" = 0x4C 0x4E)
          return :quickhelp if sig_data[0..1] == Binary::HLPStructures::SIGNATURE

          # Check WinHelp 3.x magic (little-endian 16-bit: 0x35F3)
          magic_word = sig_data[0..1].unpack1("v")
          return :winhelp if magic_word == 0x35F3

          # Check WinHelp 4.x magic (little-endian 32-bit, low 16 bits: 0x5F3F)
          magic_dword = sig_data.unpack1("V")
          return :winhelp if (magic_dword & 0xFFFF) == 0x5F3F

          raise Cabriolet::ParseError, "Unknown HLP format: #{sig_data.bytes.map { |b| format('0x%02X', b) }.join(' ')}"
        ensure
          @io_system.close(handle)
        end
      end
    end
  end
end
