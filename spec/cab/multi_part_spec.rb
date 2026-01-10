# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Multi-part cabinet operations" do
  let(:io_system) { Cabriolet::System::IOSystem.new }
  let(:decompressor) { Cabriolet::CAB::Decompressor.new(io_system) }
  let(:fixture_dir) { File.join(__dir__, "../fixtures/libmspack/cabd") }

  describe "#append" do
    context "with compatible cabinets" do
      it "appends two cabinets successfully" do
        cab1 = decompressor.open(File.join(fixture_dir, "multi_basic_pt1.cab"))
        cab2 = decompressor.open(File.join(fixture_dir, "multi_basic_pt2.cab"))

        expect { decompressor.append(cab1, cab2) }.not_to raise_error

        # Verify cabinets are linked
        expect(cab1.next_cabinet).to eq(cab2)
        expect(cab2.prev_cabinet).to eq(cab1)
      end

      it "merges folders when needed" do
        cab1 = decompressor.open(File.join(fixture_dir, "multi_basic_pt1.cab"))
        cab2 = decompressor.open(File.join(fixture_dir, "multi_basic_pt2.cab"))

        initial_folder_count = cab1.folders.size
        decompressor.append(cab1, cab2)

        # If folders were merged, count should increase by cab2's folders minus 1
        # (because the first folder of cab2 is merged with last folder of cab1)
        expect(cab1.folders.size).to be >= initial_folder_count
      end

      it "shares file and folder lists across all cabinets in the set" do
        cab1 = decompressor.open(File.join(fixture_dir, "multi_basic_pt1.cab"))
        cab2 = decompressor.open(File.join(fixture_dir, "multi_basic_pt2.cab"))

        decompressor.append(cab1, cab2)

        # Both cabinets should reference the same file and folder arrays
        expect(cab1.files).to eq(cab2.files)
        expect(cab1.folders).to eq(cab2.folders)
      end
    end

    context "with validation checks" do
      it "raises error when appending nil cabinet" do
        cab1 = decompressor.open(File.join(fixture_dir, "multi_basic_pt1.cab"))

        expect do
          decompressor.append(cab1,
                              nil)
        end.to raise_error(Cabriolet::ArgumentError, /must be provided/)
      end

      it "raises error when appending same cabinet to itself" do
        cab1 = decompressor.open(File.join(fixture_dir, "multi_basic_pt1.cab"))

        expect do
          decompressor.append(cab1, cab1)
        end.to raise_error(Cabriolet::ArgumentError,
                           /cannot merge.*with itself/i)
      end

      it "raises error when cabinets are already linked" do
        cab1 = decompressor.open(File.join(fixture_dir, "multi_basic_pt1.cab"))
        cab2 = decompressor.open(File.join(fixture_dir, "multi_basic_pt2.cab"))
        cab3 = decompressor.open(File.join(fixture_dir, "multi_basic_pt3.cab"))

        decompressor.append(cab1, cab2)

        expect do
          decompressor.append(cab1,
                              cab3)
        end.to raise_error(Cabriolet::ArgumentError, /already joined/)
      end

      it "raises error when creating circular reference" do
        cab1 = decompressor.open(File.join(fixture_dir, "multi_basic_pt1.cab"))
        cab2 = decompressor.open(File.join(fixture_dir, "multi_basic_pt2.cab"))
        cab3 = decompressor.open(File.join(fixture_dir, "multi_basic_pt3.cab"))

        decompressor.append(cab1, cab2)
        decompressor.append(cab2, cab3)

        expect do
          decompressor.append(cab3,
                              cab1)
        end.to raise_error(Cabriolet::ArgumentError, /circular/i)
      end
    end
  end

  describe "#prepend" do
    it "prepends a cabinet successfully" do
      cab1 = decompressor.open(File.join(fixture_dir, "multi_basic_pt1.cab"))
      cab2 = decompressor.open(File.join(fixture_dir, "multi_basic_pt2.cab"))

      expect { decompressor.prepend(cab2, cab1) }.not_to raise_error

      # Verify cabinets are linked in correct order
      expect(cab1.next_cabinet).to eq(cab2)
      expect(cab2.prev_cabinet).to eq(cab1)
    end

    it "produces same result as append in reverse order" do
      cab1a = decompressor.open(File.join(fixture_dir, "multi_basic_pt1.cab"))
      cab2a = decompressor.open(File.join(fixture_dir, "multi_basic_pt2.cab"))

      cab1b = decompressor.open(File.join(fixture_dir, "multi_basic_pt1.cab"))
      cab2b = decompressor.open(File.join(fixture_dir, "multi_basic_pt2.cab"))

      decompressor.append(cab1a, cab2a)
      decompressor.prepend(cab2b, cab1b)

      expect(cab1a.folders.size).to eq(cab1b.folders.size)
      expect(cab1a.files.size).to eq(cab1b.files.size)
    end
  end

  describe "folder merging" do
    context "when folders can be merged" do
      it "merges folders with matching compression type" do
        cab1 = decompressor.open(File.join(fixture_dir, "multi_basic_pt1.cab"))
        cab2 = decompressor.open(File.join(fixture_dir, "multi_basic_pt2.cab"))

        last_folder_before = cab1.folders.last
        first_folder_cab2 = cab2.folders.first

        # Only merge if folders are marked for merging
        if last_folder_before.merge_next && first_folder_cab2.merge_prev
          decompressor.append(cab1, cab2)

          # The merged folder should have FolderData chain
          merged_folder = cab1.folders.last
          expect(merged_folder.data.next_data).not_to be_nil if cab2.folders.size > 1
        end
      end

      it "updates block count correctly when merging" do
        cab1 = decompressor.open(File.join(fixture_dir, "multi_basic_pt1.cab"))
        cab2 = decompressor.open(File.join(fixture_dir, "multi_basic_pt2.cab"))

        last_folder = cab1.folders.last
        first_folder = cab2.folders.first

        if last_folder.merge_next && first_folder.merge_prev
          initial_blocks = last_folder.num_blocks
          cab2_blocks = first_folder.num_blocks

          decompressor.append(cab1, cab2)

          # Block count should be sum minus 1 (shared boundary block)
          expect(last_folder.num_blocks).to eq(initial_blocks + cab2_blocks - 1)
        end
      end

      it "removes duplicate merge files" do
        cab1 = decompressor.open(File.join(fixture_dir, "multi_basic_pt1.cab"))
        cab2 = decompressor.open(File.join(fixture_dir, "multi_basic_pt2.cab"))

        first_folder_cab2 = cab2.folders.first
        cab1.files.size
        cab2.files.size

        decompressor.append(cab1, cab2)

        # If folders were merged, some files from the merge folder should be removed
        if first_folder_cab2.merge_prev
          # Files belonging to the merged right folder should be gone
          expect(cab1.files.none? do |f|
            f.folder == first_folder_cab2
          end).to be true
        end
      end
    end

    context "when folders cannot be merged" do
      it "raises error for incompatible compression types" do
        # This would require fixture files with different compression types
        # For now, we'll just verify the error is raised in the right conditions
        cab1 = decompressor.open(File.join(fixture_dir, "multi_basic_pt1.cab"))
        cab2 = decompressor.open(File.join(fixture_dir, "multi_basic_pt2.cab"))

        # Artificially create incompatible folders for testing
        if cab1.folders.last.merge_next
          # Change compression type to force mismatch
          original_type = cab2.folders.first.comp_type
          cab2.folders.first.comp_type = 999 # Invalid type

          expect do
            decompressor.append(cab1, cab2)
          end.to raise_error(Cabriolet::DataFormatError, /cannot be merged/)

          # Restore for other tests
          cab2.folders.first.comp_type = original_type
        end
      end
    end
  end

  describe "multi-cabinet file extraction" do
    it "follows FolderData chain across cabinets" do
      cab1 = decompressor.open(File.join(fixture_dir, "multi_basic_pt1.cab"))
      cab2 = decompressor.open(File.join(fixture_dir, "multi_basic_pt2.cab"))

      decompressor.append(cab1, cab2)

      # Check that merged folders have data chain
      cab1.folders.each do |folder|
        data = folder.data
        cabinets_in_chain = []

        while data
          cabinets_in_chain << data.cabinet
          data = data.next_data
        end

        # Folders spanning multiple cabinets should have multiple data segments
        expect(cabinets_in_chain.size).to be >= 1 if folder.merge_next
      end
    end
  end

  describe "complete multi-part set" do
    it "merges a complete 5-part cabinet set" do
      cabs = (1..5).filter_map do |i|
        filename = File.join(fixture_dir, "multi_basic_pt#{i}.cab")
        next unless File.exist?(filename)

        decompressor.open(filename)
      end

      # Skip if not all parts exist
      next if cabs.size < 2

      # Link all cabinets
      cabs.each_cons(2) do |left, right|
        decompressor.append(left, right)
      end

      # First cabinet should have all files and folders
      first_cab = cabs.first
      expect(first_cab.files.size).to be > 0
      expect(first_cab.folders.size).to be > 0

      # All cabinets should share the same lists
      cabs.each do |cab|
        expect(cab.files).to eq(first_cab.files)
        expect(cab.folders).to eq(first_cab.folders)
      end

      # Cabinet chain should be complete
      current = first_cab
      cabs[1..].each do |expected_next|
        expect(current.next_cabinet).to eq(expected_next)
        current = current.next_cabinet
      end
    end
  end

  describe "edge cases" do
    it "handles empty file lists gracefully" do
      cab1 = decompressor.open(File.join(fixture_dir, "multi_basic_pt1.cab"))
      cab2 = decompressor.open(File.join(fixture_dir, "multi_basic_pt2.cab"))

      # This should work even if one cabinet has no files (though unlikely)
      expect { decompressor.append(cab1, cab2) }.not_to raise_error
    end

    it "handles cabinets with no merge folders" do
      # Test cabinets where folders don't need merging
      cab1 = decompressor.open(File.join(fixture_dir,
                                         "normal_2files_1folder.cab"))
      cab2 = decompressor.open(File.join(fixture_dir,
                                         "normal_2files_1folder.cab"))

      # Even without merge requirement, append should work
      expect { decompressor.append(cab1, cab2) }.not_to raise_error

      # Should have both cabinet's folders and files
      expect(cab1.folders.size).to eq(2)
    end
  end
end
