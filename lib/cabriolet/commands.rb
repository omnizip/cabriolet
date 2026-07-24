# frozen_string_literal: true

module Cabriolet
  module Commands
    autoload :BaseCommandHandler, "cabriolet/cli/base_command_handler"
    autoload :CommandDispatcher, "cabriolet/cli/command_dispatcher"
    autoload :CommandRegistry, "cabriolet/cli/command_registry"
  end
end
