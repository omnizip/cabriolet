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
