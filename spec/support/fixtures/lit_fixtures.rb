# frozen_string_literal: true

# LIT format fixture definitions
#
# Provides access to LIT eBook files from Project Gutenberg.

module LitFixtures
  FIXTURES_BASE = File.expand_path(File.join(__dir__, "../../fixtures"))

  # LIT eBook files from atudl_lit directory
  FILES = {
    greek_art: "atudl_lit/A History of Greek Art.lit",
    journey_center: "atudl_lit/A Journey To The Center Of The Earth.lit",
    bill: "atudl_lit/bill.lit",
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
            "Unknown LIT fixture: #{name}. Available: #{FILES.keys.sort.join(', ')}"
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
  # @param scenario [Symbol] Test scenario (:all, :with_drm, :large)
  # @return [Array<String>] Relevant fixture paths for the scenario
  def self.scenario(scenario)
    case scenario
    when :all
      all_files
    else
      raise ArgumentError, "Unknown scenario: #{scenario}"
    end
  end
end
