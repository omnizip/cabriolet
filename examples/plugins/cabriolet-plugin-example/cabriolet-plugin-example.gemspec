# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "cabriolet-plugin-example"
  spec.version = "1.0.0"
  spec.authors = ["Cabriolet Team"]
  spec.email = ["support@example.com"]

  spec.summary = "Example plugin for Cabriolet demonstrating plugin architecture"
  spec.description = <<~DESC
    An example plugin for Cabriolet that demonstrates the plugin architecture
    and API. Implements a simple ROT13 compression/decompression algorithm for
    educational purposes.

    This plugin serves as a reference implementation for developers creating
    their own Cabriolet plugins. It showcases:
    - Plugin metadata definition
    - Algorithm registration
    - Lifecycle hooks
    - Testing strategies
    - Documentation practices
  DESC

  spec.homepage = "https://github.com/omnizip/cabriolet"
  spec.license = "BSD-2-Clause"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/main/examples/plugins/#{spec.name}"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/examples/plugins/#{spec.name}/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "#{spec.homepage}/blob/main/examples/plugins/#{spec.name}/README.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir[
    "lib/**/*.rb",
    "README.md",
    "LICENSE",
    "CHANGELOG.md",
  ].select { |f| File.exist?(f) }

  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "cabriolet", "~> 0.1"

  # Development dependencies are in Gemfile
end