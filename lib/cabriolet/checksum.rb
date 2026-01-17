# frozen_string_literal: true

module Cabriolet
  # Utility module for checksum calculations
  module Checksum
    # Calculate CAB-style checksum (XOR-based)
    #
    # @param data [String] Data to calculate checksum for
    # @param initial [Integer] Initial checksum value (default: 0)
    # @return [Integer] Checksum value (32-bit)
    def self.calculate(data, initial = 0)
      cksum = initial
      bytes = data.bytes

      # Process 4-byte chunks
      (bytes.size / 4).times do |i|
        offset = i * 4
        value = bytes[offset] |
          (bytes[offset + 1] << 8) |
          (bytes[offset + 2] << 16) |
          (bytes[offset + 3] << 24)
        cksum ^= value
      end

      # Process remaining bytes
      remainder = bytes.size % 4
      if remainder.positive?
        ul = 0
        offset = bytes.size - remainder

        case remainder
        when 3
          ul |= bytes[offset + 2] << 16
          ul |= bytes[offset + 1] << 8
          ul |= bytes[offset]
        when 2
          ul |= bytes[offset + 1] << 8
          ul |= bytes[offset]
        when 1
          ul |= bytes[offset]
        end

        cksum ^= ul
      end

      cksum & 0xFFFFFFFF
    end
  end
end
