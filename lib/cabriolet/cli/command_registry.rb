# frozen_string_literal: true

module Cabriolet
  module Commands
    # Registry for mapping format symbols to command handler classes
    #
    # This registry provides a centralized location for managing format handlers,
    # following the Open/Closed Principle - new formats can be added without
    # modifying existing command logic.
    #
    # @example Registering a format handler
    #   CLI::CommandRegistry.register_format(:cab, CAB::CommandHandler)
    #
    # @example Getting a handler for a format
    #   handler = CLI::CommandRegistry.handler_for(:cab)
    #
    class CommandRegistry
      @handlers = {}

      class << self
        # Get the command handler class for a given format
        #
        # @param format [Symbol] The format symbol (e.g., :cab, :chm, :szdd)
        # @return [Class, nil] The handler class or nil if not registered
        def handler_for(format)
          @handlers[format]
        end

        # Register a command handler for a format
        #
        # This allows for dynamic registration of format handlers,
        # supporting extensibility and plugin architectures.
        #
        # @param format [Symbol] The format symbol
        # @param handler_class [Class] The command handler class
        # @raise [ArgumentError] if handler_class doesn't implement required interface
        def register_format(format, handler_class)
          validate_handler_interface(handler_class)
          @handlers[format] = handler_class
        end

        # Get all registered formats
        #
        # @return [Array<Symbol>] List of registered format symbols
        def registered_formats
          @handlers.keys
        end

        # Check if a format is registered
        #
        # @param format [Symbol] The format symbol
        # @return [Boolean] true if the format has a registered handler
        def format_registered?(format)
          @handlers.key?(format)
        end

        # Clear all registered formats (primarily for testing)
        #
        # @return [void]
        def clear
          @handlers = {}
        end

        private

        # Validate that a handler class implements the required interface
        #
        # @param handler_class [Class] The class to validate
        # @raise [ArgumentError] if the class doesn't implement required methods
        def validate_handler_interface(handler_class)
          required_methods = %i[list extract create info test]

          required_methods.each do |method|
            unless handler_class.method_defined?(method)
              raise ArgumentError,
                    "Handler class #{handler_class} must implement ##{method}"
            end
          end
        end
      end
    end
  end
end
