# TODO 10: OCP — FormatDetector registry pattern

## Priority: P1 (Open/Closed Principle violation)

## Problem
`FormatDetector.format_to_parser` uses a `case` statement with hardcoded
format→parser mappings. Adding a new format requires modifying this method,
violating OCP. The same pattern exists in `validate_format`.

## Solution
1. Replace `format_to_parser` switch with a `PARSER_REGISTRY` hash mapping
   format symbols to fully-qualified class name strings.
2. Use `const_get` to resolve classes lazily (triggers autoload chain).
3. Add `register_parser(format, klass)` for runtime plugin registration.
4. `format_to_parser` checks runtime registry first, then falls back to
   built-in registry.

## Verification
- All format detection specs pass
- New format can be registered without modifying FormatDetector
