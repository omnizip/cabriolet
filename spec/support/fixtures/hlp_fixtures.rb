# frozen_string_literal: true

# HLP format fixture definitions
#
# Provides access to HLP test fixture files including QuickHelp and WinHelp formats.

module HlpFixtures
  FIXTURES_BASE = File.expand_path(File.join(__dir__, "../../fixtures"))

  # WinHelp format files (WinHelp 4.x)
  # Note: QuickHelp fixtures not available, using WinHelp only
  WINHELP = {
    masmlib: "masm32_hlp/MASMLIB.HLP",
    qeditor: "masm32_hlp/QEDITOR.HLP",
    se: "masm32_hlp/SE.HLP",
  }.freeze

  # All HLP fixtures (using available WinHelp files)
  FILES = WINHELP.freeze

  # Get absolute path to a named fixture
  #
  # @param name [Symbol, String] Fixture name
  # @return [String] Absolute path to the fixture file
  # @raise [ArgumentError] if fixture name is not found
  def self.path(name)
    name_sym = name.to_sym
    unless FILES.key?(name_sym)
      raise ArgumentError,
            "Unknown HLP fixture: #{name}. Available: #{FILES.keys.sort.join(', ')}"
    end

    File.join(FIXTURES_BASE, FILES[name_sym])
  end

  # Get all fixture file paths
  #
  # @return [Array<String>] Absolute paths to all fixtures
  def self.all_files
    FILES.values.map { |f| File.join(FIXTURES_BASE, f) }
  end

  # Get WinHelp format fixtures
  #
  # @return [Array<String>] Paths to WinHelp fixtures
  def self.winhelp_files
    WINHELP.values.map { |f| File.join(FIXTURES_BASE, f) }
  end

  # Get fixtures for a specific test scenario
  #
  # @param scenario [Symbol] Test scenario (:winhelp, :all)
  # @return [Array<String>] Relevant fixture paths for the scenario
  def self.scenario(scenario)
    case scenario
    when :winhelp
      winhelp_files
    when :all
      all_files
    else
      raise ArgumentError,
            "Unknown scenario: #{scenario}. Available: :winhelp, :all"
    end
  end
end
