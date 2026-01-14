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

  # Ensure command handlers are always registered before each test
  # This prevents registry-clearing in command_registry_spec.rb from breaking subsequent tests
  config.before do
    require "cabriolet/cli" unless defined?(Cabriolet::CLI)

    # Re-register all format handlers to ensure they're available
    # This is needed because command_registry_spec.rb clears the registry in after hooks
    Cabriolet::Commands::CommandRegistry.register_format(:cab, Cabriolet::CAB::CommandHandler)
    Cabriolet::Commands::CommandRegistry.register_format(:chm, Cabriolet::CHM::CommandHandler)
    Cabriolet::Commands::CommandRegistry.register_format(:szdd, Cabriolet::SZDD::CommandHandler)
    Cabriolet::Commands::CommandRegistry.register_format(:kwaj, Cabriolet::KWAJ::CommandHandler)
    Cabriolet::Commands::CommandRegistry.register_format(:hlp, Cabriolet::HLP::CommandHandler)
    Cabriolet::Commands::CommandRegistry.register_format(:lit, Cabriolet::LIT::CommandHandler)
    Cabriolet::Commands::CommandRegistry.register_format(:oab, Cabriolet::OAB::CommandHandler)
  end
end

# Helper method for fixture paths
def fixture_path(*path)
  File.join(__dir__, "fixtures", *path)
end
