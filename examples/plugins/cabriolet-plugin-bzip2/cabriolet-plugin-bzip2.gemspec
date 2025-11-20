# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "cabriolet-plugin-bzip2"
  spec.version = "1.0.0"
  spec.authors = ["Cabriolet Team"]
  spec.email = ["support@example.com"]

  spec.summary = "BZip2 compression plugin for Cabriolet"
  spec.description = <<~DESC
    An advanced example plugin for Cabriolet demonstrating BZip2 compression
    algorithm integration. This is a stub implementation showcasing advanced
    plugin features including configuration, error handling, progress reporting,
    and format-specific registration.
  DESC

  spec.homepage = "https://github.com/omnizip/cabriolet"
  spec.license = "BSD-2-Clause"
  spec.required_ruby_version = ">= 2.7.0"

  spec.files = Dir["lib/**/*.rb", "README.md"].select { |f| File.exist?(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "cabriolet", "~> 0.1"
end
