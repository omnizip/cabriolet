# Comprehensive Testing and Documentation Design

**Date:** 2025-01-13
**Status:** Approved
**Author:** Design Workshop

## Overview

This document describes the design for comprehensive testing and documentation coverage across all Cabriolet formats (CAB, CHM, SZDD, KWAJ, HLP, LIT, OAB) for both API and CLI, using real fixture files.

## Goals

1. Test all 7 formats comprehensively across API and CLI
2. Use real fixture files from `spec/fixtures/` for testing
3. Ensure all code examples in documentation work with actual fixtures
4. Create testing documentation showing how to test each format
5. Identify and fix any implementation gaps discovered during testing

## Architecture

### Three-Layer Testing Approach

```
┌─────────────────────────────────────┐
│         CLI Tests                   │
│  (spec/cli/*_command_spec.rb)      │
│  Test CLI commands with fixtures    │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│       Integration Tests             │
│  (spec/{format}/integration_spec.rb)│
│  Test full workflows with fixtures  │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│         Unit Tests                  │
│  (spec/{format}/*_spec.rb)          │
│  Test components in isolation       │
└─────────────────────────────────────┘
```

### Test Data Flow

```
spec/fixtures/
├── {format}/              # Real files for integration tests
│   ├── basic.{ext}        # Simple case
│   ├── complex.{ext}      # Multiple files/compression
│   └── edge-cases/        # Malformed, empty, etc.
└── office_automation_dev/ # Official MS files (CHM)
```

For each format fixture:
1. Parse → Validate header, file count, sections
2. Extract → Verify file contents match expected
3. CLI list → Verify output shows file listing
4. CLI extract → Verify files created in output dir
5. CLI info → Verify metadata displayed
6. Doc examples → Run example code → Verify output

## Components

### 1. Fixture Registry

**`spec/support/fixtures.rb`** - Main fixture access point

```ruby
module Fixtures
  require_relative 'fixtures/chm_fixtures'
  require_relative 'fixtures/cab_fixtures'
  require_relative 'fixtures/szdd_fixtures'
  require_relative 'fixtures/kwaj_fixtures'
  require_relative 'fixtures/hlp_fixtures'
  require_relative 'fixtures/lit_fixtures'
  require_relative 'fixtures/oab_fixtures'

  # Explicit format-to-fixture mapping
  FORMATS = {
    chm: ChmFixtures,
    cab: CabFixtures,
    szdd: SzddFixtures,
    kwaj: KwajFixtures,
    hlp: HlpFixtures,
    lit: LitFixtures,
    oab: OabFixtures
  }.freeze

  def self.for(format)
    fixture_class = FORMATS[format]
    raise ArgumentError, "Unknown format: #{format}" unless fixture_class
    fixture_class
  end

  def self.all
    FORMATS.values
  end
end
```

**`spec/support/fixtures/{format}_fixtures.rb`** - Format-specific fixture access

```ruby
module CabFixtures
  FIXTURES_BASE = File.join(__dir__, "../../fixtures")

  FILES = {
    basic: "libmspack/cabd/normal_2files_1folder.cab",
    multi_folder: "libmspack/cabd/multi_basic_pt1.cab",
    compressed: "libmspack/cabd/mszip_lzx_qtm.cab",
  }.freeze

  EDGE_CASES = {
    empty: "edge_cases/empty.cab",
    corrupted: "libmspack/cabd/CVE-2018-18363.cab",
  }.freeze

  def self.path(name)
    File.join(FIXTURES_BASE, FILES[name] || EDGE_CASES[name])
  end

  def self.all_files
    FILES.values.map { |f| File.join(FIXTURES_BASE, f) }
  end
end
```

### 2. Shared Test Helpers

**`spec/support/format_test_helper.rb`** - Common test scenarios

```ruby
module FormatTestHelper
  def test_list_command(format, fixture)
    cli = Cabriolet::CLI.new
    expect { cli.list(fixture) }.not_to raise_error
  end

  def test_extract_command(format, fixture)
    cli = Cabriolet::CLI.new
    Dir.mktmpdir do |output_dir|
      cli.extract(fixture, output_dir)
      extracted = Dir.glob("#{output_dir}/**/*").select { |f| File.file?(f) }
      expect(extracted.length).to be > 0
    end
  end

  # ... more helper methods
end
```

**`spec/support/edge_case_examples.rb`** - Shared edge case behavior

```ruby
RSpec.shared_examples "edge case handling" do |format|
  context "with non-existent file" do
    it "API raises IOError" do
      expect { parser.parse("/nonexistent.#{format}") }
        .to raise_error(Cabriolet::IOError)
    end

    it "CLI exits with error" do
      expect { cli.list("/nonexistent.#{format}") }
        .to raise_error(SystemExit)
    end
  end

  context "with empty file" do
    let(:fixture) { Fixtures.for(format).edge_case(:empty) }

    it "API raises ParseError" do
      expect { parser.parse(fixture) }
        .to raise_error(Cabriolet::ParseError, /empty|invalid/i)
    end
  end
end
```

