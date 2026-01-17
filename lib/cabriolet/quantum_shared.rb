# frozen_string_literal: true

module Cabriolet
  # Shared Quantum compression constants and models
  # Used by both Compressors::Quantum and Decompressors::Quantum
  module QuantumShared
    # Frame size (32KB per frame)
    FRAME_SIZE = 32_768

    # Match constants
    MIN_MATCH = 3
    MAX_MATCH = 259

    # Position slot tables (same as in qtmd.c)
    POSITION_BASE = [
      0, 1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64, 96, 128, 192, 256, 384,
      512, 768, 1024, 1536, 2048, 3072, 4096, 6144, 8192, 12_288, 16_384,
      24_576, 32_768, 49_152, 65_536, 98_304, 131_072, 196_608, 262_144,
      393_216, 524_288, 786_432, 1_048_576, 1_572_864
    ].freeze

    EXTRA_BITS = [
      0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8,
      9, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 15, 16, 16,
      17, 17, 18, 18, 19, 19
    ].freeze

    LENGTH_BASE = [
      0, 1, 2, 3, 4, 5, 6, 8, 10, 12, 14, 18, 22, 26,
      30, 38, 46, 54, 62, 78, 94, 110, 126, 158, 190, 222, 254
    ].freeze

    LENGTH_EXTRA = [
      0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
      3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0
    ].freeze

    # Represents a symbol in an arithmetic coding model
    class ModelSymbol
      attr_accessor :sym, :cumfreq

      def initialize(sym, cumfreq)
        @sym = sym
        @cumfreq = cumfreq
      end
    end

    # Represents an arithmetic coding model
    class Model
      attr_accessor :shiftsleft, :entries, :syms

      def initialize(syms, entries)
        @syms = syms
        @entries = entries
        @shiftsleft = 4
      end
    end

    # Find position slot for a given offset
    #
    # @param offset [Integer] Position offset
    # @return [Integer] Position slot index
    def self.find_position_slot(offset)
      return 0 if offset < 4

      # Binary search through POSITION_BASE
      low = 1
      high = POSITION_BASE.size - 1

      while low < high
        mid = (low + high + 1) / 2
        if POSITION_BASE[mid] <= offset
          low = mid
        else
          high = mid - 1
        end
      end

      low
    end

    # Find length slot for a given length
    #
    # @param length [Integer] Match length
    # @return [Integer] Length slot index
    def self.find_length_slot(length)
      return 0 if length < 4

      # Binary search through LENGTH_BASE
      low = 1
      high = LENGTH_BASE.size - 1

      while low < high
        mid = (low + high + 1) / 2
        if LENGTH_BASE[mid] <= length
          low = mid
        else
          high = mid - 1
        end
      end

      low
    end
  end
end
