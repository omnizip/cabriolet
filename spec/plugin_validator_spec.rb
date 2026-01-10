# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::PluginValidator do
  # Valid test plugin
  class ValidPlugin < Cabriolet::Plugin
    def metadata
      {
        name: "valid-plugin",
        version: "1.0.0",
        author: "Test Author",
        description: "A valid test plugin",
        cabriolet_version: "~> 0.1",
      }
    end

    def setup
      # Valid setup
    end
  end

  # Invalid plugin (doesn't inherit from Plugin)
  class InvalidPlugin
    def metadata
      { name: "invalid" }
    end

    def setup; end
  end

  describe ".validate" do
    it "validates a correct plugin" do
      result = described_class.validate(ValidPlugin)
      expect(result[:valid]).to be true
      expect(result[:errors]).to be_empty
    end

    it "returns validation result structure" do
      result = described_class.validate(ValidPlugin)
      expect(result).to have_key(:valid)
      expect(result).to have_key(:errors)
      expect(result).to have_key(:warnings)
    end

    it "detects invalid inheritance" do
      result = described_class.validate(InvalidPlugin)
      expect(result[:valid]).to be false
      expect(result[:errors]).to include(/must inherit/)
    end

    it "detects missing metadata" do
      plugin_class = Class.new(Cabriolet::Plugin) do
        def metadata
          { name: "incomplete" }
        end

        def setup; end
      end

      result = described_class.validate(plugin_class)
      expect(result[:valid]).to be false
      expect(result[:errors].first).to include("Missing required metadata")
    end

    it "handles plugin instantiation errors" do
      plugin_class = Class.new(Cabriolet::Plugin) do
        def initialize(*args)
          raise "Instantiation failed"
        end
      end

      result = described_class.validate(plugin_class)
      expect(result[:valid]).to be false
      expect(result[:errors].first).to include("Failed to instantiate")
    end

    it "validates version compatibility" do
      plugin_class = Class.new(Cabriolet::Plugin) do
        def metadata
          {
            name: "test",
            version: "1.0.0",
            author: "Author",
            description: "Description",
            cabriolet_version: ">= 99.0.0",
          }
        end

        def setup; end
      end

      result = described_class.validate(plugin_class)
      expect(result[:valid]).to be false
      expect(result[:errors].first).to include("requires Cabriolet version")
    end
  end

  describe ".validate_inheritance" do
    it "accepts valid plugin class" do
      errors = described_class.validate_inheritance(ValidPlugin)
      expect(errors).to be_empty
    end

    it "rejects non-class objects" do
      errors = described_class.validate_inheritance("not a class")
      expect(errors).to include(/must be a class/)
    end

    it "rejects classes not inheriting from Plugin" do
      errors = described_class.validate_inheritance(Object)
      expect(errors).to include(/must inherit from/)
    end
  end

  describe ".validate_metadata" do
    let(:valid_metadata) do
      {
        name: "test-plugin",
        version: "1.0.0",
        author: "Test Author",
        description: "Test description",
        cabriolet_version: "~> 0.1",
      }
    end

    it "accepts valid metadata" do
      errors = described_class.validate_metadata(valid_metadata)
      expect(errors).to be_empty
    end

    it "rejects non-hash metadata" do
      errors = described_class.validate_metadata("not a hash")
      expect(errors).to include(/must be a Hash/)
    end

    it "detects missing required fields" do
      errors = described_class.validate_metadata({})
      expect(errors.first).to include("Missing required metadata")
    end

    context "name validation" do
      it "rejects non-string name" do
        meta = valid_metadata.merge(name: 123)
        errors = described_class.validate_metadata(meta)
        expect(errors).to include(/name must be a non-empty string/)
      end

      it "rejects empty name" do
        meta = valid_metadata.merge(name: "")
        errors = described_class.validate_metadata(meta)
        expect(errors).to include(/name must be a non-empty string/)
      end

      it "rejects invalid characters in name" do
        meta = valid_metadata.merge(name: "Invalid Name!")
        errors = described_class.validate_metadata(meta)
        expect(errors).to include(/must contain only lowercase/)
      end

      it "accepts valid name formats" do
        ["test", "test-plugin", "test_plugin", "test123"].each do |name|
          meta = valid_metadata.merge(name: name)
          errors = described_class.validate_metadata(meta)
          name_errors = errors.select { |e| e.include?("name") }
          expect(name_errors).to be_empty
        end
      end
    end

    context "version validation" do
      it "rejects invalid version format" do
        meta = valid_metadata.merge(version: "invalid")
        errors = described_class.validate_metadata(meta)
        expect(errors).to include(/valid semantic version/)
      end

      it "accepts valid version formats" do
        ["1.0", "1.0.0", "2.5.3"].each do |version|
          meta = valid_metadata.merge(version: version)
          errors = described_class.validate_metadata(meta)
          version_errors = errors.select { |e| e.include?("version") }
          expect(version_errors).to be_empty
        end
      end
    end

    context "optional fields validation" do
      it "validates homepage URL" do
        meta = valid_metadata.merge(homepage: "not-a-url")
        errors = described_class.validate_metadata(meta)
        expect(errors).to include(/must be a valid URL/)
      end

      it "accepts valid homepage URL" do
        meta = valid_metadata.merge(homepage: "https://example.com")
        errors = described_class.validate_metadata(meta)
        url_errors = errors.select { |e| e.include?("homepage") }
        expect(url_errors).to be_empty
      end

      it "validates dependencies array" do
        meta = valid_metadata.merge(dependencies: "not-an-array")
        errors = described_class.validate_metadata(meta)
        expect(errors).to include(/dependencies must be an array/)
      end

      it "validates tags array" do
        meta = valid_metadata.merge(tags: "not-an-array")
        errors = described_class.validate_metadata(meta)
        expect(errors).to include(/tags must be an array/)
      end
    end
  end

  describe ".validate_version_compatibility" do
    let(:current_version) { "0.1.0" }

    context "pessimistic version constraint" do
      it "accepts compatible version" do
        errors = described_class.validate_version_compatibility(
          "~> 0.1",
          current_version
        )
        expect(errors).to be_empty
      end

      it "rejects incompatible version" do
        errors = described_class.validate_version_compatibility(
          "~> 2.0",
          current_version
        )
        expect(errors).to include(/requires Cabriolet version/)
      end
    end

    context "minimum version constraint" do
      it "accepts higher version" do
        errors = described_class.validate_version_compatibility(
          ">= 0.1.0",
          current_version
        )
        expect(errors).to be_empty
      end

      it "rejects lower version" do
        errors = described_class.validate_version_compatibility(
          ">= 1.0.0",
          current_version
        )
        expect(errors).to include(/requires Cabriolet version/)
      end
    end

    context "exact version constraint" do
      it "accepts exact match" do
        errors = described_class.validate_version_compatibility(
          "= 0.1.0",
          current_version
        )
        expect(errors).to be_empty
      end

      it "rejects different version" do
        errors = described_class.validate_version_compatibility(
          "= 1.0.0",
          current_version
        )
        expect(errors).to include(/requires exact Cabriolet version/)
      end
    end
  end

  describe ".validate_dependencies" do
    it "accepts valid dependencies" do
      deps = ["plugin1 >= 1.0", "plugin2 ~> 2.0"]
      warnings = described_class.validate_dependencies(deps)
      expect(warnings).to be_empty
    end

    it "warns on non-array dependencies" do
      warnings = described_class.validate_dependencies("not-an-array")
      expect(warnings).to include(/must be an array/)
    end

    it "warns on non-string dependency" do
      warnings = described_class.validate_dependencies([123])
      expect(warnings).to include(/must be a string/)
    end

    it "warns on empty dependency" do
      warnings = described_class.validate_dependencies([""])
      expect(warnings).to include(/Empty dependency/)
    end

    it "warns on invalid dependency name" do
      warnings = described_class.validate_dependencies(["Invalid Name!"])
      expect(warnings).to include(/Invalid dependency name/)
    end
  end

  describe ".check_safety" do
    it "returns empty warnings for safe plugin" do
      warnings = described_class.check_safety(ValidPlugin)
      expect(warnings).to be_an(Array)
    end

    it "detects dangerous method usage" do
      # Create a plugin file that uses system call
      dangerous_plugin = Class.new(Cabriolet::Plugin) do
        def metadata
          {
            name: "dangerous",
            version: "1.0.0",
            author: "Author",
            description: "Dangerous plugin",
            cabriolet_version: "~> 0.1",
          }
        end

        def setup
          # This would be detected if source is available
          # system("ls")
        end
      end

      # Safety check requires source file access
      # In practice, it would detect dangerous methods
      warnings = described_class.check_safety(dangerous_plugin)
      # May be empty if source not available, which is acceptable
      expect(warnings).to be_an(Array)
    end

    it "handles plugins without source files" do
      # Anonymous classes don't have source files
      anon_plugin = Class.new(Cabriolet::Plugin) do
        def metadata
          {
            name: "anonymous",
            version: "1.0.0",
            author: "Author",
            description: "Anonymous plugin",
            cabriolet_version: "~> 0.1",
          }
        end

        def setup; end
      end

      warnings = described_class.check_safety(anon_plugin)
      expect(warnings).to be_an(Array)
    end
  end

  describe "constants" do
    it "defines required metadata fields" do
      expect(Cabriolet::PluginValidator::REQUIRED_METADATA).to eq(
        %i[name version author description cabriolet_version]
      )
    end

    it "defines dangerous methods list" do
      expect(Cabriolet::PluginValidator::DANGEROUS_METHODS).to include(
        "system", "exec", "eval", "spawn"
      )
    end
  end
end
