# frozen_string_literal: true

# Centralized fixture registry
#
# Provides access to test fixture files for all supported formats.
# This is the single entry point for accessing test fixtures in the test suite.

require_relative "fixtures/cab_fixtures"
require_relative "fixtures/chm_fixtures"
require_relative "fixtures/szdd_fixtures"
require_relative "fixtures/kwaj_fixtures"
require_relative "fixtures/hlp_fixtures"
require_relative "fixtures/lit_fixtures"
require_relative "fixtures/oab_fixtures"

# Fixtures module provides centralized access to format-specific fixture files
#
# @example Get all CAB fixtures
#   Fixtures.for(:cab).all_files
#
# @example Get specific CHM fixture
#   Fixtures.for(:chm).path("documentation")
#
# @example Get edge case fixture
#   Fixtures.for(:cab).edge_case(:corrupted)
module Fixtures
  # Explicit format-to-fixture mapping
  FORMATS = {
    cab: CabFixtures,
    chm: ChmFixtures,
    szdd: SzddFixtures,
    kwaj: KwajFixtures,
    hlp: HlpFixtures,
    lit: LitFixtures,
    oab: OabFixtures
  }.freeze

  # Get fixture accessor for a specific format
  #
  # @param format [Symbol] Format identifier (:cab, :chm, :szdd, :kwaj, :hlp, :lit, :oab)
  # @return [Class] Fixture module for the format
  # @raise [ArgumentError] if format is not supported
  def self.for(format)
    fixture_class = FORMATS[format]
    raise ArgumentError, "Unknown format: #{format}. Supported: #{FORMATS.keys.join(', ')}" unless fixture_class
    fixture_class
  end

  # Get all fixture classes
  #
  # @return [Array<Class>] All fixture modules
  def self.all
    FORMATS.values
  end

  # Get list of supported formats
  #
  # @return [Array<Symbol>] List of format identifiers
  def self.supported_formats
    FORMATS.keys
  end
end
