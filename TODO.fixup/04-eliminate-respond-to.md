# TODO 04: Eliminate respond_to? usage

## Priority: P0 (explicit rule violation)

## Problem
~30 uses of `respond_to?` for duck-typing. This violates: "NEVER use
`respond_to?` for type checking. Use `is_a?` for type checks, or better yet,
design the type hierarchy so the check isn't needed."

`respond_to?` hides type errors until runtime and couples to method names rather
than types.

## Affected Locations

### cabriolet.rb (file_info helper)
- `:256-259` — checks `file.respond_to?(:compressed_size)`, `:attributes`, `:date`,
  `:time`
**Fix**: All file model classes should define these attributes (returning nil if
N/A). The check is there because different format models have different
attribute sets. Define a common `Models::FileEntry` interface or just ensure all
file models respond to these methods (returning nil).

### streaming.rb
- `:59` — `file.respond_to?(:stream_data)` — check before calling
- `:93, :209` — `file.respond_to?(:size)`
- `:142, :146, :150` — `attributes`, `date`, `time`
- `:175` — `respond_to_missing?` (removed with TODO 03)
**Fix**: Define explicit interface on LazyFile. For `stream_data` check, use
`is_a?(StreamingFile)` or make streaming capability part of the file interface.

### modifier.rb
- `:216-218` — `attributes`, `date`, `time` with defaults
**Fix**: Same as cabriolet.rb — ensure models provide these attributes.

### validator.rb
- `:137` — `cabinet.respond_to?(:header)`
- `:197` — `file.respond_to?(:size)`
**Fix**: Use `is_a?(Models::Cabinet)` etc.

### repairer.rb
- `:118` — `file.respond_to?(:size)`
- `:181-183` — `attributes`, `date`, `time`
**Fix**: Same pattern — use type checks or ensure interface.

### hlp/decompressor.rb
- `:50` — `@delegate&.close(header) if @delegate.respond_to?(:close)`
**Fix**: The delegate should always define `close` (as a no-op if needed), or
check `is_a?` against a known interface class.

### hlp/command_handler.rb (8 occurrences)
- `:120, 146, 189` — `header.respond_to?(:version)` — different HLP header types
  have different attribute sets
- `:123, 149, 192` — `version_value.respond_to?(:to_i)` — String vs Integer
- `:170, 208` — `header.respond_to?(:files)`
- `:204` — `header.respond_to?(:length)`
**Fix**: Unify HLP header types to always respond to `version`, `files`, `length`
(returning nil). For `to_i`, use explicit conversion: Integer(version_value)
rescue version_value, or just call `version_value.to_i` (all objects respond to
`to_i`... actually no, only numerics and strings). Better: normalize to Integer
at parse time.

## Solution
1. Ensure all file/header model classes define a consistent attribute interface
   (returning nil for N/A attributes instead of being missing methods).
2. Replace `respond_to?` with `is_a?` where the type check is genuine.
3. Remove `respond_to?` where the interface is already guaranteed.
4. In streaming.rb, eliminate method_missing delegation entirely.

## Verification
- `grep -rn "respond_to?" lib/` returns 0
- All specs pass
