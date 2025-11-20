# frozen_string_literal: true

require "singleton"
require "yaml"

module Cabriolet
  # Manages plugin lifecycle and registry for Cabriolet
  #
  # The PluginManager is a thread-safe singleton that handles plugin
  # discovery, loading, activation, and deactivation. It maintains plugin
  # states and resolves dependencies.
  #
  # @example Access the plugin manager
  #   manager = Cabriolet::PluginManager.instance
  #   manager.discover_plugins
  #   manager.load_plugin("my-plugin")
  #   manager.activate_plugin("my-plugin")
  #
  # @example Using global accessor
  #   Cabriolet.plugin_manager.discover_plugins
  #   Cabriolet.plugin_manager.list_plugins(state: :active)
  class PluginManager
    include Singleton

    # @return [Hash] Plugin registry by name
    attr_reader :plugins

    # @return [Hash] Format registry
    attr_reader :formats

    # Initialize the plugin manager
    def initialize
      @plugins = {}
      @formats = {}
      @mutex = Mutex.new
      @config = load_config
    end

    # Discover available plugins
    #
    # Searches for plugins in gem paths using the pattern
    # 'cabriolet/plugins/**/*.rb'. Discovered plugins are added to the
    # registry in :discovered state.
    #
    # @return [Array<String>] List of discovered plugin names
    #
    # @example Discover plugins
    #   manager.discover_plugins
    #   #=> ["plugin1", "plugin2"]
    def discover_plugins
      @mutex.synchronize do
        plugin_files = Gem.find_files("cabriolet/plugins/**/*.rb")

        plugin_files.each do |file|
          begin
            load_plugin_file(file)
          rescue StandardError => e
            warn "Failed to load plugin from #{file}: #{e.message}"
          end
        end

        @plugins.keys
      end
    end

    # Register a plugin instance
    #
    # Adds a plugin to the registry. The plugin must be a valid Plugin
    # instance with proper metadata.
    #
    # @param plugin_instance [Plugin] Plugin instance to register
    #
    # @return [Boolean] True if registered successfully
    #
    # @raise [PluginError] If plugin is invalid
    #
    # @example Register a plugin
    #   plugin = MyPlugin.new(manager)
    #   manager.register(plugin)
    def register(plugin_instance)
      @mutex.synchronize do
        unless plugin_instance.is_a?(Plugin)
          raise PluginError,
                "Plugin must inherit from Cabriolet::Plugin"
        end

        # Validate plugin
        validation = PluginValidator.validate(plugin_instance.class)
        unless validation[:valid]
          raise PluginError,
                "Plugin validation failed: #{validation[:errors].join(', ')}"
        end

        meta = plugin_instance.metadata
        name = meta[:name]

        if @plugins.key?(name)
          raise PluginError, "Plugin '#{name}' already registered"
        end

        @plugins[name] = {
          instance: plugin_instance,
          metadata: meta,
          state: :discovered,
        }

        true
      end
    end

    # Load a plugin
    #
    # Loads and validates a discovered plugin. Calls the plugin's setup
    # method and transitions to :loaded state.
    #
    # @param name [String] Plugin name
    #
    # @return [Boolean] True if loaded successfully
    #
    # @raise [PluginError] If plugin not found or load fails
    #
    # @example Load a plugin
    #   manager.load_plugin("my-plugin")
    def load_plugin(name)
      @mutex.synchronize do
        entry = @plugins[name]
        raise PluginError, "Plugin '#{name}' not found" unless entry

        if entry[:state] == :loaded || entry[:state] == :active
          return true
        end

        begin
          plugin = entry[:instance]

          # Check dependencies
          check_dependencies!(entry[:metadata])

          # Call setup
          plugin.setup
          plugin.send(:update_state, :loaded)
          entry[:state] = :loaded

          true
        rescue StandardError => e
          plugin.send(:update_state, :failed)
          entry[:state] = :failed
          entry[:error] = e.message
          raise PluginError, "Failed to load plugin '#{name}': #{e.message}"
        end
      end
    end

    # Activate a plugin
    #
    # Activates a loaded plugin. Calls the plugin's activate method and
    # transitions to :active state.
    #
    # @param name [String] Plugin name
    #
    # @return [Boolean] True if activated successfully
    #
    # @raise [PluginError] If plugin not found or not loaded
    #
    # @example Activate a plugin
    #   manager.activate_plugin("my-plugin")
    def activate_plugin(name)
      @mutex.synchronize do
        entry = @plugins[name]
        raise PluginError, "Plugin '#{name}' not found" unless entry

        if entry[:state] == :active
          return true
        end

        unless entry[:state] == :loaded
          raise PluginError,
                "Plugin '#{name}' must be loaded before activation"
        end

        begin
          plugin = entry[:instance]
          plugin.activate
          plugin.send(:update_state, :active)
          entry[:state] = :active

          true
        rescue StandardError => e
          plugin.send(:update_state, :failed)
          entry[:state] = :failed
          entry[:error] = e.message
          raise PluginError,
                "Failed to activate plugin '#{name}': #{e.message}"
        end
      end
    end

    # Deactivate a plugin
    #
    # Deactivates an active plugin. Calls the plugin's deactivate method
    # and transitions back to :loaded state.
    #
    # @param name [String] Plugin name
    #
    # @return [Boolean] True if deactivated successfully
    #
    # @raise [PluginError] If plugin not found
    #
    # @example Deactivate a plugin
    #   manager.deactivate_plugin("my-plugin")
    def deactivate_plugin(name)
      @mutex.synchronize do
        entry = @plugins[name]
        raise PluginError, "Plugin '#{name}' not found" unless entry

        if entry[:state] != :active
          return true
        end

        begin
          plugin = entry[:instance]
          plugin.deactivate
          plugin.send(:update_state, :loaded)
          entry[:state] = :loaded

          true
        rescue StandardError => e
          entry[:error] = e.message
          raise PluginError,
                "Failed to deactivate plugin '#{name}': #{e.message}"
        end
      end
    end

    # List plugins
    #
    # Returns plugin information, optionally filtered by state.
    #
    # @param state [Symbol, nil] Optional state filter (:discovered,
    #   :loaded, :active, :failed, :disabled)
    #
    # @return [Hash] Plugin information keyed by name
    #
    # @example List all plugins
    #   manager.list_plugins
    #   #=> { "plugin1" => {...}, "plugin2" => {...} }
    #
    # @example List only active plugins
    #   manager.list_plugins(state: :active)
    #   #=> { "active-plugin" => {...} }
    def list_plugins(state: nil)
      @mutex.synchronize do
        if state.nil?
          @plugins.transform_values do |entry|
            {
              metadata: entry[:metadata],
              state: entry[:state],
              error: entry[:error],
            }
          end
        else
          @plugins.select { |_, entry| entry[:state] == state }
                 .transform_values do |entry|
            {
              metadata: entry[:metadata],
              state: entry[:state],
              error: entry[:error],
            }
          end
        end
      end
    end

    # Get a plugin by name
    #
    # @param name [String] Plugin name
    #
    # @return [Plugin, nil] Plugin instance or nil if not found
    #
    # @example Get a plugin
    #   plugin = manager.plugin("my-plugin")
    def plugin(name)
      @mutex.synchronize do
        @plugins[name]&.dig(:instance)
      end
    end

    # Check if a plugin is active
    #
    # @param name [String] Plugin name
    #
    # @return [Boolean] True if plugin is active
    #
    # @example Check plugin status
    #   manager.plugin_active?("my-plugin") #=> true
    def plugin_active?(name)
      @mutex.synchronize do
        @plugins[name]&.dig(:state) == :active
      end
    end

    # Register a format handler
    #
    # Called by plugins to register format handlers. This is used
    # internally by Plugin#register_format.
    #
    # @param format [Symbol] Format identifier
    # @param handler [Class] Handler class
    #
    # @return [void]
    #
    # @api private
    def register_format(format, handler)
      @mutex.synchronize do
        @formats[format] = handler
      end
    end

    # Get format handler
    #
    # @param format [Symbol] Format identifier
    #
    # @return [Class, nil] Handler class or nil
    #
    # @example Get format handler
    #   handler = manager.format_handler(:myformat)
    def format_handler(format)
      @mutex.synchronize do
        @formats[format]
      end
    end

    private

    # Load configuration from ~/.cabriolet/plugins.yml
    #
    # @return [Hash] Configuration hash
    def load_config
      config_path = File.expand_path("~/.cabriolet/plugins.yml")
      return {} unless File.exist?(config_path)

      YAML.load_file(config_path) || {}
    rescue StandardError => e
      warn "Failed to load plugin config: #{e.message}"
      {}
    end

    # Load a plugin file
    #
    # @param file [String] Plugin file path
    #
    # @return [void]
    def load_plugin_file(file)
      require file

      # After requiring, plugin classes should auto-register
      # This is a convention - plugins call register in their class body
    end

    # Check plugin dependencies
    #
    # @param metadata [Hash] Plugin metadata
    #
    # @return [void]
    #
    # @raise [PluginError] If dependencies not met
    def check_dependencies!(metadata)
      dependencies = metadata[:dependencies] || []

      dependencies.each do |dep|
        dep_name, dep_version = parse_dependency(dep)

        unless @plugins.key?(dep_name)
          raise PluginError,
                "Missing dependency: #{dep_name}"
        end

        dep_entry = @plugins[dep_name]
        unless dep_entry[:state] == :loaded || dep_entry[:state] == :active
          raise PluginError,
                "Dependency '#{dep_name}' not loaded"
        end

        if dep_version
          actual_version = dep_entry[:metadata][:version]
          unless version_satisfies?(actual_version, dep_version)
            raise PluginError,
                  "Dependency '#{dep_name}' version mismatch: " \
                  "need #{dep_version}, have #{actual_version}"
          end
        end
      end
    end

    # Parse dependency string
    #
    # @param dep [String] Dependency string (e.g., "plugin >= 1.0")
    #
    # @return [Array<String, String>] [name, version_requirement]
    def parse_dependency(dep)
      parts = dep.split
      name = parts[0]
      version = parts[1..].join(" ") if parts.length > 1

      [name, version]
    end

    # Check if version satisfies requirement
    #
    # @param version [String] Actual version
    # @param requirement [String] Version requirement
    #
    # @return [Boolean] True if satisfied
    def version_satisfies?(version, requirement)
      # Simple version check - can be enhanced with gem version logic
      return true if requirement.nil?

      # Parse requirement (e.g., ">= 1.0", "~> 2.0", "= 1.5")
      if requirement.start_with?(">=")
        min_version = requirement.sub(">=", "").strip
        compare_versions(version, min_version) >= 0
      elsif requirement.start_with?("~>")
        # Pessimistic version constraint
        base = requirement.sub("~>", "").strip
        compare_versions(version, base) >= 0
      elsif requirement.start_with?("=")
        exact = requirement.sub("=", "").strip
        version == exact
      else
        true
      end
    end

    # Compare two version strings
    #
    # @param v1 [String] Version 1
    # @param v2 [String] Version 2
    #
    # @return [Integer] -1, 0, or 1
    def compare_versions(v1, v2)
      parts1 = v1.split(".").map(&:to_i)
      parts2 = v2.split(".").map(&:to_i)

      [parts1.length, parts2.length].max.times do |i|
        p1 = parts1[i] || 0
        p2 = parts2[i] || 0

        return -1 if p1 < p2
        return 1 if p1 > p2
      end

      0
    end
  end
end