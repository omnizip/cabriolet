# frozen_string_literal: true

require "fileutils"

module Cabriolet
  module Commands
    # Abstract base class for format-specific command handlers
    #
    # This class defines the interface that all format command handlers must implement.
    # Each format (CAB, CHM, SZDD, KWAJ, HLP, LIT, OAB) should have its own
    # CommandHandler subclass that inherits from this base class.
    #
    # The base class provides common functionality and enforces a consistent
    # interface across all format handlers, following the Template Method pattern.
    #
    # @example Creating a format handler
    #   module Cabriolet
    #     module CAB
    #       class CommandHandler < CLI::BaseCommandHandler
    #         def list(file, options = {})
    #           # Implementation for listing CAB files
    #         end
    #       end
    #     end
    #   end
    #
    class BaseCommandHandler
      # Initialize the command handler
      #
      # @param verbose [Boolean] Enable verbose output
      def initialize(verbose: false)
        @verbose = verbose
      end

      # List archive contents
      #
      # @param file [String] Path to the archive file
      # @param options [Hash] Additional options
      # @raise [NotImplementedError] Subclass must implement
      def list(file, options = {})
        raise NotImplementedError,
              "#{self.class} must implement #list"
      end

      # Extract files from archive
      #
      # @param file [String] Path to the archive file
      # @param output_dir [String] Output directory path
      # @param options [Hash] Additional options
      # @raise [NotImplementedError] Subclass must implement
      def extract(file, output_dir, options = {})
        raise NotImplementedError,
              "#{self.class} must implement #extract"
      end

      # Create a new archive
      #
      # @param output [String] Output file path
      # @param files [Array<String>] List of input files
      # @param options [Hash] Additional options
      # @raise [NotImplementedError] Subclass must implement
      def create(output, files, options = {})
        raise NotImplementedError,
              "#{self.class} must implement #create"
      end

      # Display archive information
      #
      # @param file [String] Path to the archive file
      # @param options [Hash] Additional options
      # @raise [NotImplementedError] Subclass must implement
      def info(file, options = {})
        raise NotImplementedError,
              "#{self.class} must implement #info"
      end

      # Test archive integrity
      #
      # @param file [String] Path to the archive file
      # @param options [Hash] Additional options
      # @raise [NotImplementedError] Subclass must implement
      def test(file, options = {})
        raise NotImplementedError,
              "#{self.class} must implement #test"
      end

      protected

      # Check if verbose output is enabled
      #
      # @return [Boolean] true if verbose mode is active
      def verbose?
        @verbose
      end

      # Detect format from file using FormatDetector
      #
      # This is a convenience method for handlers that need to perform
      # format detection within their operations.
      #
      # @param file [String] Path to the file
      # @return [Symbol, nil] Detected format symbol
      def detect_format(file)
        FormatDetector.detect(file)
      end

      # Validate that a file exists
      #
      # @param file [String] Path to the file
      # @raise [ArgumentError] if file doesn't exist
      def validate_file_exists(file)
        return if File.exist?(file)

        raise ArgumentError, "File does not exist: #{file}"
      end

      # Ensure output directory exists
      #
      # @param output_dir [String] Output directory path
      # @return [String] The output directory path
      def ensure_output_dir(output_dir)
        FileUtils.mkdir_p(output_dir)
        output_dir
      end

      # Run the Validator on a file and raise on failure.
      #
      # @param file [String] Path to the archive file
      # @param level [Symbol] Validation level (:quick, :standard, :thorough)
      # @return [Cabriolet::ValidationReport] The validation report
      # @raise [Cabriolet::Error] if validation fails
      def validate_integrity(file, level: Cabriolet::Validator::LEVEL_QUICK)
        report = Cabriolet::Validator.new(file, level: level).validate

        unless report.valid?
          report.errors.each { |e| puts "ERROR: #{e}" }
          raise Cabriolet::Error, "Integrity check failed"
        end

        report
      end
    end
  end
end
