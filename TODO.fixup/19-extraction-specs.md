# TODO 19: Add extraction module specs

## Priority: P1

## Problem
extraction/extractor.rb (169 lines) and extraction/file_operations.rb (60 lines)
have no direct spec coverage.

## Solution
- spec/extraction/extractor_spec.rb: test parallel extraction, stats, overwrite behavior
- spec/extraction/file_operations_spec.rb: test build_output_path, normalize_filename,
  preserve_file_attributes, ensure_parent_dir, write_file
