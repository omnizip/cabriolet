# frozen_string_literal: true

require_relative "command_registry"
require_relative "base_command_handler"
require_relative "../format_detector"

module Cabriolet
  module Commands
    # Unified command dispatcher that routes commands to format-specific handlers
    #
    # The dispatcher is responsible for:
    # 1. Detecting the format of input files (or using manual override)
    # 2. Selecting the appropriate format handler from the registry
    # 3. Delegating command execution to the handler
    #
    # This class implements the Strategy pattern, where the format handler
    # is the strategy selected based on the detected format.
    #
    # @example Using the dispatcher
    #   dispatcher = CLI::CommandDispatcher.new(format: :cab, verbose: true)
    #   dispatcher.dispatch(:list, "archive.cab")
    #
    class CommandDispatcher
      # Initialize the command dispatcher
      #
      # @param options [Hash] Configuration options
      # @option options [String, Symbol] :format Manual format override
      # @option options [Boolean] :verbose Enable verbose output
      def initialize(options = {})
        @format_override = parse_format_option(options[:format])
        @verbose = options[:verbose] || false
      end

      # Dispatch a command to the appropriate format handler
      #
      # This method detects the format (if not manually specified),
      # retrieves the appropriate handler, and delegates the command execution.
      #
      # @param command [Symbol] The command to execute (:list, :extract, etc.)
      # @param file [String] Path to the archive file
      # @param args [Array] Additional positional arguments for the command
      # @param options [Hash] Additional options to pass to the handler
      # @raise [Cabriolet::Error] if format detection fails or handler not found
      # @return [void]
      def dispatch(command, file, *args, **options)
        format = detect_format(file)
        handler = get_handler_for(format)

        execute_command(handler, command, file, args, options)
      end

      # Check if a format is supported
      #
      # @param format [Symbol] The format to check
      # @return [Boolean] true if the format has a registered handler
      def self.format_supported?(format)
        CommandRegistry.format_registered?(format)
      end

      # Get list of supported formats
      #
      # @return [Array<Symbol>] List of supported format symbols
      def self.supported_formats
        CommandRegistry.registered_formats
      end

      private

      # Parse format option to symbol
      #
      # @param format_value [String, Symbol, nil] The format option value
      # @return [Symbol, nil] The format as a symbol
      def parse_format_option(format_value)
        return nil if format_value.nil?

        format_value.to_sym
      end

      # Detect format from file with fallback to manual override
      #
      # @param file [String] Path to the archive file
      # @return [Symbol] The detected format symbol
      # @raise [Cabriolet::Error] if format cannot be detected
      def detect_format(file)
        return @format_override if @format_override

        format = FormatDetector.detect(file)
        if format.nil?
          supported = CommandRegistry.registered_formats.join(", ")
          raise Error,
                "Cannot detect format for: #{file}. " \
                "Use --format to specify (supported: #{supported})"
        end

        format
      end

      # Get the handler class for a format
      #
      # @param format [Symbol] The format symbol
      # @return [Class] The handler class
      # @raise [Cabriolet::Error] if no handler is registered
      def get_handler_for(format)
        handler = CommandRegistry.handler_for(format)

        unless handler
          raise Error,
                "No command handler registered for format: #{format}"
        end

        handler
      end

      # Execute the command on the handler
      #
      # @param handler_class [Class] The handler class
      # @param command [Symbol] The command to execute
      # @param file [String] Path to the archive file
      # @param args [Array] Additional positional arguments
      # @param options [Hash] Additional options
      # @return [void]
      def execute_command(handler_class, command, file, args, options)
        handler = handler_class.new(verbose: @verbose)

        # Call the command method with appropriate arguments
        case command
        when :extract
          output_dir = args.first || options[:output_dir]
          handler.extract(file, output_dir, options)
        when :create
          files = args.first || options[:files] || []
          handler.create(file, files, options)
        else
          # For commands that take just file and options
          handler.public_send(command, file, options)
        end
      end
    end
  end
end
