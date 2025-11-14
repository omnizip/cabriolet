# frozen_string_literal: true

module Cabriolet
  # Archive modification functionality (add, update, remove files)
  class Modifier
    def initialize(path)
      @path = path
      @format = FormatDetector.detect(path)
      @modifications = []
      @parser_class = FormatDetector.format_to_parser(@format)

      raise UnsupportedFormatError, "Unknown format: #{path}" unless @format

      unless @parser_class
        raise UnsupportedFormatError,
              "No parser for format: #{@format}"
      end
    end

    # Add a file to the archive
    #
    # @param name [String] File name in archive
    # @param source [String, nil] Source file path (nil for data parameter)
    # @param data [String, nil] File data (if source not provided)
    # @param options [Hash] File metadata options
    # @return [self]
    #
    # @example
    #   modifier = Cabriolet::Modifier.new('archive.cab')
    #   modifier.add_file('new.txt', source: 'path/to/new.txt')
    #   modifier.add_file('data.bin', data: binary_data)
    #   modifier.save
    def add_file(name, source: nil, data: nil, **options)
      if source.nil? && data.nil?
        raise ArgumentError,
              "Must provide either source or data"
      end

      file_data = source ? File.read(source, mode: "rb") : data

      @modifications << {
        action: :add,
        name: name,
        data: file_data,
        options: options,
      }

      self
    end

    # Update an existing file in the archive
    #
    # @param name [String] File name to update
    # @param source [String, nil] Source file path
    # @param data [String, nil] New file data
    # @return [self]
    #
    # @example
    #   modifier.update_file('config.xml', data: new_xml_data)
    def update_file(name, source: nil, data: nil, **options)
      if source.nil? && data.nil?
        raise ArgumentError,
              "Must provide either source or data"
      end

      file_data = source ? File.read(source, mode: "rb") : data

      @modifications << {
        action: :update,
        name: name,
        data: file_data,
        options: options,
      }

      self
    end

    # Remove a file from the archive
    #
    # @param name [String] File name to remove
    # @return [self]
    #
    # @example
    #   modifier.remove_file('old.txt')
    def remove_file(name)
      @modifications << {
        action: :remove,
        name: name,
      }

      self
    end

    # Rename a file in the archive
    #
    # @param old_name [String] Current file name
    # @param new_name [String] New file name
    # @return [self]
    #
    # @example
    #   modifier.rename_file('old_name.txt', 'new_name.txt')
    def rename_file(old_name, new_name)
      @modifications << {
        action: :rename,
        old_name: old_name,
        new_name: new_name,
      }

      self
    end

    # Save modifications to the archive
    #
    # @param output [String, nil] Output path (nil for in-place update)
    # @return [ModificationReport] Report of changes made
    #
    # @example
    #   modifier.save  # Update in-place
    #   modifier.save(output: 'modified.cab')  # Save to new file
    def save(output: nil)
      output ||= @path

      # Parse original archive
      archive = @parser_class.new.parse(@path)

      # Apply modifications
      modified_files = apply_modifications(archive)

      # Rebuild archive
      rebuild_archive(modified_files, output)

      ModificationReport.new(
        success: true,
        original: @path,
        output: output,
        modifications: @modifications.count,
        added: @modifications.count { |m| m[:action] == :add },
        updated: @modifications.count { |m| m[:action] == :update },
        removed: @modifications.count { |m| m[:action] == :remove },
        renamed: @modifications.count { |m| m[:action] == :rename },
      )
    rescue StandardError => e
      ModificationReport.new(
        success: false,
        original: @path,
        output: output,
        error: e.message,
      )
    end

    # Preview modifications without saving
    #
    # @return [Array<Hash>] List of planned modifications
    def preview
      @modifications.map do |mod|
        case mod[:action]
        when :add
          { action: "ADD", file: mod[:name], size: mod[:data].bytesize }
        when :update
          { action: "UPDATE", file: mod[:name], size: mod[:data].bytesize }
        when :remove
          { action: "REMOVE", file: mod[:name] }
        when :rename
          { action: "RENAME", from: mod[:old_name], to: mod[:new_name] }
        end
      end
    end

    private

    def apply_modifications(archive)
      # Start with existing files
      files_map = {}
      archive.files.each do |file|
        files_map[file.name] = file
      end

      # Apply each modification
      @modifications.each do |mod|
        case mod[:action]
        when :add
          files_map[mod[:name]] = create_file_object(mod)
        when :update
          if files_map[mod[:name]]
            files_map[mod[:name]] =
              create_file_object(mod)
          end
        when :remove
          files_map.delete(mod[:name])
        when :rename
          if files_map[mod[:old_name]]
            file = files_map.delete(mod[:old_name])
            files_map[mod[:new_name]] = rename_file_object(file, mod[:new_name])
          end
        end
      end

      files_map.values
    end

    def create_file_object(mod)
      # Create a simple file object with necessary attributes
      FileObject.new(
        name: mod[:name],
        data: mod[:data],
        attributes: mod[:options][:attributes] || 0x20, # Archive attribute
        date: mod[:options][:date],
        time: mod[:options][:time],
      )
    end

    def rename_file_object(file, new_name)
      FileObject.new(
        name: new_name,
        data: file.data,
        attributes: file.respond_to?(:attributes) ? file.attributes : 0x20,
        date: file.respond_to?(:date) ? file.date : nil,
        time: file.respond_to?(:time) ? file.time : nil,
      )
    end

    def rebuild_archive(files, output)
      case @format
      when :cab
        rebuild_cab(files, output)
      else
        raise UnsupportedOperationError,
              "Modification not supported for #{@format}"
      end
    end

    def rebuild_cab(files, output)
      require_relative "cab/compressor"

      compressor = CAB::Compressor.new(
        output: output,
        compression: :mszip,
      )

      files.each do |file|
        compressor.add_file_data(
          file.name,
          file.data,
          attributes: file.attributes,
          date: file.date,
          time: file.time,
        )
      end

      compressor.compress
    end

    # Simple file object for modified files
    class FileObject
      attr_reader :name, :data, :attributes, :date, :time

      def initialize(name:, data:, attributes: nil, date: nil, time: nil)
        @name = name
        @data = data
        @attributes = attributes
        @date = date
        @time = time
      end

      def size
        @data.bytesize
      end
    end
  end

  # Modification report
  class ModificationReport
    attr_reader :success, :original, :output, :modifications, :added, :updated,
                :removed, :renamed, :error

    def initialize(success:, original:, output:, modifications: 0, added: 0, updated: 0, removed: 0, renamed: 0,
                   error: nil)
      @success = success
      @original = original
      @output = output
      @modifications = modifications
      @added = added
      @updated = updated
      @removed = removed
      @renamed = renamed
      @error = error
    end

    def success?
      @success
    end

    def summary
      if success?
        "Modified #{@modifications} items: +#{@added} ~#{@updated} -#{@removed} →#{@renamed}"
      else
        "Modification failed: #{@error}"
      end
    end

    def detailed_report
      report = ["=" * 60]
      report << "Archive Modification Report"
      report << ("=" * 60)
      report << "Original: #{@original}"
      report << "Output:   #{@output}"
      report << "Status:   #{success? ? 'SUCCESS' : 'FAILED'}"
      report << ""

      if success?
        report << "Modifications:"
        report << "  Added:   #{@added}"
        report << "  Updated: #{@updated}"
        report << "  Removed: #{@removed}"
        report << "  Renamed: #{@renamed}"
        report << "  Total:   #{@modifications}"
      else
        report << "Error: #{@error}"
      end

      report << ""
      report << ("=" * 60)
      report.join("\n")
    end
  end
end
