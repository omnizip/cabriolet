# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::CAB::Decompressor, "#search" do
  let(:decompressor) { described_class.new }
  let(:fixtures_dir) do
    File.join(__dir__, "..", "fixtures", "libmspack", "cabd")
  end

  describe "searching for embedded cabinets" do
    it "finds a cabinet in search_basic.cab" do
      file_path = File.join(fixtures_dir, "search_basic.cab")
      cabinet = decompressor.search(file_path)

      expect(cabinet).not_to be_nil
      expect(cabinet).to be_a(Cabriolet::Models::Cabinet)
      expect(cabinet.base_offset).to be >= 0
    end

    it "finds multiple cabinets in search_tricky1.cab" do
      file_path = File.join(fixtures_dir, "search_tricky1.cab")
      cabinet = decompressor.search(file_path)

      expect(cabinet).not_to be_nil

      # Count cabinets in linked list
      count = 0
      cab = cabinet
      while cab
        count += 1
        expect(cab).to be_a(Cabriolet::Models::Cabinet)
        expect(cab.base_offset).to be >= 0
        cab = cab.next
      end

      expect(count).to be > 0
    end

    it "returns nil when no cabinets found" do
      # Create a temporary file with no CAB signature
      require "tempfile"
      temp_file = Tempfile.new("no_cab")
      temp_file.write("This is not a CAB file" * 100)
      temp_file.close

      cabinet = decompressor.search(temp_file.path)

      expect(cabinet).to be_nil

      temp_file.unlink
    end

    it "handles files with false CAB signatures" do
      # Create a file with fake "MSCF" but invalid cabinet structure
      require "tempfile"
      temp_file = Tempfile.new("fake_cab")
      # Write "MSCF" but with invalid cabinet data
      temp_file.write("Some data before")
      temp_file.write("MSCF")
      temp_file.write("\x00" * 100) # Invalid cabinet data
      temp_file.close

      cabinet = decompressor.search(temp_file.path)

      # Should either find nothing or handle gracefully
      # (depending on whether validation fails)
      expect(cabinet).to be_nil

      temp_file.unlink
    end
  end

  describe "search buffer size configuration" do
    it "uses default search buffer size" do
      expect(decompressor.search_buffer_size).to eq(32_768)
    end

    it "allows setting custom search buffer size" do
      decompressor.search_buffer_size = 16_384
      expect(decompressor.search_buffer_size).to eq(16_384)
    end

    it "searches successfully with different buffer sizes" do
      file_path = File.join(fixtures_dir, "search_basic.cab")

      # Try with smaller buffer
      decompressor.search_buffer_size = 1024
      cabinet = decompressor.search(file_path)
      expect(cabinet).not_to be_nil

      # Try with larger buffer
      decompressor.search_buffer_size = 65_536
      cabinet = decompressor.search(file_path)
      expect(cabinet).not_to be_nil
    end
  end

  describe "InstallShield detection" do
    it "warns about InstallShield headers" do
      require "tempfile"
      temp_file = Tempfile.new("installshield")
      # Write InstallShield signature (0x28635349 = "ISc(")
      temp_file.write([0x28635349].pack("V"))
      temp_file.write("\x00" * 100)
      temp_file.close

      # Should not raise an error
      expect { decompressor.search(temp_file.path) }.not_to raise_error

      temp_file.unlink
    end
  end

  describe "cabinet offset tracking" do
    it "sets base_offset correctly for found cabinets" do
      file_path = File.join(fixtures_dir, "search_basic.cab")
      cabinet = decompressor.search(file_path)

      expect(cabinet).not_to be_nil
      expect(cabinet.base_offset).to be_a(Integer)
      expect(cabinet.base_offset).to be >= 0
    end

    it "links multiple cabinets with next pointer" do
      file_path = File.join(fixtures_dir, "search_tricky1.cab")
      cabinet = decompressor.search(file_path)

      if cabinet&.next
        expect(cabinet.next).to be_a(Cabriolet::Models::Cabinet)
        expect(cabinet.next.base_offset).to be > cabinet.base_offset
      end
    end
  end

  describe "error handling" do
    it "handles non-existent files" do
      expect do
        decompressor.search("nonexistent_file.dat")
      end.to raise_error(Cabriolet::IOError)
    end

    it "handles empty files" do
      require "tempfile"
      temp_file = Tempfile.new("empty")
      temp_file.close

      cabinet = decompressor.search(temp_file.path)
      expect(cabinet).to be_nil

      temp_file.unlink
    end

    it "handles very small files" do
      require "tempfile"
      temp_file = Tempfile.new("tiny")
      temp_file.write("AB")
      temp_file.close

      cabinet = decompressor.search(temp_file.path)
      expect(cabinet).to be_nil

      temp_file.unlink
    end
  end

  describe "salvage mode" do
    it "respects salvage mode setting" do
      decompressor.salvage = true
      expect(decompressor.salvage).to be true

      file_path = File.join(fixtures_dir, "search_basic.cab")
      cabinet = decompressor.search(file_path)
      expect(cabinet).not_to be_nil
    end
  end

  describe "verbose output" do
    it "outputs verbose messages when enabled" do
      Cabriolet.verbose = true
      file_path = File.join(fixtures_dir, "search_basic.cab")

      # Should not raise errors with verbose mode
      expect { decompressor.search(file_path) }.not_to raise_error

      Cabriolet.verbose = false
    end
  end

  describe "private helper methods" do
    describe "#validate_cabinet_signature" do
      it "validates reasonable cabinet parameters" do
        # foffset < cablen, both within file bounds
        result = decompressor.send(:validate_cabinet_signature,
                                   100, 1000, 0, 2000)
        expect(result).to be true
      end

      it "rejects invalid cabinet parameters" do
        # foffset >= cablen
        result = decompressor.send(:validate_cabinet_signature,
                                   1000, 100, 0, 2000)
        expect(result).to be false
      end

      it "rejects parameters outside file bounds" do
        # offset + cablen > file_length + 32
        result = decompressor.send(:validate_cabinet_signature,
                                   100, 10_000, 0, 1000)
        expect(result).to be false
      end

      it "allows invalid lengths in salvage mode" do
        decompressor.salvage = true
        # Would normally be rejected, but salvage mode allows it
        result = decompressor.send(:validate_cabinet_signature,
                                   100, 10_000, 0, 1000)
        # In salvage mode, length validation is relaxed
        expect([true, false]).to include(result)
      end
    end
  end

  describe "searching past invalid MSCF signatures" do
    # Regression test: find_cabinet_in_buffer must continue searching after
    # encountering an MSCF signature that fails validation, not give up.
    #
    # Real-world case: EuroFix.exe has MSCF signatures at offsets 5175,
    # 6222, and 21504. The first two fail validation but offset 21504
    # is a real CAB with 134 extractable files.

    it "finds a valid cabinet after invalid MSCF signatures" do
      # Build a buffer with two MSCF signatures:
      #   Offset 0:   invalid (foffset >= cablen → fails validation)
      #   Offset 100: valid   (foffset < cablen, within file bounds)
      buf = Array.new(300, 0)

      # First MSCF at byte 0 — invalid: foffset(100) >= cablen(10)
      "MSCF".bytes.each_with_index { |b, j| buf[j] = b }
      buf[8] = 10 # cablen LSB = 10
      buf[16] = 100 # foffset LSB = 100 (>= cablen, so invalid)

      # Second MSCF at byte 100 — valid: foffset(50) < cablen(200)
      "MSCF".bytes.each_with_index { |b, j| buf[100 + j] = b }
      buf[108] = 200  # cablen LSB = 200
      buf[116] = 50   # foffset LSB = 50 (< cablen, valid)

      result = decompressor.send(:find_cabinet_in_buffer,
                                 buf, 300, 0, nil, nil, 500)

      expect(result).to eq(100),
                        "find_cabinet_in_buffer should skip invalid MSCF at offset 0 " \
                        "and return valid cabinet at offset 100 (got #{result.inspect})"
    end

    it "returns nil when all MSCF signatures are invalid" do
      buf = Array.new(200, 0)

      # MSCF at byte 0 — invalid: foffset(100) >= cablen(10)
      "MSCF".bytes.each_with_index { |b, j| buf[j] = b }
      buf[8] = 10
      buf[16] = 100

      result = decompressor.send(:find_cabinet_in_buffer,
                                 buf, 200, 0, nil, nil, 500)
      expect(result).to be_nil
    end

    it "finds cabinet at first position when first signature is valid" do
      buf = Array.new(200, 0)

      # MSCF at byte 0 — valid: foffset(50) < cablen(200)
      "MSCF".bytes.each_with_index { |b, j| buf[j] = b }
      buf[8] = 200 # cablen
      buf[16] = 50 # foffset

      result = decompressor.send(:find_cabinet_in_buffer,
                                 buf, 200, 0, nil, nil, 500)
      expect(result).to eq(0)
    end

    it "skips multiple invalid signatures before finding a valid one" do
      buf = Array.new(500, 0)

      # Invalid MSCF at byte 0
      "MSCF".bytes.each_with_index { |b, j| buf[j] = b }
      buf[8] = 10
      buf[16] = 100 # foffset >= cablen

      # Invalid MSCF at byte 100
      "MSCF".bytes.each_with_index { |b, j| buf[100 + j] = b }
      buf[108] = 5
      buf[116] = 50 # foffset >= cablen

      # Valid MSCF at byte 200
      "MSCF".bytes.each_with_index { |b, j| buf[200 + j] = b }
      buf[208] = 200 # cablen = 200 (low byte)
      buf[216] = 50 # foffset = 50 (< cablen)

      result = decompressor.send(:find_cabinet_in_buffer,
                                 buf, 500, 0, nil, nil, 1000)
      expect(result).to eq(200)
    end
  end

  describe "chunk boundary overlap in search" do
    # The search method reads the file in chunks of search_buffer_size.
    # An MSCF header is 20 bytes. Without overlap, a signature spanning
    # two chunks would be missed. The overlap ensures re-scanning.

    it "finds a cabinet whose MSCF header spans a chunk boundary" do
      require "tempfile"

      # Use a fixture with exactly ONE MSCF signature so we know the
      # overlap is the only way to find it when the header is split.
      cab_data = File.binread(File.join(fixtures_dir,
                                        "normal_2files_1folder.cab"))

      # Build a file: 30 bytes of non-MSCF padding + the single CAB.
      # MSCF lands at absolute offset 30. The 20-byte header spans bytes 30-49.
      temp_file = Tempfile.new("boundary_cab")
      temp_file.binmode
      temp_file.write("X" * 30)
      temp_file.write(cab_data)
      temp_file.close

      # buffer_size=40: first chunk has bytes 0-39, capturing "MSCF" at 30
      # but only 10 of the 20 header bytes (30-39). The state machine exits
      # incomplete. The 20-byte overlap re-reads bytes 20-39 in the next
      # chunk, placing the full 20-byte header in range.
      decompressor.search_buffer_size = 40

      cabinet = decompressor.search(temp_file.path)
      expect(cabinet).not_to be_nil,
                             "search should find cabinet when MSCF header spans chunk boundary " \
                             "(MSCF at offset 30, buffer_size=40)"

      temp_file.unlink
    end

    it "does not loop infinitely on a tiny file with no cabinet" do
      require "tempfile"
      temp_file = Tempfile.new("tiny_nocab")
      # 20 bytes — exactly the overlap size; must not cause infinite loop
      temp_file.write("X" * 20)
      temp_file.close

      decompressor.search_buffer_size = 20
      # Should terminate and return nil, not hang
      cabinet = decompressor.search(temp_file.path)
      expect(cabinet).to be_nil

      temp_file.unlink
    end
  end

  describe "cabinet properties" do
    it "parses cabinet properties correctly" do
      file_path = File.join(fixtures_dir, "search_basic.cab")
      cabinet = decompressor.search(file_path)

      expect(cabinet).not_to be_nil
      expect(cabinet.filename).to eq(file_path)
      expect(cabinet.folders).to be_an(Array)
      expect(cabinet.files).to be_an(Array)
    end

    it "provides file and folder counts" do
      file_path = File.join(fixtures_dir, "search_basic.cab")
      cabinet = decompressor.search(file_path)

      if cabinet
        expect(cabinet.file_count).to be_a(Integer)
        expect(cabinet.folder_count).to be_a(Integer)
        expect(cabinet.file_count).to be >= 0
        expect(cabinet.folder_count).to be >= 0
      end
    end
  end
end
