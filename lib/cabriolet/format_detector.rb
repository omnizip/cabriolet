# frozen_string_literal: true

module Cabriolet
  # Detects archive format based on magic bytes and file structure
  class FormatDetector
    # Magic byte signatures for supported formats
    MAGIC_SIGNATURES = {
      "MSCF" => :cab,
      "ITSF" => :chm,
      "\x3F\x5F" => :hlp,       # ?_
      "\x4C\x4E" => :hlp,       # LN (alternative HLP signature)
      "KWAJ" => :kwaj,
      "SZDD" => :szdd,
      "\x88\xF0\x27\x00" => :szdd, # Alternative SZDD signature
      "ITOLITLS" => :lit,
      "\x00\x00\x00\x00" => :oab, # OAB has null header start
    }.freeze

    # File extension to format mapping (fallback)
    EXTENSION_MAP = {
      ".cab" => :cab,
      ".chm" => :chm,
      ".hlp" => :hlp,
      ".kwj" => :kwaj,
      ".kwaj" => :kwaj,
      ".lit" => :lit,
      ".oab" => :oab,
      ".szdd" => :szdd,
    }.freeze

    class << self
      # Detect format from file path
      #
      # @param path [String] Path to the archive file
      # @return [Symbol, nil] Detected format or nil if unknown
      def detect(path)
        return nil unless File.exist?(path)

        # Try magic byte detection first
        format = detect_by_magic_bytes(path)
        return format if format

        # Fallback to extension-based detection
        detect_by_extension(path)
      end

      # Detect format from IO stream
      #
      # @param io [IO] IO object to read from
      # @return [Symbol, nil] Detected format or nil if unknown
      def detect_from_io(io)
        original_pos = io.pos

        # Read first 16 bytes for magic byte checking
        magic_bytes = io.read(16)
        io.seek(original_pos) if original_pos

        return nil unless magic_bytes && magic_bytes.size >= 4

        detect_magic_bytes(magic_bytes)
      end

      # Detect format and return appropriate parser class
      #
      # @param path [String] Path to the archive file
      # @return [Class, nil] Parser class or nil if unknown format
      def parser_for(path)
        format = detect(path)
        format_to_parser(format) if format
      end

      # Convert format symbol to parser class
      #
      # @param format [Symbol] Format symbol
      # @return [Class, nil] Parser class
      def format_to_parser(format)
        case format
        when :cab
          Cabriolet::CAB::Parser
        when :chm
          Cabriolet::CHM::Parser
        when :hlp
          Cabriolet::HLP::Parser
        when :kwaj
          Cabriolet::KWAJ::Parser
        when :szdd
          Cabriolet::SZDD::Parser
        when :lit
          # LIT parser to be implemented
          nil
        when :oab
          # OAB parser to be implemented
          nil
        end
      end

      private

      def detect_by_magic_bytes(path)
        File.open(path, "rb") do |file|
          magic_bytes = file.read(16)
          detect_magic_bytes(magic_bytes)
        end
      rescue StandardError
        nil
      end

      def detect_magic_bytes(bytes)
        return nil unless bytes && bytes.size >= 4

        # Check each known signature
        MAGIC_SIGNATURES.each do |signature, format|
          if bytes.start_with?(signature) && validate_format(bytes, format)
            # Additional validation for specific formats
            return format
          end
        end

        nil
      end

      def detect_by_extension(path)
        ext = File.extname(path).downcase
        EXTENSION_MAP[ext]
      end

      def validate_format(bytes, format)
        case format
        when :cab
          # Verify CAB header structure
          bytes.size >= 36 && bytes[0..3] == "MSCF"
        when :chm
          # Verify CHM header
          bytes.size >= 8 && bytes[0..3] == "ITSF"
        when :hlp
          # HLP files have either ?_ or LN signature
          bytes.size >= 2 && ["\x3F\x5F", "\x4C\x4E"].include?(bytes[0..1])
        when :kwaj
          # Verify KWAJ header
          bytes.size >= 4 && bytes[0..3] == "KWAJ"
        when :szdd
          # SZDD can have multiple signatures
          bytes.size >= 4 && ["SZDD", "\x88\xF0\x27\x00"].include?(bytes[0..3])
        when :lit
          # Verify LIT header
          bytes.size >= 8 && bytes[0..7] == "ITOLITLS"
        when :oab
          # OAB validation would need more specific checks
          true
        else
          true
        end
      end
    end
  end
end
