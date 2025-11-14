# frozen_string_literal: true

module Cabriolet
  # Archive validation and integrity checking
  class Validator
    # Validation levels
    LEVEL_QUICK = :quick        # Basic structure validation
    LEVEL_STANDARD = :standard  # Standard validation with checksums
    LEVEL_THOROUGH = :thorough  # Full decompression validation

    def initialize(path, level: LEVEL_STANDARD)
      @path = path
      @level = level
      @errors = []
      @warnings = []
      @format = nil
    end

    # Validate the archive
    #
    # @return [ValidationReport] Validation report object
    #
    # @example
    #   validator = Cabriolet::Validator.new('archive.cab')
    #   report = validator.validate
    #   puts "Valid: #{report.valid?}"
    #   puts "Errors: #{report.errors}"
    def validate
      detect_format

      case @level
      when LEVEL_QUICK
        validate_quick
      when LEVEL_STANDARD
        validate_standard
      when LEVEL_THOROUGH
        validate_thorough
      end

      ValidationReport.new(
        valid: @errors.empty?,
        format: @format,
        level: @level,
        errors: @errors,
        warnings: @warnings,
        path: @path,
      )
    end

    private

    def detect_format
      @format = FormatDetector.detect(@path)

      unless @format
        @errors << "Unable to detect archive format"
        return
      end

      @warnings << "Format detected as: #{@format}"
    end

    def validate_quick
      return unless @format

      # Basic file checks
      validate_file_exists
      validate_file_readable
      validate_magic_bytes
    end

    def validate_standard
      validate_quick
      return unless @errors.empty?

      # Structure validation
      validate_structure
      validate_checksums if should_validate_checksums?
    end

    def validate_thorough
      validate_standard
      return unless @errors.empty?

      # Full decompression test
      validate_decompression
      validate_file_integrity
    end

    def validate_file_exists
      return if File.exist?(@path)

      @errors << "File does not exist: #{@path}"
    end

    def validate_file_readable
      return if File.readable?(@path)

      @errors << "File is not readable: #{@path}"
    end

    def validate_magic_bytes
      File.open(@path, "rb") do |f|
        magic = f.read(4)

        expected = expected_magic_bytes(@format)
        @errors << "Invalid magic bytes for #{@format} format" unless expected.any? do |m|
          magic.start_with?(m)
        end
      end
    rescue StandardError => e
      @errors << "Error reading magic bytes: #{e.message}"
    end

    def validate_structure
      parser_class = FormatDetector.format_to_parser(@format)
      unless parser_class
        @errors << "No parser available for format: #{@format}"
        return
      end

      archive = parser_class.new.parse(@path)

      # Format-specific structure validation
      case @format
      when :cab
        validate_cab_structure(archive)
      when :chm
        validate_chm_structure(archive)
      end
    rescue StandardError => e
      @errors << "Structure validation failed: #{e.message}"
    end

    def validate_cab_structure(cabinet)
      # Validate CAB header
      unless cabinet.respond_to?(:header)
        @errors << "Missing CAB header"
        return
      end

      header = cabinet.header

      # Check version
      unless header.version_major == 1 && header.version_minor >= 1
        @warnings << "Unusual CAB version: #{header.version_major}.#{header.version_minor}"
      end

      # Check folder count
      @errors << "CAB has no folders" if cabinet.folders.empty?

      # Check file count
      @warnings << "CAB has no files" if cabinet.files.empty?

      # Validate folder indices
      cabinet.files.each do |file|
        @errors << "File #{file.name} references invalid folder index" if file.folder_index >= cabinet.folders.count
      end
    end

    def validate_chm_structure(chm)
      return unless chm.files.empty?

      @warnings << "CHM has no files"
    end

    def validate_checksums
      case @format
      when :cab
        validate_cab_checksums
      end
    rescue StandardError => e
      @errors << "Checksum validation failed: #{e.message}"
    end

    def validate_cab_checksums
      parser = Cabriolet::CAB::Parser.new(skip_checksum: false)
      begin
        parser.parse(@path)
        @warnings << "All checksums valid"
      rescue Cabriolet::ChecksumError => e
        @errors << "Checksum error: #{e.message}"
      end
    end

    def validate_decompression
      parser_class = FormatDetector.format_to_parser(@format)
      archive = parser_class.new.parse(@path)

      file_count = 0
      failed_count = 0

      archive.files.each do |file|
        file_count += 1
        begin
          data = file.data
          if data.nil? || (file.respond_to?(:size) && data.bytesize != file.size)
            @warnings << "File size mismatch: #{file.name}"
          end
        rescue StandardError => e
          failed_count += 1
          @errors << "Failed to decompress #{file.name}: #{e.message}"
        end
      end

      if failed_count.zero?
        @warnings << "All #{file_count} files decompressed successfully"
      else
        @errors << "#{failed_count} out of #{file_count} files failed to decompress"
      end
    end

    def validate_file_integrity
      # Additional integrity checks could be added here
      # For example: path traversal detection, suspicious file names, etc.

      parser_class = FormatDetector.format_to_parser(@format)
      archive = parser_class.new.parse(@path)

      archive.files.each do |file|
        # Check for path traversal attempts
        @warnings << "Suspicious path detected: #{file.name}" if file.name.include?("..") || file.name.start_with?("/")

        # Check for extremely long file names
        @warnings << "Unusually long filename: #{file.name[0..50]}..." if file.name.length > 255
      end
    end

    def should_validate_checksums?
      @format == :cab # Only CAB format has checksums
    end

    def expected_magic_bytes(format)
      case format
      when :cab
        ["MSCF"]
      when :chm
        ["ITSF"]
      when :hlp
        ["\x3F\x5F", "\x4C\x4E"]
      when :kwaj
        ["KWAJ"]
      when :szdd
        ["SZDD", "\x88\xF0\x27\x00"]
      when :lit
        ["ITOLITLS"]
      else
        []
      end
    end
  end

  # Validation report object
  class ValidationReport
    attr_reader :valid, :format, :level, :errors, :warnings, :path

    def initialize(valid:, format:, level:, errors:, warnings:, path:)
      @valid = valid
      @format = format
      @level = level
      @errors = errors
      @warnings = warnings
      @path = path
    end

    def valid?
      @valid
    end

    def has_errors?
      !@errors.empty?
    end

    def has_warnings?
      !@warnings.empty?
    end

    def summary
      status = valid? ? "VALID" : "INVALID"
      "#{status} - #{@format} archive (#{@level} validation)\n" \
        "Errors: #{@errors.count}, Warnings: #{@warnings.count}"
    end

    def detailed_report
      report = ["=" * 60]
      report << "Validation Report"
      report << ("=" * 60)
      report << "File: #{@path}"
      report << "Format: #{@format}"
      report << "Level: #{@level}"
      report << "Status: #{valid? ? 'VALID' : 'INVALID'}"
      report << ""

      if has_errors?
        report << "ERRORS:"
        @errors.each_with_index do |error, i|
          report << "  #{i + 1}. #{error}"
        end
        report << ""
      end

      if has_warnings?
        report << "WARNINGS:"
        @warnings.each_with_index do |warning, i|
          report << "  #{i + 1}. #{warning}"
        end
        report << ""
      end

      report << ("=" * 60)
      report.join("\n")
    end

    def to_h
      {
        valid: @valid,
        format: @format,
        level: @level,
        path: @path,
        error_count: @errors.count,
        warning_count: @warnings.count,
        errors: @errors,
        warnings: @warnings,
      }
    end

    def to_json(*args)
      require "json"
      to_h.to_json(*args)
    end
  end
end
