# frozen_string_literal: true

require_relative "../../binary/hlp_structures"
require "stringio"

module Cabriolet
  module HLP
    module WinHelp
      # B+ tree builder for WinHelp 4.x directory format
      #
      # Builds B+ tree directory structure for WinHelp 4.x files.
      # The directory maps filenames to file offsets using a B+ tree
      # with fixed-size pages.
      class BTreeBuilder
        # Default page size for WinHelp 4.x directory (1KB for catalog/directory)
        DEFAULT_PAGE_SIZE = 0x0400 # 1KB

        # Page types
        PAGE_TYPE_LEAF = 0
        PAGE_TYPE_INDEX = 1

        # B+ tree magic number
        BTREE_MAGIC = 0x293B

        # Flags for B+ tree header
        # Bit 0x0002 is always 1
        # Bit 0x0400 is 1 for catalog/directory
        FLAGS_MAGIC_BIT = 0x0002
        FLAGS_CATALOG_BIT = 0x0400

        attr_reader :page_size, :structure

        # Initialize B+ tree builder
        #
        # @param page_size [Integer] Page size in bytes (default: 1KB)
        # @param structure [String] Structure string describing data format
        def initialize(page_size: DEFAULT_PAGE_SIZE, structure: "FFz")
          @page_size = page_size
          @structure = structure
          @entries = []
        end

        # Add a file entry to the B+ tree
        #
        # @param filename [String] Internal filename (e.g., "|SYSTEM")
        # @param offset [Integer] File offset in help file
        # @param size [Integer] File size in bytes
        def add_entry(filename, offset, size)
          @entries << { filename: filename, offset: offset, size: size }
        end

        # Build B+ tree structure
        #
        # @return [Hash] Hash containing :header, :pages
        def build
          return build_empty if @entries.empty?

          # Sort entries by filename
          sorted_entries = @entries.sort_by { |e| e[:filename] }

          # Build leaf pages
          leaf_pages = build_leaf_pages(sorted_entries)

          # Build index pages if needed
          if leaf_pages.size > 1
            index_pages = build_index_pages(leaf_pages)
            root_page = index_pages.first[:page_num]
            n_levels = 2
          else
            index_pages = []
            root_page = leaf_pages.first[:page_num]
            n_levels = 1
          end

          # Build B+ tree header
          header = build_header(
            total_pages: leaf_pages.size + index_pages.size,
            root_page: root_page,
            n_levels: n_levels,
            total_entries: @entries.size,
          )

          # Combine all pages
          all_pages = index_pages + leaf_pages

          { header: header, pages: all_pages }
        end

        private

        # Build empty B+ tree (single empty leaf page)
        #
        # @return [Hash] Hash containing :header, :pages
        def build_empty
          # Create empty leaf page
          leaf_page = {
            page_num: 0,
            data: build_empty_leaf_page,
          }

          header = build_header(
            total_pages: 1,
            root_page: 0,
            n_levels: 1,
            total_entries: 0,
          )

          { header: header, pages: [leaf_page] }
        end

        # Build B+ tree header
        #
        # @param total_pages [Integer] Total number of pages
        # @param root_page [Integer] Root page number
        # @param n_levels [Integer] Number of levels in tree
        # @param total_entries [Integer] Total number of entries
        # @return [Binary::HLPStructures::WinHelpBTreeHeader] B+ tree header
        def build_header(total_pages:, root_page:, n_levels:, total_entries:)
          Binary::HLPStructures::WinHelpBTreeHeader.new(
            magic: BTREE_MAGIC,
            flags: FLAGS_MAGIC_BIT | FLAGS_CATALOG_BIT,
            page_size: @page_size,
            structure: @structure.ljust(16, "\x00"),
            must_be_zero: 0,
            page_splits: 0,
            root_page: root_page,
            must_be_neg_one: 0xFFFF,
            total_pages: total_pages,
            n_levels: n_levels,
            total_btree_entries: total_entries,
          )
        end

        # Build leaf pages from entries
        #
        # @param entries [Array<Hash>] Sorted file entries
        # @return [Array<Hash>] Array of page hashes with :page_num and :data
        def build_leaf_pages(entries)
          pages = []
          current_page_data = StringIO.new
          page_num = 0

          entries.each do |entry|
            # Check if this entry fits in current page
            entry_size = entry[:filename].bytesize + 1 + 4 # filename + null + offset
            header_size = 8 # leaf node header

            # Check if we need a new page
            if (current_page_data.size + entry_size + header_size) > @page_size
              # Finish current page and start new one
              pages << finish_leaf_page(current_page_data, page_num,
                                        pages.empty?)
              page_num += 1
              current_page_data = StringIO.new
            end

            # Write entry to current page
            current_page_data.write(entry[:filename])
            current_page_data.write("\x00") # null terminator
            current_page_data.write([entry[:offset]].pack("V")) # 4-byte offset
          end

          # Finish last page
          if current_page_data.size.positive?
            pages << finish_leaf_page(current_page_data, page_num, pages.empty?)
          end

          pages
        end

        # Finish a leaf page by adding header
        #
        # @param page_data [StringIO] Page data without header
        # @param page_num [Integer] Page number
        # @param is_first [Boolean] Whether this is the first page
        # @return [Hash] Page hash with :page_num and :data
        def finish_leaf_page(page_data, page_num, is_first)
          data = page_data.string
          n_entries = count_entries(data)

          # Build leaf node header
          # - 2 bytes: unused (we use 0)
          # - 2 bytes: nEntries
          # - 2 bytes: PreviousPage (0xFFFF for first)
          # - 2 bytes: NextPage (0xFFFF for last, to be determined)
          header = [
            0, # unused
            n_entries,
            is_first ? 0xFFFF : page_num - 1, # previous page
            0xFFFF, # next page (will update if more pages added)
          ].pack("vvvv")

          { page_num: page_num, data: header + data }
        end

        # Build empty leaf page
        #
        # @return [String] Empty leaf page data
        def build_empty_leaf_page
          # Empty leaf has header with nEntries = 0
          [
            0, # unused
            0, # nEntries = 0
            0xFFFF, # previous page
            0xFFFF, # next page
          ].pack("vvvv")
        end

        # Build index pages from leaf pages
        #
        # @param leaf_pages [Array<Hash>] Leaf page hashes
        # @return [Array<Hash>] Array of index page hashes
        def build_index_pages(leaf_pages)
          # For simplicity, create single index page pointing to all leaf pages
          # In a real implementation, this would recursively build index pages
          index_data = StringIO.new

          leaf_pages.each do |page|
            # For index pages, entries are: (filename, page_number)
            # We use the first filename from each leaf page as key
            first_filename = extract_first_filename(page[:data])
            index_data.write(first_filename)
            index_data.write("\x00") # null terminator
            index_data.write([page[:page_num]].pack("v")) # 2-byte page number
          end

          data = index_data.string
          n_entries = leaf_pages.size

          # Build index node header
          # - 2 bytes: unused (we use 0)
          # - 2 bytes: nEntries
          # - 2 bytes: PreviousPage (0xFFFF - no previous)
          header = [
            0, # unused
            n_entries,
            0xFFFF, # previous page (none for root)
          ].pack("vvv")

          [{
            page_num: leaf_pages.size, # Index pages come after leaf pages
            data: header + data,
          }]
        end

        # Extract first filename from page data
        #
        # @param page_data [String] Page data with header
        # @return [String] First filename in page
        def extract_first_filename(page_data)
          # Skip 8-byte header
          data_start = 8
          data = page_data[data_start..]

          # Filename is null-terminated
          null_pos = data.index("\x00")
          return "" if null_pos.nil?

          data[0...null_pos]
        end

        # Count entries in page data
        #
        # @param data [String] Page data without header
        # @return [Integer] Number of entries
        def count_entries(data)
          count = 0
          pos = 0

          while pos < data.bytesize
            # Find null terminator
            null_pos = data.index("\x00", pos)
            break if null_pos.nil?

            # Skip filename
            pos = null_pos + 1

            # Skip 4-byte offset
            pos += 4

            count += 1
          end

          count
        end
      end
    end
  end
end
