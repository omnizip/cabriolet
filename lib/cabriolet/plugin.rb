# frozen_string_literal: true

module Cabriolet
  # Base class for all Cabriolet plugins
  #
  # Plugins extend Cabriolet's functionality by providing custom compression
  # algorithms, format handlers, or other enhancements. All plugins must
  # inherit from this base class and implement required methods.
  #
  # @abstract Subclass and implement {#metadata} and {#setup} to create
  #   a plugin
  #
  # @example Creating a simple plugin
  #   class MyPlugin < Cabriolet::Plugin
  #     def metadata
  #       {
  #         name: "my-plugin",
  #         version: "1.0.0",
  #         author: "Your Name",
  #         description: "Adds custom compression algorithm",
  #         cabriolet_version: "~> 0.1"
  #       }
  #     end
  #
  #     def setup
  #       register_algorithm(:custom, CustomAlgorithm,
  #                         category: :compressor)
  #     end
  #   end
  class Plugin
    # Plugin states
    STATES = %i[discovered loaded active failed disabled].freeze

    # @return [Symbol] Current plugin state
    attr_reader :state

    # Initialize a new plugin
    #
    # @param manager [PluginManager] The plugin manager instance
    def initialize(manager = nil)
      @manager = manager
      @state = :discovered
    end

    # Get plugin metadata
    #
    # @abstract Must be implemented by subclasses
    #
    # @return [Hash] Plugin metadata containing:
    # @option return [String] :name Plugin name (required)
    # @option return [String] :version Plugin version (required)
    # @option return [String] :author Plugin author (required)
    # @option return [String] :description Plugin description (required)
    # @option return [String] :cabriolet_version Compatible Cabriolet
    #   version (required)
    # @option return [String] :homepage Plugin homepage URL (optional)
    # @option return [String] :license Plugin license (optional)
    # @option return [Array<String>] :dependencies Plugin dependencies
    #   (optional)
    # @option return [Array<String>] :tags Search tags (optional)
    # @option return [Hash] :provides What the plugin provides (optional)
    #
    # @raise [NotImplementedError] If not implemented by subclass
    #
    # @example Minimal metadata
    #   def metadata
    #     {
    #       name: "my-plugin",
    #       version: "1.0.0",
    #       author: "Your Name",
    #       description: "Plugin description",
    #       cabriolet_version: "~> 0.1"
    #     }
    #   end
    #
    # @example Full metadata
    #   def metadata
    #     {
    #       name: "advanced-plugin",
    #       version: "2.0.0",
    #       author: "Developer",
    #       description: "Advanced features",
    #       cabriolet_version: ">= 0.1.0",
    #       homepage: "https://example.com",
    #       license: "MIT",
    #       dependencies: ["other-plugin >= 1.0"],
    #       tags: ["compression", "algorithm"],
    #       provides: { algorithms: [:custom], formats: [:special] }
    #     }
    #   end
    def metadata
      raise NotImplementedError,
            "#{self.class} must implement metadata method"
    end

    # Setup the plugin
    #
    # Called when the plugin is loaded. Use this method to register
    # algorithms, formats, or perform other initialization tasks.
    #
    # @abstract Must be implemented by subclasses
    #
    # @raise [NotImplementedError] If not implemented by subclass
    #
    # @example Register an algorithm
    #   def setup
    #     register_algorithm(:myalgo, MyAlgorithm,
    #                       category: :compressor)
    #   end
    #
    # @example Register multiple items
    #   def setup
    #     register_algorithm(:algo1, Algo1, category: :compressor)
    #     register_algorithm(:algo2, Algo2, category: :decompressor)
    #     register_format(:myformat, MyFormatHandler)
    #   end
    def setup
      raise NotImplementedError,
            "#{self.class} must implement setup method"
    end

    # Activate the plugin
    #
    # Called when the plugin is activated. Override to perform actions
    # when the plugin becomes active.
    #
    # @return [void]
    #
    # @example Add hooks on activation
    #   def activate
    #     puts "#{metadata[:name]} activated"
    #     # Additional activation logic...
    #   end
    def activate
      # Default implementation does nothing
    end

    # Deactivate the plugin
    #
    # Called when the plugin is deactivated. Override to perform cleanup
    # when the plugin is deactivated.
    #
    # @return [void]
    #
    # @example Cleanup on deactivation
    #   def deactivate
    #     # Cleanup resources...
    #     puts "#{metadata[:name]} deactivated"
    #   end
    def deactivate
      # Default implementation does nothing
    end

    # Cleanup the plugin
    #
    # Called when the plugin is unloaded. Override to perform final
    # cleanup tasks.
    #
    # @return [void]
    #
    # @example Final cleanup
    #   def cleanup
    #     # Release resources...
    #     # Close connections...
    #   end
    def cleanup
      # Default implementation does nothing
    end

    protected

    # Register a compression or decompression algorithm
    #
    # @param type [Symbol] Algorithm type identifier
    # @param klass [Class] Algorithm class
    # @param options [Hash] Registration options
    # @option options [Symbol] :category Required - :compressor or
    #   :decompressor
    # @option options [Integer] :priority Algorithm priority (default: 0)
    # @option options [Symbol, nil] :format Format restriction (optional)
    #
    # @return [void]
    #
    # @raise [PluginError] If manager is not available
    #
    # @example Register a compressor
    #   register_algorithm(:myalgo, MyCompressor,
    #                     category: :compressor, priority: 10)
    #
    # @example Register a format-specific decompressor
    #   register_algorithm(:special, SpecialDecompressor,
    #                     category: :decompressor, format: :cab)
    def register_algorithm(type, klass, **options)
      raise PluginError, "Plugin manager not available" unless @manager

      Cabriolet.algorithm_factory.register(type, klass, **options)
    end

    # Register a format handler
    #
    # @param format [Symbol] Format identifier
    # @param handler [Class] Format handler class
    #
    # @return [void]
    #
    # @raise [PluginError] If manager is not available
    #
    # @example Register a format handler
    #   register_format(:myformat, MyFormatHandler)
    def register_format(format, handler)
      raise PluginError, "Plugin manager not available" unless @manager

      # Format registration will be implemented when format registry exists
      # For now, store in manager's format registry
      @manager.register_format(format, handler)
    end

    # Update plugin state
    #
    # @param new_state [Symbol] New state (must be in STATES)
    #
    # @return [void]
    #
    # @raise [ArgumentError] If state is invalid
    def update_state(new_state)
      unless STATES.include?(new_state)
        raise ArgumentError, "Invalid state: #{new_state}"
      end

      @state = new_state
    end
  end
end
