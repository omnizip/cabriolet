# TODO 14: Add FormatDetector spec

## Priority: P1 (core module, 162 lines, no spec)

## Problem
FormatDetector is the entry point for format detection — used by Cabriolet.open,
Cabriolet.extract, Cabriolet.info, the Validator, the Streaming module, and the
Repairer. It has zero spec coverage.

## Solution
Add spec/format_detector_spec.rb covering:
- Magic byte detection for each format (CAB, CHM, SZDD, KWAJ, HLP, LIT, OAB)
- Extension fallback
- parser_for and format_to_parser
- register_parser (plugin registration)
- detect_from_io

## Verification
- bundle exec rspec spec/format_detector_spec.rb passes
