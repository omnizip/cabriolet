# frozen_string_literal: true

require "bindata"

module Cabriolet
  module Binary
    # CHM ITSF Header (main file header)
    class CHMITSFHeader < BinData::Record
      endian :little

      string :signature, length: 4 # 'ITSF'
      uint32 :version
      uint32 :header_len
      uint32 :unknown1
      uint32 :timestamp
      uint32 :language_id
      string :guid1, length: 16
      string :guid2, length: 16
    end

    # CHM Header Section Table
    class CHMHeaderSectionTable < BinData::Record
      endian :little

      uint64 :offset_hs0
      uint64 :length_hs0
      uint64 :offset_hs1
      uint64 :length_hs1
      uint64 :offset_cs0 # Only in version 3+
    end

    # CHM Header Section 0
    class CHMHeaderSection0 < BinData::Record
      endian :little

      uint32 :unknown1
      uint32 :unknown2
      uint64 :file_len
      uint32 :unknown3
      uint32 :unknown4
    end

    # CHM Header Section 1 (Directory header)
    class CHMHeaderSection1 < BinData::Record
      endian :little

      string :signature, length: 4 # 'ITSP'
      uint32 :version
      uint32 :header_len
      uint32 :unknown1
      uint32 :chunk_size
      uint32 :density
      uint32 :depth
      int32  :index_root
      uint32 :first_pmgl
      uint32 :last_pmgl
      uint32 :unknown2
      uint32 :num_chunks
      uint32 :language_id
      string :guid, length: 16
      uint32 :unknown3
      uint32 :unknown4
      uint32 :unknown5
      uint32 :unknown6
    end

    # PMGL Chunk Header (directory listing chunk)
    class PMGLChunkHeader < BinData::Record
      endian :little

      string :signature, length: 4 # 'PMGL'
      uint32 :quickref_size
      uint32 :unknown1
      int32  :prev_chunk
      int32  :next_chunk
    end

    # PMGI Chunk Header (directory index chunk)
    class PMGIChunkHeader < BinData::Record
      endian :little

      string :signature, length: 4 # 'PMGI'
      uint32 :quickref_size
    end

    # CHM LZX Control Data
    class CHMLZXControlData < BinData::Record
      endian :little

      uint32 :len
      string :signature, length: 4 # 'LZXC'
      uint32 :version
      uint32 :reset_interval
      uint32 :window_size
      uint32 :cache_size
      uint32 :unknown1
    end

    # LZX Reset Table Header
    class LZXResetTableHeader < BinData::Record
      endian :little

      uint32 :unknown1
      uint32 :num_entries
      uint32 :entry_size
      uint32 :table_offset
      uint64 :uncomp_len
      uint64 :comp_len
      uint64 :frame_len
    end

    # Helper class for reading ENCINT (variable-length integers)
    class ENCINTReader
      # Read an ENCINT from an IO stream
      # Returns the integer value
      def self.read(io)
        result = 0
        byte = 0x80
        bytes_read = 0
        max_bytes = 9 # 63 bits max

        while byte.anybits?(0x80) && bytes_read < max_bytes
          byte_data = io.read(1)
          if byte_data.nil?
            raise Cabriolet::FormatError,
                  "Unexpected end of ENCINT"
          end

          byte = byte_data.unpack1("C")
          result = (result << 7) | (byte & 0x7F)
          bytes_read += 1
        end

        if bytes_read == max_bytes && byte.anybits?(0x80)
          raise Cabriolet::FormatError,
                "ENCINT too large"
        end

        result
      end

      # Read an ENCINT from a string at a given position
      # Returns [value, new_position]
      def self.read_from_string(str, pos)
        result = 0
        byte = 0x80
        bytes_read = 0
        max_bytes = 9

        while byte.anybits?(0x80) && bytes_read < max_bytes
          if pos >= str.length
            raise Cabriolet::FormatError,
                  "ENCINT beyond string"
          end

          byte = str.getbyte(pos)
          pos += 1
          result = (result << 7) | (byte & 0x7F)
          bytes_read += 1
        end

        if bytes_read == max_bytes && byte.anybits?(0x80)
          raise Cabriolet::FormatError,
                "ENCINT too large"
        end

        [result, pos]
      end
    end

    # Helper class for writing ENCINT (variable-length integers)
    class ENCINTWriter
      # Write an ENCINT to an IO stream
      # @param io [IO] IO object to write to
      # @param value [Integer] Value to encode
      # @return [Integer] Number of bytes written
      def self.write(io, value)
        bytes = encode(value)
        io.write(bytes)
        bytes.bytesize
      end

      # Encode an integer as ENCINT bytes
      # @param value [Integer] Value to encode (must be non-negative)
      # @return [String] Encoded bytes
      def self.encode(value)
        if value.negative?
          raise ArgumentError,
                "ENCINT value must be non-negative"
        end

        # Special case: zero
        return "\x00".b if value.zero?

        bytes = []

        # Encode 7 bits at a time
        while value.positive?
          byte = value & 0x7F
          value >>= 7
          bytes.unshift(byte)
        end

        # Set high bit on all but last byte
        (0...(bytes.length - 1)).each do |i|
          bytes[i] |= 0x80
        end

        bytes.pack("C*")
      end
    end
  end
end
