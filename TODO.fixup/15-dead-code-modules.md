# TODO 15: Dead code — FormatBase, FileCollection, OffsetCalculator

## Priority: P2 (MECE violation — modules that don't earn their keep)

## Problem
Three modules are defined and autoloaded but never referenced:
- `FormatBase` (79 lines) — no class inherits from it
- `Collections::FileCollection` (175 lines) — no code uses it
- Top-level `OffsetCalculator` / `CABOffsetCalculator` (81 lines) — never called
  (note: HLP::QuickHelp::OffsetCalculator is a different, used class)

These fail the deletion test: deleting them removes complexity without
relocating it. They confuse new developers and add maintenance burden.

## Solution
Per user rules (NEVER DELETE SOURCE FILES), flag each with a clear header
comment documenting that it is currently unused and connecting it to the
intended use case or marking it as a future API.

## Verification
- Header comments clearly document the status of each module
