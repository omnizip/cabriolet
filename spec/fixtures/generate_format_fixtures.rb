#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to generate test fixtures for HLP, LIT, and OAB formats
# Run from project root: bundle exec ruby spec/fixtures/generate_format_fixtures.rb

require_relative "../../lib/cabriolet"

# Create fixtures directory
fixtures_dir = File.expand_path(__dir__)
FileUtils.mkdir_p(File.join(fixtures_dir, "hlp"))
FileUtils.mkdir_p(File.join(fixtures_dir, "lit"))
FileUtils.mkdir_p(File.join(fixtures_dir, "oab"))

# Test data
simple_data = "Hello, World! This is a test file.\n"
multiline_data = "Line 1: Test data\nLine 2: More test data\nLine 3: Even more data\n" * 10

begin
  # Generate HLP fixture

  hlp_file = File.join(fixtures_dir, "hlp", "test_simple.hlp")
  hlp_compressor = Cabriolet::HLP::Compressor.new
  hlp_compressor.add_data(simple_data, "test.txt", compress: false)
  hlp_compressor.generate(hlp_file)

  hlp_file2 = File.join(fixtures_dir, "hlp", "test_compressed.hlp")
  hlp_compressor2 = Cabriolet::HLP::Compressor.new
  hlp_compressor2.add_data(multiline_data, "compressed.txt", compress: true)
  hlp_compressor2.generate(hlp_file2)

  hlp_multi = File.join(fixtures_dir, "hlp", "test_multi.hlp")
  hlp_compressor3 = Cabriolet::HLP::Compressor.new
  hlp_compressor3.add_data("File 1 content\n", "file1.txt", compress: false)
  hlp_compressor3.add_data("File 2 content " * 20, "file2.txt", compress: true)
  hlp_compressor3.add_data("File 3 content\n", "file3.txt", compress: false)
  hlp_compressor3.generate(hlp_multi)
rescue StandardError
end

begin
  # Generate LIT fixtures

  # Create temporary source file
  temp_source = File.join(fixtures_dir, "lit", "temp_source.txt")
  File.write(temp_source, simple_data)

  lit_file = File.join(fixtures_dir, "lit", "test_simple.lit")
  lit_compressor = Cabriolet::LIT::Compressor.new
  lit_compressor.add_file(temp_source, "test.txt", compress: false)
  lit_compressor.generate(lit_file)

  # Multi-file LIT
  temp_source2 = File.join(fixtures_dir, "lit", "temp_source2.txt")
  File.write(temp_source2, multiline_data)

  lit_multi = File.join(fixtures_dir, "lit", "test_multi.lit")
  lit_compressor2 = Cabriolet::LIT::Compressor.new
  lit_compressor2.add_file(temp_source, "file1.txt", compress: false)
  lit_compressor2.add_file(temp_source2, "file2.txt", compress: false)
  lit_compressor2.generate(lit_multi)

  # Clean up temp files
  FileUtils.rm_f(temp_source)
  FileUtils.rm_f(temp_source2)
rescue StandardError
end

begin
  # Generate OAB fixtures

  # Create temporary source file
  temp_data = File.join(fixtures_dir, "oab", "temp_data.dat")
  File.write(temp_data, simple_data)

  oab_file = File.join(fixtures_dir, "oab", "test_simple.oab")
  oab_compressor = Cabriolet::OAB::Compressor.new
  oab_compressor.compress(temp_data, oab_file)

  # Larger OAB file
  large_data = File.join(fixtures_dir, "oab", "temp_large.dat")
  File.write(large_data, multiline_data * 10)

  oab_large = File.join(fixtures_dir, "oab", "test_large.oab")
  oab_compressor2 = Cabriolet::OAB::Compressor.new
  oab_compressor2.compress(large_data, oab_large)

  # Clean up temp files
  FileUtils.rm_f(temp_data)
  FileUtils.rm_f(large_data)
rescue StandardError
end
