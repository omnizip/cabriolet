# frozen_string_literal: true

# OAB format fixture definitions
#
# Provides access to OAB (Offline Address Book) test files.

module OabFixtures
  FIXTURES_BASE = File.expand_path(File.join(__dir__, "../../fixtures"))

  # OAB test files
  FILES = {
    simple: "oab/test_simple.oab",
    large: "oab/test_large.oab",
  }.freeze

  # Get absolute path to a named fixture
  #
  # @param name [Symbol, String] Fixture name
  # @return [String] Absolute path to the fixture file
  # @raise [ArgumentError] if fixture name is not found
  def self.path(name)
    name_sym = name.to_sym
    unless FILES.key?(name_sym)
      raise ArgumentError,
            "Unknown OAB fixture: #{name}. Available: #{FILES.keys.sort.join(', ')}"
    end

    File.join(FIXTURES_BASE, FILES[name_sym])
  end

  # Get all fixture file paths
  #
  # @return [Array<String>] Absolute paths to all fixtures
  def self.all_files
    FILES.values.map { |f| File.join(FIXTURES_BASE, f) }
  end

  # Get fixtures for a specific test scenario
  #
  # @param scenario [Symbol] Test scenario (:basic, :large, :all)
  # @return [Array<String>] Relevant fixture paths for the scenario
  def self.scenario(scenario)
    case scenario
    when :basic
      [path(:simple)]
    when :large
      [path(:large)]
    when :all
      all_files
    else
      raise ArgumentError, "Unknown scenario: #{scenario}"
    end
  end
end
