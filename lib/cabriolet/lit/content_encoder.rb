# frozen_string_literal: true

module Cabriolet
  module LIT
    # Encodes LIT content data (NameList, manifest)
    class ContentEncoder
      # Build NameList data from sections
      #
      # @param sections [Array<Hash>] Sections array
      # @return [String] Binary NameList data
      def self.build_namelist_data(sections)
        data = +""
        data += [0].pack("v") # Initial field

        # Write number of sections
        data += [sections.size].pack("v")

        # Write each section name
        null_terminator = [0].pack("v")
        sections.each do |section|
          name = section[:name]
          # Convert to UTF-16LE
          name_utf16 = name.encode("UTF-16LE").force_encoding("ASCII-8BIT")
          name_length = name_utf16.bytesize / 2

          data += [name_length].pack("v")
          data += name_utf16
          data += null_terminator
        end

        data
      end

      # Build manifest data from manifest structure
      #
      # @param manifest [Hash] Manifest structure with mappings
      # @return [String] Binary manifest data
      def self.build_manifest_data(manifest)
        data = +""

        # For simplicity: single directory entry
        data += [0].pack("C") # Empty directory name = end of directories

        # Write 4 groups
        terminator = [0].pack("C")
        4.times do |group|
          # Get mappings for this group
          group_mappings = manifest[:mappings].select { |m| m[:group] == group }

          data += [group_mappings.size].pack("V")

          group_mappings.each do |mapping|
            data += [mapping[:offset]].pack("V")

            # Internal name
            data += [mapping[:internal_name].bytesize].pack("C")
            data += mapping[:internal_name]

            # Original name
            data += [mapping[:original_name].bytesize].pack("C")
            data += mapping[:original_name]

            # Content type
            data += [mapping[:content_type].bytesize].pack("C")
            data += mapping[:content_type]

            # Terminator
            data += terminator
          end
        end

        data
      end
    end
  end
end
