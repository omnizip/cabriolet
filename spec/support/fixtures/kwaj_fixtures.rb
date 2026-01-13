# frozen_string_literal: true

# KWAJ format fixture definitions
#
# Provides access to KWAJ-compressed test files from libmspack test suite.

module KwajFixtures
  FIXTURES_BASE = File.expand_path(File.join(__dir__, "../../fixtures"))

  # Libmspack KWAJ test files
  # Files are organized as f00-f04, f10-f14, f20-f24, etc.
  # Note: f04, f11 have malformed headers that cause ParseError (edge cases)
  FILES = {
    # Basic test files
    f00: "libmspack/kwajd/f00.kwj",
    f01: "libmspack/kwajd/f01.kwj",
    f02: "libmspack/kwajd/f02.kwj",
    f03: "libmspack/kwajd/f03.kwj",
    f10: "libmspack/kwajd/f10.kwj",
    f20: "libmspack/kwajd/f20.kwj",
    f30: "libmspack/kwajd/f30.kwj",
    f40: "libmspack/kwajd/f40.kwj",
  }.freeze

  # Edge case fixtures (files that cause ParseError)
  EDGE_CASES = {
    f04: "libmspack/kwajd/f04.kwj",
    f11: "libmspack/kwajd/f11.kwj",
    cve_2018_14681: "libmspack/kwajd/cve-2018-14681.kwj",
  }.freeze

  # Get absolute path to a named fixture
  #
  # @param name [Symbol, String] Fixture name
  # @return [String] Absolute path to the fixture file
  # @raise [ArgumentError] if fixture name is not found
  def self.path(name)
    name_sym = name.to_sym

    if FILES.key?(name_sym)
      File.join(FIXTURES_BASE, FILES[name_sym])
    elsif EDGE_CASES.key?(name_sym)
      File.join(FIXTURES_BASE, EDGE_CASES[name_sym])
    else
      raise ArgumentError,
            "Unknown KWAJ fixture: #{name}. Available: #{(FILES.keys + EDGE_CASES.keys).sort.join(', ')}"
    end
  end

  # Get all fixture file paths
  #
  # @return [Array<String>] Absolute paths to all fixtures
  def self.all_files
    FILES.values.map { |f| File.join(FIXTURES_BASE, f) }
  end

  # Get edge case fixture file path
  #
  # @param name [Symbol, String] Edge case fixture name
  # @return [String] Absolute path to the edge case fixture
  def self.edge_case(name)
    name_sym = name.to_sym
    unless EDGE_CASES.key?(name_sym)
      raise ArgumentError,
            "Unknown edge case: #{name}. Available: #{EDGE_CASES.keys.sort.join(', ')}"
    end

    File.join(FIXTURES_BASE, EDGE_CASES[name_sym])
  end

  # Get fixtures for a specific test scenario
  #
  # @param scenario [Symbol] Test scenario (:basic, :all)
  # @return [Array<String>] Relevant fixture paths for the scenario
  def self.scenario(scenario)
    case scenario
    when :basic
      # Use f00-f03 (first 4 files - excluding malformed f04)
      FILES.values.first(4).map { |f| File.join(FIXTURES_BASE, f) }
    when :all
      all_files
    else
      raise ArgumentError, "Unknown scenario: #{scenario}"
    end
  end
end

