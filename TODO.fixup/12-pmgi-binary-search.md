# TODO 12: Implement PMGI binary search in CHM decompressor

## Priority: P2 (performance optimization)

## Problem
`chm/decompressor.rb#fast_search_pmgi` currently falls back to linear PMGL
search. PMGI chunks provide an index that enables O(log n) binary search,
which is significantly faster for large CHM files with many entries.

## Solution
Implement binary search over PMGI index entries:
1. Parse PMGI chunk headers to extract index entries
2. Binary search for the target filename
3. Use the found chunk number to narrow the PMGL search

## Verification
- CHM decompressor specs pass
- Performance: large CHM files search faster
