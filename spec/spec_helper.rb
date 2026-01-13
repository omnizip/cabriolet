# frozen_string_literal: true

require "cabriolet"
require "rspec/its"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Helper to get fixture path
  config.define_singleton_method(:fixture_path) do |*path|
    File.join(__dir__, "fixtures", *path)
  end
end

# Helper method for fixture paths
def fixture_path(*path)
  File.join(__dir__, "fixtures", *path)
end
