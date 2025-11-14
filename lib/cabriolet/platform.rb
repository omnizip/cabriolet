# frozen_string_literal: true

module Cabriolet
  # Platform detection for handling OS-specific behavior
  module Platform
    # Check if running on Windows
    #
    # @return [Boolean] true if on Windows (including MinGW, Cygwin)
    def self.windows?
      RUBY_PLATFORM =~ /mswin|mingw|cygwin/
    end

    # Check if running on Unix-like system
    #
    # @return [Boolean] true if on Unix (Linux, macOS, BSD, etc.)
    def self.unix?
      !windows?
    end

    # Check if platform supports Unix file permissions
    #
    # @return [Boolean] true if platform supports chmod with Unix permission bits
    def self.supports_unix_permissions?
      unix?
    end
  end
end
