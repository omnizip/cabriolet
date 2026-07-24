# frozen_string_literal: true

module Cabriolet
  # Detects archive format based on magic bytes and file structure.
  #
  # Uses a registry pattern for format→parser mapping. Built-in formats are
  # registered as constants; plugins can register additional parsers at
  # runtime via +register_parser+. This follows the Open/Closed Principle —
  # new formats can be added without modifying existing detection logic.
  class FormatDetector
    # Magic byte signatures for supported formats
    MAGIC_SIGNATURES = {
      "MSCF" => :cab,
      "ITSF" => :chm,
      "\x3F\x5F" => :hlp,
      "\x4C\x4E" => :hlp,
      "KWAJ" => :kwaj,
      "SZDD" => :szdd,
      "\x88\xF0\x27\x00" => :szdd,
      "ITOLITLS" => :lit,
      "\x00\x00\x00\x00" => :oab,
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

    # Built-in parser registry: format symbol → fully-qualified class name.
    # Resolved lazily via const_get so autoload is not triggered until needed.
    BUILTIN_PARSERS = {
      cab: "Cabriolet::CAB::Parser",
      chm: "Cabriolet::CHM::Parser",
      hlp: "Cabriolet::HLP::Parser",
      kwaj: "Cabriolet::KWAJ::Parser",
      szdd: "Cabriolet::SZDD::Parser",
      lit: "Cabriolet::LIT::Parser",
      oab: "Cabriolet::OAB::Decompressor",
    }.freeze

    @registered_parsers = {}

    class << self
      # Register a parser class for a format at runtime.
      #
      # @param format [Symbol] Format identifier
      # @param parser_class [Class] Parser class
      def register_parser(format, parser_class)
        @registered_parsers[format] = parser_class
      end

      # Clear all runtime-registered parsers. Useful for testing.
      def clear_registered_parsers
        @registered_parsers.clear
      end

      # Detect format from file path.
      #
      # @param path [String] Path to the archive file
      # @return [Symbol, nil] Detected format or nil if unknown
      def detect(path)
        return nil unless File.exist?(path)

        format = detect_by_magic_bytes(path)
        return format if format

        detect_by_extension(path)
      end

      # Detect format from IO stream.
      #
      # @param io [IO] IO object to read from
      # @return [Symbol, nil] Detected format or nil if unknown
      def detect_from_io(io)
        original_pos = io.pos
        magic_bytes = io.read(16)
        io.seek(original_pos) if original_pos
        return nil unless magic_bytes && magic_bytes.size >= 4

        detect_magic_bytes(magic_bytes)
      end

      # Detect format and return appropriate parser class.
      #
      # @param path [String] Path to the archive file
      # @return [Class, nil] Parser class or nil if unknown format
      def parser_for(path)
        format = detect(path)
        format_to_parser(format) if format
      end

      # Convert format symbol to parser class.
      #
      # Checks runtime-registered parsers first, then built-in registry.
      # Uses const_get for lazy resolution (triggers autoload).
      #
      # @param format [Symbol] Format symbol
      # @return [Class, nil] Parser class
      def format_to_parser(format)
        @registered_parsers[format] || builtin_parser(format)
      end

      private

      def builtin_parser(format)
        class_name = BUILTIN_PARSERS[format]
        return nil unless class_name

        Object.const_get(class_name)
      end

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

        bytes = bytes.dup.force_encoding(Encoding::BINARY) unless bytes.encoding == Encoding::BINARY

        MAGIC_SIGNATURES.each do |signature, format|
          sig = signature.dup.force_encoding(Encoding::BINARY)
          if bytes.start_with?(sig) && validate_format(bytes, format)
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
          bytes.size >= 4 && bytes[0..3] == "MSCF"
        when :chm
          bytes.size >= 8 && bytes[0..3] == "ITSF"
        when :hlp
          bytes.size >= 2 && ["\x3F\x5F", "\x4C\x4E"].include?(bytes[0..1])
        when :kwaj
          bytes.size >= 4 && bytes[0..3] == "KWAJ"
        when :szdd
          bytes.size >= 4 && ["SZDD", "\x88\xF0\x27\x00"].include?(bytes[0..3])
        when :lit
          bytes.size >= 8 && bytes[0..7] == "ITOLITLS"
        when :oab
          true
        else
          true
        end
      end
    end
  end
end
