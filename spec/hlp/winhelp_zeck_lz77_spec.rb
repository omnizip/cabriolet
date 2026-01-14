# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::HLP::WinHelp::ZeckLZ77 do
  let(:decompressor) { described_class.new }

  describe "#decompress" do
    context "with literal bytes only" do
      it "decompresses simple literal bytes" do
        # Flag byte: 0x00 (all 8 bits = 0, all literals)
        # Followed by 8 literal bytes
        input = [0x00, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47,
                 0x48].pack("C*")
        expected = "ABCDEFGH"

        result = decompressor.decompress(input, expected.bytesize)
        expect(result).to eq(expected)
      end

      it "handles multiple flag bytes with literals" do
        # Two flag bytes, 16 literal bytes total
        input = [0x00, *"ABCDEFGH".bytes, 0x00,
                 *"12345678".bytes].pack("C*")
        expected = "ABCDEFGH12345678"

        result = decompressor.decompress(input, expected.bytesize)
        expect(result).to eq(expected)
      end
    end

    context "with short matches (length 3-18)" do
      it "decompresses a simple match" do
        # Setup: "ABCABC" - second ABC is a match
        # "ABC" (3 literals) then match offset=3, length=3
        # Flag: 0x08 (bit 3 set = token 3 is match)
        # 3 literals: A, B, C
        # Match: offset=3 (0x00 0x03), length=3 (encoded as 0)
        input = +""
        input << [0x08].pack("C") # Flag: bit 3 = match
        input << "ABC" # 3 literals
        input << [0x00, 0x03].pack("CC") # Match: offset=3, length=3

        expected = "ABCABC"
        result = decompressor.decompress(input, expected.bytesize)
        expect(result).to eq(expected)
      end

      it "handles match with offset encoding" do
        # Test different offset values
        # Create pattern then match it
        input = +""
        input << [0x10].pack("C")       # Flag: bit 4 = match
        input << "TEST"                 # 4 literals
        input << [0x00, 0x04].pack("CC") # Match: offset=4, length=3

        expected = "TESTTES"
        result = decompressor.decompress(input, expected.bytesize)
        expect(result).to eq(expected)
      end
    end

    context "with long matches (length 19-271)" do
      it "decompresses match with extra length byte" do
        # Match with length > 18 requires extra byte
        # Flag with match, then 20 literals, then long match
        input = +""
        input << [0x80].pack("C") # Flag: bit 7 = match

        # First 7 literals
        input << ("A" * 7)

        # Match: offset=7, length=20 (needs extra byte)
        # Length field = 15 (0x0F) triggers extra byte
        # Extra byte = 1 (means length = 1 + 19 = 20)
        input << [0x0F, 0x07, 0x01].pack("CCC")

        expected = "A" * 27 # 7 literals + 20 from match
        result = decompressor.decompress(input, expected.bytesize)
        expect(result).to eq(expected)
      end
    end

    context "with mixed literals and matches" do
      it "handles complex pattern" do
        # "HELLO WORLD HELLO"
        # "HELLO WORLD " (12 bytes literal)
        # "HELLO" (5 bytes match from offset 12)
        input = +""

        # First flag: 8 literals
        input << [0x00].pack("C")
        input << "HELLO WO" # 8 bytes

        # Second flag: 4 literals, then match at bit 4
        input << [0x10].pack("C") # Flag: bit 4 = match
        input << "RLD "                  # 4 more literals (12 total)
        input << [0x02, 0x0C].pack("CC") # Match: offset=12, length=5

        expected = "HELLO WORLD HELLO"
        result = decompressor.decompress(input, expected.bytesize)
        expect(result).to eq(expected)
      end
    end

    context "with overlapping matches" do
      it "handles match that extends beyond window" do
        # Pathological case: match overlaps with itself
        # "AAA" then match offset=1, length=10
        # This creates "AAAAAAAAAAAAA" (13 A's total)
        input = +""
        input << [0x08].pack("C") # Flag: bit 3 = match
        input << "AAA" # 3 literals
        input << [0x07, 0x01].pack("CC") # Match: offset=1, length=10

        expected = "A" * 13
        result = decompressor.decompress(input, expected.bytesize)
        expect(result).to eq(expected)
      end
    end

    context "error handling" do
      it "handles premature end of input" do
        # Flag says literals but runs out
        input = [0x00, 0x41, 0x42].pack("C*")

        result = decompressor.decompress(input, 10)
        # Should stop gracefully when input ends
        expect(result.bytesize).to be <= 10
        expect(result).to eq("AB") # Got 2 bytes before end
      end

      it "raises error for invalid offset" do
        # Match with offset beyond window (when window is empty)
        input = +""
        input << [0x01].pack("C")           # Flag: bit 0 = match (first token)
        input << [0x03, 0x01].pack("CC")    # Match: offset=1, length=6 (but nothing in window!)

        expect do
          decompressor.decompress(input, 10)
        end.to raise_error(Cabriolet::DecompressionError, /Invalid offset/)
      end
    end

    context "with expected output size" do
      it "stops at expected size" do
        # More compressed data than needed
        input = +""
        input << [0x00].pack("C")
        input << ("A" * 8)   # 8 bytes
        input << [0x00].pack("C")
        input << ("B" * 8)   # 8 more bytes

        result = decompressor.decompress(input, 10)
        expect(result.bytesize).to eq(10)
        expect(result).to eq("#{'A' * 8}BB")
      end

      it "returns what it can if input ends early" do
        input = [0x00, 0x41, 0x42].pack("C*")

        result = decompressor.decompress(input, 10)
        expect(result).to eq("AB")
      end
    end
  end

  describe "#compress" do
    context "with simple data" do
      it "compresses literal bytes" do
        input = "ABCDEFGH"
        compressed = decompressor.compress(input)

        # Should have flag byte + literals
        expect(compressed.bytesize).to be > 0

        # Verify round-trip
        decompressed = decompressor.decompress(compressed, input.bytesize)
        expect(decompressed).to eq(input)
      end

      it "compresses repeating patterns" do
        input = "ABCABCABC"
        compressed = decompressor.compress(input)

        # Should be smaller due to matches
        expect(compressed.bytesize).to be < input.bytesize

        # Verify round-trip
        decompressed = decompressor.decompress(compressed, input.bytesize)
        expect(decompressed).to eq(input)
      end
    end

    context "round-trip testing" do
      it "handles short text" do
        input = "Hello World!"
        compressed = decompressor.compress(input)
        decompressed = decompressor.decompress(compressed, input.bytesize)
        expect(decompressed).to eq(input)
      end

      it "handles longer text with patterns" do
        input = "The quick brown fox jumps over the lazy dog. " * 10
        compressed = decompressor.compress(input)
        decompressed = decompressor.decompress(compressed, input.bytesize)
        expect(decompressed).to eq(input)
      end

      it "handles text with many repetitions" do
        input = "A" * 100
        compressed = decompressor.compress(input)

        # Should compress well
        expect(compressed.bytesize).to be < input.bytesize / 2

        decompressed = decompressor.decompress(compressed, input.bytesize)
        expect(decompressed).to eq(input)
      end

      it "handles binary data" do
        input = (0..255).map(&:chr).join * 2
        compressed = decompressor.compress(input)
        decompressed = decompressor.decompress(compressed, input.bytesize)
        expect(decompressed).to eq(input)
      end

      it "handles empty input" do
        input = ""
        compressed = decompressor.compress(input)
        decompressed = decompressor.decompress(compressed, 0)
        expect(decompressed).to eq(input)
      end
    end
  end
end
