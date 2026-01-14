# frozen_string_literal: true

# CHM format fixture definitions
#
# Provides access to CHM test fixture files including real-world documentation,
# security test cases, and official Microsoft Office VBA documentation.

module ChmFixtures
  FIXTURES_BASE = File.expand_path(File.join(__dir__, "../../fixtures"))

  # Real-world CHM documentation files
  FILES = {
    # Using available libmspack test files as basic fixtures
    encints_64bit_both: "libmspack/chmd/encints-64bit-both.chm",
    encints_32bit_both: "libmspack/chmd/encints-32bit-both.chm",
  }.freeze

  # Security and edge case test files from libmspack
  EDGE_CASES = {
    # CVE security test files
    cve_2015_4468: "libmspack/chmd/cve-2015-4468-namelen-bounds.chm",
    cve_2015_4469: "libmspack/chmd/cve-2015-4469-namelen-bounds.chm",
    cve_2015_4472: "libmspack/chmd/cve-2015-4472-namelen-bounds.chm",
    cve_2017_6419: "libmspack/chmd/cve-2017-6419-lzx-negative-spaninfo.chm",
    cve_2018_14679: "libmspack/chmd/cve-2018-14679-off-by-one.chm",
    cve_2018_14680: "libmspack/chmd/cve-2018-14680-blank-filenames.chm",
    cve_2018_14682: "libmspack/chmd/cve-2018-14682-unicode-u100.chm",
    cve_2018_18585: "libmspack/chmd/cve-2018-18585-blank-filenames.chm",
    cve_2019_1010305: "libmspack/chmd/cve-2019-1010305-name-overread.chm",

    # Encoding tests (32-bit vs 64-bit integer encoding)
    encints_32bit_lengths: "libmspack/chmd/encints-32bit-lengths.chm",
    encints_32bit_offsets: "libmspack/chmd/encints-32bit-offsets.chm",
    encints_32bit_both: "libmspack/chmd/encints-32bit-both.chm",
    encints_64bit_lengths: "libmspack/chmd/encints-64bit-lengths.chm",
    encints_64bit_offsets: "libmspack/chmd/encints-64bit-offsets.chm",
    encints_64bit_both: "libmspack/chmd/encints-64bit-both.chm",
  }.freeze

  # Get absolute path to a named fixture
  #
  # @param name [Symbol, String] Fixture name from FILES or EDGE_CASES
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
            "Unknown CHM fixture: #{name}. Available: #{(FILES.keys + EDGE_CASES.keys).sort.join(', ')}"
    end
  end

  # Get all standard fixture file paths
  #
  # @return [Array<String>] Absolute paths to all standard fixtures
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
  # @param scenario [Symbol] Test scenario (:basic, :edge_cases, :encoding, :cve)
  # @return [Array<String>] Relevant fixture paths for the scenario
  def self.scenario(scenario)
    case scenario
    when :basic
      [path(:encints_64bit_both), path(:encints_32bit_both)]
    when :edge_cases
      EDGE_CASES.values.select { |f| f.include?("cve") }
        .map { |f| File.join(FIXTURES_BASE, f) }
    when :encoding
      EDGE_CASES.values.select { |f| f.include?("encints") }
        .map { |f| File.join(FIXTURES_BASE, f) }
    when :cve
      EDGE_CASES.values.select { |f| f.include?("cve") }
        .map { |f| File.join(FIXTURES_BASE, f) }
    else
      raise ArgumentError, "Unknown scenario: #{scenario}"
    end
  end
end