### 3. DRY Test Pattern

Use `let`, `context`, `describe`, `subject`, `its` to eliminate repetition:

```ruby
RSpec.describe Cabriolet::CAB::Parser do
  let(:parser) { described_class.new }

  describe "#parse" do
    subject(:parsed) { parser.parse(fixture) }

    context "with basic cabinet" do
      let(:fixture) { Fixtures.for(:cab).path(:basic) }

      it { expect { parsed }.not_to raise_error }
      its(:file_count) { is_expected.to eq(2) }
      its(:folder_count) { is_expected.to eq(1) }

      describe "file entries" do
        subject(:files) { parsed.files }
        it { is_expected.to all(be_a(Cabriolet::Models::File)) }
      end
    end

    context "with compressed cabinet" do
      let(:fixture) { Fixtures.for(:cab).path(:compressed) }

      describe "compression" do
        subject(:folders) { parsed.folders }
        it { is_expected.to all(have_attributes(compression_type: be_in([:mszip, :lzx, :quantum]))) }
      end
    end
  end
end
```

### 4. Meaningful CLI Tests

Test actual outcomes, not just "no errors":

```ruby
RSpec.describe "cab CLI commands" do
  let(:cli) { Cabriolet::CLI.new }
  let(:basic_cab) { Fixtures.for(:cab).path(:basic) }

  describe "#extract" do
    it "extracts all files from cabinet to output directory" do
      Dir.mktmpdir do |output_dir|
        cli.extract(basic_cab, output_dir)

        extracted_files = Dir.glob("#{output_dir}/**/*").select { |f| File.file?(f) }
        expect(extracted_files.length).to eq(2)
        expect(File.read(extracted_files.first)).to start_with("MZ")
      end
    end

    it "creates subdirectories matching folder structure" do
      multi_folder = Fixtures.for(:cab).path(:multi_folder)

      Dir.mktmpdir do |output_dir|
        cli.extract(multi_folder, output_dir)
        directories = Dir.glob("#{output_dir}/**/*/").select { |d| File.directory?(d) }
        expect(directories.length).to be > 1
      end
    end
  end

  describe "#create" do
    it "creates a valid cabinet that can be parsed back" do
      Dir.mktmpdir do |dir|
        test_file = File.join(dir, "test.txt")
        File.write(test_file, "test content")

        output = File.join(dir, "test.cab")
        cli.create(output, test_file)

        parser = Cabriolet::CAB::Parser.new
        cabinet = parser.parse(output)
        expect(cabinet.file_count).to eq(1)
        expect(cabinet.files.first.name).to eq("test.txt")
      end
    end

    it "applies specified compression type" do
      Dir.mktmpdir do |dir|
        test_file = File.join(dir, "test.txt")
        File.write(test_file, "x" * 1000)

        output = File.join(dir, "compressed.cab")
        cli.create(output, test_file, compression: "mszip")

        parser = Cabriolet::CAB::Parser.new
        cabinet = parser.parse(output)
        expect(cabinet.folders.first.compression_type).to eq(:mszip)
      end
    end
  end
end
```

## Documentation

### New Testing Guide

**`docs/developer/testing/comprehensive-testing.adoc`**

```asciidoc
[[comprehensive-testing]]
= Comprehensive Testing Guide

This guide covers how Cabriolet tests all supported formats with real fixture files.

[[testing-architecture]]
== Testing Architecture

Cabriolet uses a three-layer testing approach:

. *Unit Tests* - Test individual components (Parser, Compressor, Decompressor)
. *Integration Tests* - Test full workflows with real fixtures
. *CLI Tests* - Test command-line interface behavior

[[testing-fixtures]]
== Test Fixtures

Fixtures are organized by format in `spec/fixtures/` and accessed via the `Fixtures` module:

[source,ruby]
----
# Get all fixtures for a format
files = Fixtures.for(:cab).all_files

# Get specific fixture
basic_cab = Fixtures.for(:cab).path(:basic)

# Get edge case fixtures
corrupted = Fixtures.for(:cab).edge_case(:corrupted)
----

[[testing-formats]]
== Testing Each Format

=== CAB Format

.Basic cabinet test
[source,ruby]
----
parser = Cabriolet::CAB::Parser.new
cabinet = parser.parse(Fixtures.for(:cab).path(:basic))
expect(cabinet.file_count).to eq(2)
----

.Extract cabinet via CLI
[source,ruby]
----
cli = Cabriolet::CLI.new
cli.extract("basic.cab", "/tmp/output")
# Verify files created
----

=== CHM Format

.Parse CHM file
[source,ruby]
----
parser = Cabriolet::CHM::Parser.new
chm = parser.parse(Fixtures.for(:chm).path("documentation"))
expect(chm.file_count).to be > 0
----

[[testing-edge-cases]]
== Edge Case Testing

Each format includes edge case tests for:

* Empty files
* Corrupted headers
* Wrong format signatures
* Multi-part archives

[[running-tests]]
== Running Tests

.Run all tests
----
bundle exec rspec
----

.Run specific format
----
bundle exec rspec spec/cab
----

.Run with verbose output
----
bundle exec rspec --format documentation
----
```

