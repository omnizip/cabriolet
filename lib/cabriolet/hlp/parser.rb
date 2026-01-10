# frozen_string_literal: true

require_relative "quickhelp/parser"
require_relative "winhelp/parser"

module Cabriolet
  module HLP
    # Main parser for HLP files
    #
    # Detects the HLP format variant and delegates to the appropriate parser:
    # - QuickHelp (DOS format with "LN" signature)
    # - Windows Help (WinHelp 3.x/4.x format)
    class Parser
      attr_reader :io_system

      # Initialize parser
      #
      # @param io_system [System::IOSystem, nil] Custom I/O system or nil for default
      def initialize(io_system = nil)
        @io_system = io_system || System::IOSystem.new
      end

      # Parse an HLP file
      #
      # @param filename [String] Path to HLP file
      # @return [Models::HLPHeader, Models::WinHelpHeader] Parsed header with metadata
      # @raise [Cabriolet::ParseError] if file is not a valid HLP format
      def parse(filename)
        # Detect format
        format = detect_format(filename)

        # Dispatch to appropriate parser
        case format
        when :quickhelp
          QuickHelp::Parser.new(@io_system).parse(filename)
        when :winhelp
          WinHelp::Parser.new(@io_system).parse(filename)
        else
          raise Cabriolet::ParseError,
                "Unknown HLP format in file: #{filename}"
        end
      end

      private

      # Detect HLP format variant
      #
      # @param filename [String] Path to HLP file
      # @return [Symbol] :quickhelp or :winhelp
      # @raise [Cabriolet::ParseError] if format cannot be determined
      def detect_format(filename)
        handle = @io_system.open(filename, Constants::MODE_READ)

        begin
          # Read first 4 bytes to check signature
          sig_data = @io_system.read(handle, 4)

          # Check QuickHelp signature ("LN" at offset 0)
          if sig_data[0..1] == Binary::HLPStructures::SIGNATURE
            return :quickhelp
          end

          # Check WinHelp 3.x magic (0x35F3 at offset 0, 16-bit)
          magic_word = sig_data[0..1].unpack1("v")
          return :winhelp if magic_word == 0x35F3

          # Check WinHelp 4.x magic (0x5F3F or 0x3F5F in lower 16 bits of 32-bit value)
          magic_dword = sig_data.unpack1("V")
          return :winhelp if (magic_dword & 0xFFFF) == 0x5F3F || (magic_dword & 0xFFFF) == 0x3F5F

          # Unknown format
          raise Cabriolet::ParseError,
                "Unknown HLP signature: #{sig_data.bytes.map { |b| format('0x%02X', b) }.join(' ')}"
        ensure
          @io_system.close(handle)
        end
      end
    end
  end
end
