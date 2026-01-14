# frozen_string_literal: true

module Cabriolet
  # Validates plugin classes and configurations
  #
  # The PluginValidator provides comprehensive validation for plugins
  # including inheritance checks, metadata validation, version
  # compatibility, and safety scanning.
  #
  # @example Validate a plugin class
  #   result = PluginValidator.validate(MyPlugin)
  #   if result[:valid]
  #     puts "Plugin is valid"
  #   else
  #     puts "Errors: #{result[:errors].join(', ')}"
  #   end
  class PluginValidator
    # Required metadata fields
    REQUIRED_METADATA = %i[name version author description
                           cabriolet_version].freeze

    # Dangerous method names to check for
    DANGEROUS_METHODS = %w[
      system exec spawn ` fork eval instance_eval class_eval
      module_eval binding const_set remove_const send __send__
      method_missing respond_to_missing?
    ].freeze

    class << self
      # Validate a plugin class
      #
      # Performs comprehensive validation including inheritance, metadata,
      # version compatibility, and safety checks.
      #
      # @param plugin_class [Class] Plugin class to validate
      #
      # @return [Hash] Validation result with:
      #   - :valid [Boolean] True if all checks pass
      #   - :errors [Array<String>] List of validation errors (empty if
      #     valid)
      #   - :warnings [Array<String>] List of warnings (non-fatal issues)
      #
      # @example Validate a plugin
      #   result = PluginValidator.validate(MyPlugin)
      #   result[:valid] #=> true
      #   result[:errors] #=> []
      #   result[:warnings] #=> ["Uses eval in setup method"]
      def validate(plugin_class)
        errors = []
        warnings = []

        # Check inheritance
        inherit_errors = validate_inheritance(plugin_class)
        errors.concat(inherit_errors)

        # If inheritance fails, stop here
        return { valid: false, errors: errors, warnings: warnings } unless
          inherit_errors.empty?

        # Create instance to check metadata
        begin
          instance = plugin_class.new(nil)
          metadata = instance.metadata

          # Validate metadata
          meta_errors = validate_metadata(metadata)
          errors.concat(meta_errors)

          # Check version compatibility
          if metadata[:cabriolet_version]
            version_errors = validate_version_compatibility(
              metadata[:cabriolet_version],
              Cabriolet::VERSION,
            )
            errors.concat(version_errors)
          end

          # Validate dependencies
          if metadata[:dependencies]
            dep_warnings = validate_dependencies(metadata[:dependencies])
            warnings.concat(dep_warnings)
          end
        rescue NotImplementedError => e
          errors << "Plugin does not implement required method: " \
                    "#{e.message}"
        rescue StandardError => e
          errors << "Failed to instantiate plugin: #{e.message}"
        end

        # Safety checks
        safety_warnings = check_safety(plugin_class)
        warnings.concat(safety_warnings)

        {
          valid: errors.empty?,
          errors: errors,
          warnings: warnings,
        }
      end

      # Validate plugin inheritance
      #
      # Checks that the plugin class properly inherits from
      # Cabriolet::Plugin.
      #
      # @param plugin_class [Class] Plugin class to validate
      #
      # @return [Array<String>] List of inheritance errors (empty if valid)
      #
      # @example Valid inheritance
      #   PluginValidator.validate_inheritance(MyPlugin)
      #   #=> []
      #
      # @example Invalid inheritance
      #   PluginValidator.validate_inheritance(Object)
      #   #=> ["Plugin must inherit from Cabriolet::Plugin"]
      def validate_inheritance(plugin_class)
        errors = []

        unless plugin_class.is_a?(Class)
          errors << "Plugin must be a class, got #{plugin_class.class}"
          return errors
        end

        unless plugin_class < Plugin
          errors << "Plugin must inherit from Cabriolet::Plugin"
        end

        errors
      end

      # Validate plugin metadata
      #
      # Checks that all required metadata fields are present and valid.
      #
      # @param metadata [Hash] Plugin metadata to validate
      #
      # @return [Array<String>] List of metadata errors (empty if valid)
      #
      # @example Valid metadata
      #   meta = { name: "test", version: "1.0", ... }
      #   PluginValidator.validate_metadata(meta)
      #   #=> []
      #
      # @example Missing fields
      #   PluginValidator.validate_metadata({})
      #   #=> ["Missing required metadata: name, version, ..."]
      def validate_metadata(metadata)
        errors = []

        unless metadata.is_a?(Hash)
          errors << "Metadata must be a Hash"
          return errors
        end

        # Check required fields
        missing = REQUIRED_METADATA - metadata.keys
        unless missing.empty?
          errors << "Missing required metadata: #{missing.join(', ')}"
        end

        # Validate field types and formats
        if metadata[:name]
          unless metadata[:name].is_a?(String) &&
              !metadata[:name].empty?
            errors << "Plugin name must be a non-empty string"
          end

          if metadata[:name].is_a?(String) && metadata[:name] =~ /^[a-z0-9_-]+$/
            # Valid format - do nothing
          elsif metadata[:name].is_a?(String)
            errors << "Plugin name must contain only lowercase letters, " \
                      "numbers, hyphens, and underscores"
          end
        end

        if metadata[:version] && !valid_version?(metadata[:version])
          errors << "Plugin version must be a valid semantic version " \
                    "(e.g., '1.0.0')"
        end

        if metadata[:author] && !(metadata[:author].is_a?(String) &&
                 !metadata[:author].empty?)
          errors << "Plugin author must be a non-empty string"
        end

        if metadata[:description] && !(metadata[:description].is_a?(String) &&
                 !metadata[:description].empty?)
          errors << "Plugin description must be a non-empty string"
        end

        # Optional fields validation
        if metadata[:homepage] && !metadata[:homepage].empty? && !valid_url?(metadata[:homepage])
          errors << "Plugin homepage must be a valid URL"
        end

        if metadata[:dependencies] && !metadata[:dependencies].is_a?(Array)
          errors << "Plugin dependencies must be an array"
        end

        if metadata[:tags] && !metadata[:tags].is_a?(Array)
          errors << "Plugin tags must be an array"
        end

        errors
      end

      # Validate version compatibility
      #
      # Checks if the plugin's required Cabriolet version matches the
      # current version.
      #
      # @param plugin_version [String] Required Cabriolet version
      # @param cabriolet_version [String] Current Cabriolet version
      #
      # @return [Array<String>] List of version errors (empty if
      #   compatible)
      #
      # @example Compatible version
      #   PluginValidator.validate_version_compatibility("~> 0.1", "0.1.0")
      #   #=> []
      #
      # @example Incompatible version
      #   PluginValidator.validate_version_compatibility(">= 2.0", "0.1.0")
      #   #=> ["Plugin requires Cabriolet version >= 2.0, ..."]
      def validate_version_compatibility(plugin_version, cabriolet_version)
        errors = []

        # Parse version requirement
        if plugin_version.start_with?("~>")
          # Pessimistic version constraint
          required = plugin_version.sub("~>", "").strip
          unless version_compatible?(cabriolet_version, required, :pessimistic)
            errors << "Plugin requires Cabriolet version ~> #{required}, " \
                      "but #{cabriolet_version} is installed"
          end
        elsif plugin_version.start_with?(">=")
          # Minimum version
          required = plugin_version.sub(">=", "").strip
          unless version_compatible?(cabriolet_version, required, :gte)
            errors << "Plugin requires Cabriolet version >= #{required}, " \
                      "but #{cabriolet_version} is installed"
          end
        elsif plugin_version.start_with?("=")
          # Exact version
          required = plugin_version.sub("=", "").strip
          unless cabriolet_version == required
            errors << "Plugin requires exact Cabriolet version #{required}, " \
                      "but #{cabriolet_version} is installed"
          end
        end

        errors
      end

      # Validate plugin dependencies
      #
      # Checks if dependency specifications are valid. This performs
      # format validation only; actual dependency resolution happens at
      # load time.
      #
      # @param dependencies [Array<String>] Dependency specifications
      #
      # @return [Array<String>] List of validation warnings
      #
      # @example Valid dependencies
      #   deps = ["other-plugin >= 1.0"]
      #   PluginValidator.validate_dependencies(deps)
      #   #=> []
      def validate_dependencies(dependencies)
        warnings = []

        unless dependencies.is_a?(Array)
          warnings << "Dependencies must be an array"
          return warnings
        end

        dependencies.each do |dep|
          unless dep.is_a?(String)
            warnings << "Each dependency must be a string"
            next
          end

          parts = dep.split
          if parts.empty?
            warnings << "Empty dependency specification"
          elsif !/^[a-z0-9_-]+$/.match?(parts[0])
            warnings << "Invalid dependency name: #{parts[0]}"
          end
        end

        warnings
      end

      # Check plugin for potentially dangerous code
      #
      # Scans the plugin's source code for dangerous method calls that
      # might pose security risks.
      #
      # @param plugin_class [Class] Plugin class to check
      #
      # @return [Array<String>] List of safety warnings
      #
      # @example Safe plugin
      #   PluginValidator.check_safety(MySafePlugin)
      #   #=> []
      #
      # @example Potentially dangerous plugin
      #   PluginValidator.check_safety(MyDangerousPlugin)
      #   #=> ["Uses system call in setup method"]
      def check_safety(plugin_class)
        warnings = []

        # Get source location
        begin
          methods_to_check = %i[setup activate metadata]

          methods_to_check.each do |method_name|
            next unless plugin_class.method_defined?(method_name, false)

            method_obj = plugin_class.instance_method(method_name)
            source_location = method_obj.source_location

            if source_location && File.exist?(source_location[0])
              source = File.read(source_location[0])

              DANGEROUS_METHODS.each do |dangerous|
                pattern = /\b#{Regexp.escape(dangerous)}\b/
                if source&.match?(pattern)
                  warnings << "Plugin uses potentially dangerous method " \
                              "'#{dangerous}' " \
                              "in #{source_location[0]}"
                end
              end
            end
          end
        rescue StandardError => e
          warnings << "Could not perform safety check: #{e.message}"
        end

        warnings
      end

      private

      # Check if a version string is valid
      #
      # @param version [String] Version string to check
      #
      # @return [Boolean] True if valid
      def valid_version?(version)
        version.is_a?(String) && version =~ /^\d+\.\d+(\.\d+)?$/
      end

      # Check if a URL is valid
      #
      # @param url [String] URL string to check
      #
      # @return [Boolean] True if valid
      def valid_url?(url)
        url.is_a?(String) && url =~ %r{^https?://}
      end

      # Check version compatibility
      #
      # @param actual [String] Actual version
      # @param required [String] Required version
      # @param constraint [Symbol] Constraint type (:gte, :pessimistic)
      #
      # @return [Boolean] True if compatible
      def version_compatible?(actual, required, constraint)
        actual_parts = actual.split(".").map(&:to_i)
        required_parts = required.split(".").map(&:to_i)

        case constraint
        when :gte
          compare_versions(actual_parts, required_parts) >= 0
        when :pessimistic
          # ~> 1.2 means >= 1.2 and < 2.0
          # ~> 1.2.3 means >= 1.2.3 and < 1.3
          return false if compare_versions(actual_parts,
                                           required_parts).negative?

          upper = required_parts.dup
          if required_parts.length >= 3
            # Patch-level constraint
            upper[1] += 1
            upper[2] = 0
          else
            # Minor-level constraint
            upper[0] += 1
            upper[1] = 0
          end

          compare_versions(actual_parts, upper).negative?
        else
          false
        end
      end

      # Compare version part arrays
      #
      # @param v1 [Array<Integer>] Version 1 parts
      # @param v2 [Array<Integer>] Version 2 parts
      #
      # @return [Integer] -1, 0, or 1
      def compare_versions(v1, v2)
        max_length = [v1.length, v2.length].max

        max_length.times do |i|
          p1 = v1[i] || 0
          p2 = v2[i] || 0

          return -1 if p1 < p2
          return 1 if p1 > p2
        end

        0
      end
    end
  end
end