### Documentation Verification

**`spec/support/doc_verifier.rb`**

```ruby
module DocVerifier
  # Extract code blocks from AsciiDoc files
  def self.extract_examples(doc_path)
    content = File.read(doc_path)
    content.scan(/\[source,ruby\].*?----(.*?)----/m).flatten
  end

  # Verify an example works with fixtures
  def self.verify_example(code, format)
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        eval(code)
      end
    end
  rescue => e
    { status: :failed, error: e.message }
  end

  # Run all examples from a doc file
  def self.verify_doc(doc_path)
    examples = extract_examples(doc_path)
    results = examples.map { |code| verify_example(code, format) }
    generate_report(doc_path, results)
  end
end
```

**Rake task** `rake docs:verify`:

```ruby
namespace :docs do
  desc "Verify all code examples in documentation"
  task verify: :environment do
    Dir["docs/**/*.adoc"].each do |doc|
      puts "Verifying #{doc}..."
      DocVerifier.verify_doc(doc)
    end
  end
end
```

## Implementation Plan

### Phase 1: Infrastructure + CAB Template

1. Create `spec/support/fixtures.rb` infrastructure
2. Create `spec/support/fixtures/cab_fixtures.rb`
3. Create `spec/support/format_test_helper.rb`
4. Create `spec/support/edge_case_examples.rb`
5. Enhance `spec/cab/parser_spec.rb` with fixture-based tests
6. Enhance `spec/cab/compressor_spec.rb` with fixture-based tests
7. Enhance `spec/cab/decompressor_spec.rb` with fixture-based tests
8. Create `spec/cli/cab_command_spec.rb`
9. Create `docs/developer/testing/comprehensive-testing.adoc`

### Phase 2: Apply to Mature Formats

Apply CAB template to:
- CHM
- HLP
- LIT

### Phase 3: Apply to Simpler Formats

Apply template to:
- SZDD
- KWAJ
- OAB

### Phase 4: Documentation Verification

1. Run `rake docs:verify` on all documentation
2. Mark working examples with ✓
3. Mark pending examples with ○
4. Fix or remove broken examples

## File Structure

```
spec/
├── support/
│   ├── fixtures.rb                    # NEW: Main fixture registry
│   ├── fixtures/
│   │   ├── cab_fixtures.rb            # NEW: CAB fixture access
│   │   ├── chm_fixtures.rb            # NEW: CHM fixture access (already exists as fixture_chm.rb)
│   │   ├── szdd_fixtures.rb           # NEW: SZDD fixture access
│   │   ├── kwaj_fixtures.rb           # NEW: KWAJ fixture access
│   │   ├── hlp_fixtures.rb            # NEW: HLP fixture access
│   │   ├── lit_fixtures.rb            # NEW: LIT fixture access
│   │   └── oab_fixtures.rb            # NEW: OAB fixture access
│   ├── format_test_helper.rb          # NEW: Shared test helpers
│   └── edge_case_examples.rb          # NEW: Shared edge case tests
├── cab/
│   ├── parser_spec.rb                 # ENHANCE: With fixture-based tests
│   ├── compressor_spec.rb             # ENHANCE: With fixture-based tests
│   ├── decompressor_spec.rb           # ENHANCE: With fixture-based tests
│   ├── integration_spec.rb            # KEEP: As-is
│   ├── cli_spec.rb                    # NEW: Full CLI command tests
│   └── edge_cases_spec.rb             # NEW: Edge case scenarios
├── cli/
│   ├── cab_command_spec.rb            # NEW: CAB-specific CLI tests
│   └── {format}_command_spec.rb       # NEW: For each format
└── {format}/                           # Existing tests, enhance with fixtures
```

## Success Criteria

1. All 7 formats have comprehensive API tests using real fixtures
2. All 7 formats have comprehensive CLI tests verifying actual behavior
3. All edge cases are tested consistently across formats
4. All code examples in documentation are verified and marked
5. New testing guide documents the approach
6. No implementation gaps remain (or are documented)

## Open Questions

None - design is approved and ready to implement.
