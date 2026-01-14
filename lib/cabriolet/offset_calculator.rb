# frozen_string_literal: true

module Cabriolet
  # Abstract base class for offset calculators
  #
  # Single responsibility: Calculate file positions within archive.
  # Strategy pattern: Different formats implement different calculation strategies.
  #
  # Subclasses must implement:
  # - calculate(structure) - Returns hash of offsets
  #
  # @example Creating a calculator
  #   class MyFormatCalculator < OffsetCalculator
  #     def calculate(structure)
  #       { header: 0, data: 100 }
  #     end
  #   end
  class OffsetCalculator
    # Calculate all offsets in archive structure
    #
    # @param structure [Hash] Archive structure with files, folders, etc.
    # @return [Hash] Offset information
    # @raise [NotImplementedError] if not implemented by subclass
    def calculate(structure)
      raise NotImplementedError,
            "#{self.class.name} must implement calculate(structure)"
    end

    protected

    # Helper: Calculate cumulative offsets for items
    #
    # @param items [Array] Items to calculate offsets for
    # @param initial_offset [Integer] Starting offset
    # @yield [item] Block that returns size for each item
    # @return [Array<Hash>] Items with their offsets
    def cumulative_offsets(items, initial_offset = 0)
      offset = initial_offset
      items.map do |item|
        current_offset = offset
        item_size = yield(item)
        offset += item_size
        { item: item, offset: current_offset, size: item_size }
      end
    end
  end

  # CAB-specific offset calculator
  #
  # Calculates offsets for CFHEADER, CFFOLDER entries, CFFILE entries,
  # and CFDATA blocks in Microsoft Cabinet files.
  class CABOffsetCalculator < OffsetCalculator
    # Calculate CAB file offsets
    #
    # @param structure [Hash] Must contain :folders and :files
    # @return [Hash] Offset information
    def calculate(structure)
      offset = Constants::CFHEADER_SIZE

      # Folders section
      folders_offset = offset
      offset += Constants::CFFOLDER_SIZE * structure[:folders].size

      # Files section
      files_offset = offset
      structure[:files].each do |file_info|
        offset += Constants::CFFILE_SIZE
        offset += file_info[:name].bytesize + 1 # null-terminated
      end

      # Data blocks section
      data_offset = offset

      {
        folders: folders_offset,
        files: files_offset,
        data: data_offset,
      }
    end
  end
end
