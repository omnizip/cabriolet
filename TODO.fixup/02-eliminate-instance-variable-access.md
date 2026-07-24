# TODO 02: Eliminate instance_variable_set/get in lib code

## Priority: P0 (explicit rule violation)

## Problem
The codebase uses `instance_variable_set` and `instance_variable_get` to reach
into other objects' internal state. This breaks encapsulation and violates the
project rule: "NEVER use `instance_variable_set` or `instance_variable_get`.
Accessing another object's instance variables breaks encapsulation."

## Affected Locations (lib)

### lit/decompressor.rb
- `:47` — `lit_file.instance_variable_set(:@filename, filename)` — sets filename
  on parsed LITFile model without an accessor
- `:304` — `lit_file.instance_variable_get(:@filename)` — reads it back
- `:321` — same
- `:423` — same
- `:441` — same
**Fix**: Add `attr_accessor :filename` to `Models::LITFile` (or `Models::LITHeader`).

### lit/parser.rb
- `:225` — `entry.instance_variable_get(:@_bytes_read)` — reads parse metadata
  from `LITDirectoryEntry`
- `:280` — `entry.instance_variable_set(:@_bytes_read, pos - start_pos)` — sets it
- `:608` — `mapping.instance_variable_get(:@_bytes_read)` — reads from
  `LITManifestMapping`
- `:665` — `mapping.instance_variable_set(:@_bytes_read, pos - start_pos)` — sets it
**Fix**: Add `attr_accessor :bytes_read` to both entry models (rename `_bytes_read`
to a proper public name). This is parser position tracking, not domain state —
but it still belongs as a proper attribute.

### lit/command_handler.rb
- `:150` — `lit_file.instance_variable_get(:@filename)`
- `:186` — same
**Fix**: Fixed by TODO above (filename accessor).

### chm/decompressor.rb
- `:144-147, :153` — Swaps `@output` on `@lzx_state` (a Decompressors::LZX
  instance) to redirect decompression output
**Fix**: Add a public method on Decompressors::LZX like
`with_output(temporary_output) { ... }` or `redirect_output(handle)` /
`restore_output(handle)` pair. Better: add `decompress_to(handle, bytes)` that
temporarily sets output without caller managing ivars.

### cab/extractor.rb
- `:246` — `@current_decomp.instance_variable_set(:@output, null_output)`
- `:270` — `@current_decomp.instance_variable_set(:@output, output_fh)`
**Fix**: Same as chm — add public output-redirect API on decompressor base class.

### hlp/quickhelp/huffman_tree.rb
- `:100` — `tree.instance_variable_set(:@root, nodes[0])`
- `:101` — `tree.instance_variable_set(:@symbol_count, (n / 2) + 1)`
**Fix**: The `HuffmanTree` class is built by a factory method that then pokes
internal state. Add proper constructor or setter methods.

## Solution
For each location, add a proper public API to the target class:
1. `Models::LITFile` — `attr_accessor :filename`
2. `Models::LITDirectoryEntry`, `Models::LITManifestMapping` — `attr_accessor :bytes_read`
3. `Decompressors::Base` (and subclasses) — public output management:
   `decompress_to(output_handle, bytes)` method
4. `HuffmanTree` — proper constructor accepting root and symbol_count

## Verification
- `grep -rn "instance_variable_set\|instance_variable_get" lib/` returns 0
- All specs still pass
