# TODO 07: Address code TODO comments

## Priority: P1 (incomplete functionality)

## Problem
Several command handlers and decompressors contain TODO comments indicating
stubbed-out functionality. These should be either implemented or clearly
documented as intentional limitations.

## Affected Locations

### Integrity testing stubs (5 files)
- `lib/cabriolet/cab/command_handler.rb:117` — `# TODO: Implement full integrity testing`
- `lib/cabriolet/chm/command_handler.rb` (similar pattern, check)
- `lib/cabriolet/szdd/command_handler.rb:138` — same
- `lib/cabriolet/kwaj/command_handler.rb:151` — same
- `lib/cabriolet/hlp/command_handler.rb:119` — same

These handlers have a `test`/`verify` command that currently only does basic
checks. "Full integrity testing" means: verify checksums on all data blocks,
verify file sizes match headers, verify folder structure consistency.

**Fix**: Wire the existing `Validator` class into each command handler's test
command. The Validator already does checksum and structural validation. Use it
instead of stub logic.

### LZX compressor TODO
- `lib/cabriolet/compressors/lzx.rb:125` — `# TODO: Use compress_frame_verbatim
  once tree encoding is fixed`

The LZX compressor falls back to a simpler path because tree encoding has a bug.
**Fix**: This requires deep LZX expertise. At minimum, document the limitation
clearly and ensure the fallback produces valid (if not optimally compressed)
output. If the fallback already works, convert the TODO to a documented
limitation comment.

### CHM PMGI binary search
- `lib/cabriolet/chm/decompressor.rb:382` — `# TODO: Implement PMGI-based binary
  search`

CHM files use PMGI (Name List) index chunks for fast binary search of entries.
Currently a linear scan is used. For large CHM files this is slow.

**Fix**: Implement binary search over PMGI index entries. This is a performance
optimization, not a correctness issue. Document if deferred.

## Solution
1. For integrity testing: wire `Cabriolet::Validator` into each handler's `test`
   command. Replace stub with real validation.
2. For LZX: ensure fallback works, document limitation clearly.
3. For PMGI: implement binary search or document deferral with rationale.

## Verification
- `grep -rn "TODO" lib/` returns 0 (or only documented limitations)
- Integrity test commands actually validate archives
