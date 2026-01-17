# frozen_string_literal: true

module Cabriolet
  module LIT
    # Generates GUIDs for LIT files
    class GuidGenerator
      # Generate a random GUID
      #
      # @return [String] 16-byte random GUID
      def self.generate
        require "securerandom"
        SecureRandom.random_bytes(16)
      end
    end
  end
end
