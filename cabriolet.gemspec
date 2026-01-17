# frozen_string_literal: true

require_relative "lib/cabriolet/version"

Gem::Specification.new do |spec|
  spec.name = "cabriolet"
  spec.version = Cabriolet::VERSION
  spec.authors = ["Ribose Inc."]
  spec.email = ["open.source@ribose.com"]

  spec.summary = "Pure Ruby implementation for extracting Microsoft Cabinet files"
  spec.description = <<~DESC
    Cabriolet is a pure Ruby gem for extracting Microsoft Cabinet (.CAB) files.
    It supports multiple compression algorithms (MSZIP, LZX, Quantum, LZSS) and
    requires no C extensions, making it portable across all Ruby platforms.
  DESC
  spec.homepage = "https://github.com/omnizip/cabriolet"
  spec.license = "BSD-3-Clause"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["documentation_uri"] = "https://rubydoc.info/gems/cabriolet"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob("{lib,exe}/**/*") + %w[
    README.adoc
    LICENSE
  ]
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "bindata", "~> 2.5"
  spec.add_dependency "fractor", "~> 0.1"
  spec.add_dependency "thor", "~> 1.3"
end
