# frozen_string_literal: true

require_relative "quickhelp/compressor"
require_relative "winhelp/compressor"

module Cabriolet
  module HLP
    # Main compressor for HLP files
    #
    # Creates HLP files in either QuickHelp or Windows Help format.
    # By default, uses QuickHelp format for compatibility.
    class Compressor
      attr_reader :io_system

      # Initialize compressor
      #
      # @param io_system [System::IOSystem, nil] Custom I/O system or nil for default
      def initialize(io_system = nil)
        @io_system = io_system || System::IOSystem.new
        @quickhelp = QuickHelp::Compressor.new(@io_system)
      end

      # Add a file to the archive
      #
      # @param source_path [String] Path to source file
      # @param hlp_path [String] Path within archive
      # @param compress [Boolean] Whether to compress
      # @return [void]
      def add_file(source_path, hlp_path, compress: true)
        @quickhelp.add_file(source_path, hlp_path, compress: compress)
      end

      # Add data from memory
      #
      # @param data [String] Data to add
      # @param hlp_path [String] Path within archive
      # @param compress [Boolean] Whether to compress
      # @return [void]
      def add_data(data, hlp_path, compress: true)
        @quickhelp.add_data(data, hlp_path, compress: compress)
      end

      # Generate HLP archive (QuickHelp format by default)
      #
      # @param output_file [String] Output file path
      # @param options [Hash] Format options
      # @return [Integer] Bytes written
      def generate(output_file, **options)
        @quickhelp.generate(output_file, **options)
      end

      # Create a Windows Help format HLP file
      #
      # @param output_file [String] Output file path
      # @param options [Hash] Format options
      # @return [WinHelp::Compressor] Compressor for building WinHelp file
      def self.create_winhelp(io_system = nil)
        WinHelp::Compressor.new(io_system)
      end
    end
  end
end
