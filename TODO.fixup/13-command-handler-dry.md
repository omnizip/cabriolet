# TODO 13: DRY — Command handler template method pattern

## Priority: P1 (DRY violation, ~1650 lines across 7 handlers)

## Problem
All 7 format command handlers (CAB, CHM, SZDD, KWAJ, HLP, LIT, OAB) have
identical method signatures and very similar implementations for test, info,
list. Each reimplements: validate_file_exists → open decompressor → display →
close. The base class only raises NotImplementedError.

## Solution
Extract common patterns to BaseCommandHandler using Template Method:
1. `test(file, options)` — runs Validator + calls `display_test_info` hook
2. `info(file, options)` — opens archive + calls `display_info` hook
3. `list(file, options)` — opens archive + calls `display_files` hook
Each subclass overrides the display hooks with format-specific output.

## Verification
- Handler line counts decrease significantly
- All CLI command specs pass
