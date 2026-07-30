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
    # #list, #info and #test are implemented here as the shared
    # validate -> open -> render -> close flow. A subclass supplies its
    # decompressor and the three render hooks. #test inserts two more steps
    # between open and render: it prints the "Testing <file>..." banner and
    # runs validate_integrity, so a failed check aborts before the format's
    # own report is written.
    #
    # A format whose read commands do not open an archive opts out by
    # overriding #list, #info and #test outright. OAB does exactly that: it is
    # a compressed stream rather than an archive, so it never reaches this
    # template.
    #
    # @example Creating a format handler
    #   module Cabriolet
    #     module CAB
    #       class CommandHandler < Commands::BaseCommandHandler
    #         private
    #
    #         def decompressor_class
    #           Decompressor
    #         end
    #
    #         def render_listing(session, file, options)
    #           # What #list prints
    #         end
    #
    #         def render_info(session, file)
    #           # What #info prints
    #         end
    #
    #         def render_test_result(session)
    #           # What #test prints once the integrity check passes
    #         end
    #       end
    #     end
    #   end
    #
    class BaseCommandHandler
      # An opened archive together with the decompressor that opened it.
      ArchiveSession = Struct.new(:decompressor, :archive)

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
      # @return [void]
      def list(file, options = {})
        validate_file_exists(file)
        session = open_archive(file)
        render_listing(session, file, options)
        close_archive(session)
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
      # @return [void]
      def info(file, _options = {})
        validate_file_exists(file)
        session = open_archive(file)
        render_info(session, file)
        close_archive(session)
      end

      # Test archive integrity
      #
      # @param file [String] Path to the archive file
      # @param options [Hash] Additional options
      # @return [void]
      # @raise [Cabriolet::Error] if the integrity check fails
      def test(file, _options = {})
        validate_file_exists(file)
        session = open_archive(file)

        puts "Testing #{file}..."
        validate_integrity(file)
        render_test_result(session)
        close_archive(session)
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

      private

      # The decompressor class this format opens archives with
      #
      # @return [Class] A class answering #open(file) and #close(archive)
      # @raise [NotImplementedError] Subclass must implement
      def decompressor_class
        raise NotImplementedError,
              "#{self.class} must implement #decompressor_class"
      end

      # Open an archive and pair it with its decompressor
      #
      # @param file [String] Path to the archive file
      # @return [ArchiveSession] The opened session
      def open_archive(file)
        decompressor = decompressor_class.new
        ArchiveSession.new(decompressor, decompressor.open(file))
      end

      # Release an opened archive
      #
      # Deliberately not wrapped in an ensure. Anything that raises after the
      # archive is opened skips this call and leaves it unclosed: a failing
      # render, and in #test a failing validate_integrity too. That second path
      # is not hypothetical — LIT takes it on every successfully opened file,
      # because the Validator rejects the format outright. Preserving the
      # existing semantics; adding cleanup is a separate concern.
      #
      # @param session [ArchiveSession] The session to close
      # @return [void]
      def close_archive(session)
        session.decompressor.close(session.archive)
      end

      # Print the archive listing
      #
      # @param session [ArchiveSession] The opened session
      # @param file [String] Path to the archive file
      # @param options [Hash] Additional options
      # @raise [NotImplementedError] Subclass must implement
      def render_listing(session, file, options)
        raise NotImplementedError,
              "#{self.class} must implement #render_listing"
      end

      # Print detailed archive information
      #
      # @param session [ArchiveSession] The opened session
      # @param file [String] Path to the archive file
      # @raise [NotImplementedError] Subclass must implement
      def render_info(session, file)
        raise NotImplementedError,
              "#{self.class} must implement #render_info"
      end

      # Print the outcome of a successful integrity check
      #
      # @param session [ArchiveSession] The opened session
      # @raise [NotImplementedError] Subclass must implement
      def render_test_result(session)
        raise NotImplementedError,
              "#{self.class} must implement #render_test_result"
      end
    end
  end
end
