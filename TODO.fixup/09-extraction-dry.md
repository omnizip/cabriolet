# TODO 09: DRY — Extract shared extraction attribute preservation

## Priority: P1 (DRY violation)

## Problem
`preserve_file_attributes` is duplicated verbatim in two files:
- `lib/cabriolet/extraction/base_extractor.rb:79-84`
- `lib/cabriolet/extraction/file_extraction_worker.rb:81-86`

Both contain the exact same logic for preserving file timestamps after
extraction. Changes to one must be manually mirrored in the other.

## Solution
Extract the method into a shared module `Extraction::AttributePreservation`
that both classes include. The method uses `file.datetime` which all file
models now provide.

## Verification
- `diff` between the two implementations shows zero differences after refactor
- Extraction specs pass
