# frozen_string_literal: true

# CAB format fixture definitions
#
# Provides access to CAB test fixture files for testing cabinet parsing,
# extraction, and creation functionality.

module CabFixtures
  FIXTURES_BASE = File.expand_path(File.join(__dir__, "../../fixtures"))

  # Standard cabinet fixtures for common test scenarios
  FILES = {
    # Basic cabinets
    basic: "libmspack/cabd/normal_2files_1folder.cab",
    simple: "cabextract/simple.cab",

    # Compression types
    mszip: "libmspack/cabd/mszip_lzx_qtm.cab",  # Contains MSZIP, LZX, Quantum

    # Multi-part cabinets
    multi_pt1: "libmspack/cabd/multi_basic_pt1.cab",
    multi_pt2: "libmspack/cabd/multi_basic_pt2.cab",
    multi_pt3: "libmspack/cabd/multi_basic_pt3.cab",
    multi_pt4: "libmspack/cabd/multi_basic_pt4.cab",
    multi_pt5: "libmspack/cabd/multi_basic_pt5.cab",

    # Split cabinets (from cabextract)
    split_1: "cabextract/split-1.cab",
    split_2: "cabextract/split-2.cab",
    split_3: "cabextract/split-3.cab",
    split_4: "cabextract/split-4.cab",
    split_5: "cabextract/split-5.cab",

    # Encoding tests (from cabextract)
    encoding_ascii: "cabextract/case-ascii.cab",
    encoding_utf8: "cabextract/case-utf8.cab",
    encoding_koi8: "cabextract/encoding-koi8.cab",

    # Edge case and security test files
    edge_reserved_hfd: "libmspack/cabd/reserve_HFD.cab",
    edge_reserved_3fd: "libmspack/cabd/reserve_-FD.cab",
    edge_reserved_3dash: "libmspack/cabd/reserve_---.cab",
  }.freeze

  # Edge case fixtures for testing error handling
  EDGE_CASES = {
    # Invalid signatures
    bad_signature: "libmspack/cabd/bad_signature.cab",

    # Invalid structure
    bad_no_folders: "libmspack/cabd/bad_nofolders.cab",

    # Security vulnerability test cases (CVE)
    cve_2015_4471: "libmspack/cabd/cve-2015-4471-lzx-under-read.cab",
    cve_2017_11423: "libmspack/cabd/cve-2017-11423-fname-overread.cab",

    # Partial/incomplete files
    partial_shortfolder: "libmspack/cabd/partial_shortfolder.cab",
    partial_nofolder: "libmspack/cabd/partial_nofolder.cab",
    partial_shortextheader: "libmspack/cabd/partial_shortextheader.cab",
    partial_shortheader: "libmspack/cabd/partial_shortheader.cab",
    partial_nodata: "libmspack/cabd/partial_nodata.cab",
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
            "Unknown CAB fixture: #{name}. Available: #{(FILES.keys + EDGE_CASES.keys).sort.join(', ')}"
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
  # @param scenario [Symbol] Test scenario (:basic, :compression, :multi, :encoding, :edge_cases)
  # @return [Array<String>] Relevant fixture paths for the scenario
  def self.scenario(scenario)
    case scenario
    when :basic
      [path(:basic), path(:simple)]
    when :compression
      [path(:mszip)]
    when :multi
      [path(:multi_pt1), path(:multi_pt2), path(:multi_pt3), path(:multi_pt4), path(:multi_pt5)]
    when :encoding
      [path(:encoding_ascii), path(:encoding_utf8), path(:encoding_koi8)]
    when :split
      [path(:split_1), path(:split_2), path(:split_3), path(:split_4), path(:split_5)]
    when :edge_cases
      EDGE_CASES.values.map { |f| File.join(FIXTURES_BASE, f) }
    else
      raise ArgumentError, "Unknown scenario: #{scenario}"
    end
  end
end
