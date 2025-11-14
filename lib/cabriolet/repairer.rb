# frozen_string_literal: true

module Cabriolet
  # Archive repair and recovery functionality
  class Repairer
    def initialize(path, **options)
      @path = path
      @options = options
      @format = FormatDetector.detect(path)
      @recovery_stats = { recovered: 0, failed: 0, partial: 0 }
    end

    # Attempt to repair the archive
    #
    # @param output [String] Output path for repaired archive
    # @param options [Hash] Repair options
    # @option options [Boolean] :salvage_mode (true) Enable salvage mode
    # @option options [Boolean] :skip_corrupted (true) Skip corrupted files
    # @option options [Boolean] :rebuild_index (true) Rebuild file index
    # @return [RepairReport] Repair report
    #
    # @example
    #   repairer = Cabriolet::Repairer.new('corrupted.cab')
    #   report = repairer.repair(output: 'repaired.cab')
    def repair(output:, **options)
      salvage_mode = options.fetch(:salvage_mode, true)
      skip_corrupted = options.fetch(:skip_corrupted, true)
      rebuild_index = options.fetch(:rebuild_index, true)

      begin
        # Parse with salvage mode enabled
        parser_class = FormatDetector.format_to_parser(@format)
        unless parser_class
          raise UnsupportedFormatError,
                "No parser for format: #{@format}"
        end

        archive = parser_class.new(
          salvage_mode: salvage_mode,
          skip_checksum: true,
          continue_on_error: true,
        ).parse(@path)

        # Extract recoverable files
        recovered_files = extract_recoverable_files(archive, skip_corrupted)

        # Rebuild archive
        rebuild_archive(recovered_files, output) if rebuild_index

        RepairReport.new(
          success: true,
          original_file: @path,
          repaired_file: output,
          stats: @recovery_stats,
          recovered_files: recovered_files.map(&:name),
        )
      rescue StandardError => e
        RepairReport.new(
          success: false,
          original_file: @path,
          repaired_file: output,
          stats: @recovery_stats,
          error: e.message,
        )
      end
    end

    # Salvage files from corrupted archive
    #
    # @param output_dir [String] Directory to save recovered files
    # @return [SalvageReport] Salvage report with statistics
    #
    # @example
    #   repairer = Cabriolet::Repairer.new('corrupted.cab')
    #   report = repairer.salvage(output_dir: 'recovered/')
    def salvage(output_dir:)
      FileUtils.mkdir_p(output_dir)

      parser_class = FormatDetector.format_to_parser(@format)
      archive = parser_class.new(
        salvage_mode: true,
        skip_checksum: true,
        continue_on_error: true,
      ).parse(@path)

      salvaged_files = []

      archive.files.each do |file|
        data = file.data
        output_path = File.join(output_dir, sanitize_filename(file.name))
        FileUtils.mkdir_p(File.dirname(output_path))
        File.write(output_path, data, mode: "wb")

        @recovery_stats[:recovered] += 1
        salvaged_files << file.name
      rescue StandardError => e
        @recovery_stats[:failed] += 1
        warn "Could not salvage #{file.name}: #{e.message}"
      end

      SalvageReport.new(
        output_dir: output_dir,
        stats: @recovery_stats,
        salvaged_files: salvaged_files,
      )
    end

    private

    def extract_recoverable_files(archive, skip_corrupted)
      recovered = []

      archive.files.each do |file|
        # Try to decompress file data
        data = file.data

        # Verify data integrity if possible
        if file.respond_to?(:size) && data.bytesize == file.size
          recovered << RecoveredFile.new(file, data, :complete)
          @recovery_stats[:recovered] += 1
        elsif skip_corrupted
          @recovery_stats[:failed] += 1
        else
          recovered << RecoveredFile.new(file, data, :partial)
          @recovery_stats[:partial] += 1
        end
      rescue StandardError => e
        @recovery_stats[:failed] += 1
        warn "Failed to recover #{file.name}: #{e.message}" unless skip_corrupted
      end

      recovered
    end

    def rebuild_archive(files, output_path)
      # Rebuild based on format
      case @format
      when :cab
        rebuild_cab(files, output_path)
      else
        # For other formats, just extract the files
        # Full rebuild may not be supported
        raise UnsupportedOperationError, "Rebuild not supported for #{@format}"
      end
    end

    def rebuild_cab(files, output_path)
      require_relative "cab/compressor"

      compressor = CAB::Compressor.new(
        output: output_path,
        compression: :mszip, # Use safe compression
      )

      files.each do |recovered_file|
        compressor.add_file_data(
          recovered_file.name,
          recovered_file.data,
          attributes: recovered_file.attributes,
          date: recovered_file.date,
          time: recovered_file.time,
        )
      end

      compressor.compress
    end

    def sanitize_filename(filename)
      # Remove path traversal attempts and dangerous characters
      filename.gsub("\\", "/").gsub("..", "_").gsub(%r{^/}, "")
    end

    # Recovered file wrapper
    class RecoveredFile
      attr_reader :name, :data, :status, :attributes, :date, :time

      def initialize(original_file, data, status)
        @name = original_file.name
        @data = data
        @status = status # :complete or :partial
        @attributes = original_file.attributes if original_file.respond_to?(:attributes)
        @date = original_file.date if original_file.respond_to?(:date)
        @time = original_file.time if original_file.respond_to?(:time)
      end

      def complete?
        @status == :complete
      end

      def partial?
        @status == :partial
      end
    end
  end

  # Repair report
  class RepairReport
    attr_reader :success, :original_file, :repaired_file, :stats,
                :recovered_files, :error

    def initialize(success:, original_file:, repaired_file:, stats:,
recovered_files: [], error: nil)
      @success = success
      @original_file = original_file
      @repaired_file = repaired_file
      @stats = stats
      @recovered_files = recovered_files
      @error = error
    end

    def success?
      @success
    end

    def summary
      if success?
        "Repair successful: #{@stats[:recovered]} files recovered, #{@stats[:failed]} failed"
      else
        "Repair failed: #{@error}"
      end
    end

    def detailed_report
      report = ["=" * 60]
      report << "Archive Repair Report"
      report << ("=" * 60)
      report << "Original: #{@original_file}"
      report << "Repaired: #{@repaired_file}"
      report << "Status: #{success? ? 'SUCCESS' : 'FAILED'}"
      report << ""
      report << "Statistics:"
      report << "  Recovered: #{@stats[:recovered]}"
      report << "  Partial:   #{@stats[:partial]}"
      report << "  Failed:    #{@stats[:failed]}"
      report << ""

      if @error
        report << "Error: #{@error}"
        report << ""
      end

      if @recovered_files.any?
        report << "Recovered Files:"
        @recovered_files.each { |f| report << "  - #{f}" }
        report << ""
      end

      report << ("=" * 60)
      report.join("\n")
    end
  end

  # Salvage report
  class SalvageReport
    attr_reader :output_dir, :stats, :salvaged_files

    def initialize(output_dir:, stats:, salvaged_files:)
      @output_dir = output_dir
      @stats = stats
      @salvaged_files = salvaged_files
    end

    def summary
      "Salvaged #{@stats[:recovered]} files to #{@output_dir}, #{@stats[:failed]} failed"
    end

    def detailed_report
      report = ["=" * 60]
      report << "Salvage Operation Report"
      report << ("=" * 60)
      report << "Output Directory: #{@output_dir}"
      report << ""
      report << "Statistics:"
      report << "  Salvaged: #{@stats[:recovered]}"
      report << "  Failed:   #{@stats[:failed]}"
      report << ""

      if @salvaged_files.any?
        report << "Salvaged Files:"
        @salvaged_files.each { |f| report << "  - #{f}" }
        report << ""
      end

      report << ("=" * 60)
      report.join("\n")
    end
  end
end
