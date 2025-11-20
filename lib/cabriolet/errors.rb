# frozen_string_literal: true

module Cabriolet
  # Base error class for all Cabriolet errors
  class Error < StandardError; end

  # Raised when there's an I/O error
  class IOError < Error; end

  # Raised when parsing a CAB file fails
  class ParseError < Error; end

  # Raised during decompression
  class DecompressionError < Error; end

  # Raised during compression
  class CompressionError < Error; end

  # Raised when a checksum doesn't match
  class ChecksumError < Error; end

  # Raised when an unsupported format is encountered
  class UnsupportedFormatError < Error; end

  # Raised when invalid arguments are provided
  class ArgumentError < ::ArgumentError; end

  # Raised when file signature doesn't match expected format
  class SignatureError < Error; end

  # Raised when file format is invalid or corrupted
  class FormatError < Error; end

  # Raised when read operation fails
  class ReadError < IOError; end

  # Raised when seek operation fails
  class SeekError < IOError; end

  # Raised when plugin operations fail
  class PluginError < Error; end
end
