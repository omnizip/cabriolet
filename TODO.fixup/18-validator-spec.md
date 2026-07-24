# TODO 18: Add Validator spec

## Priority: P1 (323-line critical module, zero direct spec coverage)

## Problem
Validator is used by all command handler test methods and the Cabriolet.info API.
Its validation levels (quick, standard, thorough), error reporting, and report
serialization are entirely untested.

## Solution
Add spec/validator_spec.rb covering:
- LEVEL_QUICK: file existence, readability, magic bytes
- LEVEL_STANDARD: structure validation, checksums
- LEVEL_THOROUGH: decompression validation
- ValidationReport: valid?, errors, warnings, to_h, to_json, text report
- Error handling for invalid files
