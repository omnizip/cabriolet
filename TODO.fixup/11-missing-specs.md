# TODO 11: Add specs for untested modules

## Priority: P1 (test coverage gap)

## Problem
Three significant modules have zero spec coverage:
- `lib/cabriolet/streaming.rb` (213 lines) — streaming extraction API
- `lib/cabriolet/modifier.rb` (325 lines) — archive modification
- `lib/cabriolet/repairer.rb` (287 lines) — corrupted archive repair

## Solution
Add spec files for each:
- `spec/streaming_spec.rb` — test StreamParser, LazyFile, BatchProcessor
- `spec/modifier_spec.rb` — test Modifier operations on each format
- `spec/repairer_spec.rb` — test Repairer with valid and corrupted archives

## Verification
- `bundle exec rspec spec/streaming_spec.rb spec/modifier_spec.rb spec/repairer_spec.rb` passes
