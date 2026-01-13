# frozen_string_literal: true

# SZDD format fixture definitions
#
# Provides access to SZDD-compressed executables from Windows 95/98 era software.

module SzddFixtures
  FIXTURES_BASE = File.expand_path(File.join(__dir__, "../../../fixtures"))

  # SZDD-compressed files from MUANGL20 (M.U.A.N.G.E.L.O game)
  MUANGL20 = {
    # Sample SZDD files from MUANGL20 directory
    muan_inst: "MUANGL20/MAUNINST.EX_",
  }.freeze

  # SZDD-compressed files from TBWNT807 (TurboBrowser Watch)
  TBWNT807 = {
    uninstall: "TBWNT807/UNINSTAL.EX_",
    setup: "TBWNT807/_SETUPNT.EX_",
    key: "TBWNT807/TBKEYW32.EX_",
    load: "TBWNT807/TBLOAD32.EX_",
    avw: "TBWNT807/TBAVW32.EX_",
  }.freeze

  # All SZDD fixtures combined
  FILES = MUANGL20.merge(TBWNT807).freeze

  # Get absolute path to a named fixture
  #
  # @param name [Symbol, String] Fixture name
  # @return [String] Absolute path to the fixture file
  # @raise [ArgumentError] if fixture name is not found
  def self.path(name)
    name_sym = name.to_sym
    unless FILES.key?(name_sym)
      raise ArgumentError,
            "Unknown SZDD fixture: #{name}. Available: #{FILES.keys.sort.join(', ')}"
    end

    File.join(FIXTURES_BASE, FILES[name_sym])
  end

  # Get all fixture file paths
  #
  # @return [Array<String>] Absolute paths to all fixtures
  def self.all_files
    FILES.values.map { |f| File.join(FIXTURES_BASE, f) }
  end

  # Get fixtures from MUANGL20
  #
  # @return [Array<String>] Paths to MUANGL20 fixtures
  def self.muangl20_files
    MUANGL20.values.map { |f| File.join(FIXTURES_BASE, f) }
  end

  # Get fixtures from TBWNT807
  #
  # @return [Array<String>] Paths to TBWNT807 fixtures
  def self.tbwnt807_files
    TBWNT807.values.map { |f| File.join(FIXTURES_BASE, f) }
  end

  # Get fixtures for a specific test scenario
  #
  # @param scenario [Symbol] Test scenario (:muangl20, :tbwnt807, :all)
  # @return [Array<String>] Relevant fixture paths for the scenario
  def self.scenario(scenario)
    case scenario
    when :muangl20
      muangl20_files
    when :tbwnt807
      tbwnt807_files
    when :all
      all_files
    else
      raise ArgumentError, "Unknown scenario: #{scenario}"
    end
  end
end
