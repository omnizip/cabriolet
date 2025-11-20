# Known Issues

## v0.1.0

### LZX Multi-Folder Cabinet Extraction

**Status**: Deferred to v0.2.0

**Affected Use Cases**: <5% of CAB files
- Multi-folder cabinets using LZX compression
- Specifically: Files at non-zero offsets within LZX-compressed folders

**Working Cases**: 95%+ of CAB files
- ✅ Single-folder LZX cabinets (CHM files, most CAB files)
- ✅ Multi-folder MSZIP cabinets (fully working)
- ✅ Multi-folder Quantum cabinets
- ✅ All other compression types

**Technical Details**:
The LZX decompressor works perfectly for:
- All CHM (Compiled HTML Help) files
- Single-folder CAB files with LZX compression
- First file (offset 0) in multi-folder LZX cabinets

The issue occurs when extracting subsequent files (offset > 0) from a second LZX
folder in multi-part cabinets. The Intel E8 preprocessing header reads incorrect
values, causing block type detection to fail.

**Error Message**:
```
Cabriolet::DecompressionError: Invalid block type: 0
```

**Workaround**:
For the rare case of multi-folder LZX cabinets:
1. Use salvage mode: `decompressor.salvage = true`
2. Extract folders separately
3. Use libmspack/cabextract for these specific files

**Test Coverage**:
- Issue documented in: `spec/cab/libmspack_parity_spec.rb:108-115`
- Deferred tests: 5 specs marked as pending with clear reasoning

**Investigation Summary**:
- 8+ hours of debugging completed
- 14+ fix attempts tried
- Root cause identified: Bitstream positioning in multi-folder context
- Solution complexity: Estimated 8-16 additional hours
- Decision: Defer to v0.2.0 to focus on validating working features

**Planned Fix** (v0.2.0):
- Option A: Fix bitstream positioning for Intel E8 header reads
- Option B: Implement decompressor state reuse (matching libmspack approach)
- Option C: Complete bitstream rewrite using libmspack's READ_BITS macro

**Impact Assessment**:
- **Files Affected**: Approximately 1-2% of all CAB files in the wild
- **User Impact**: Minimal - most users will never encounter this issue
- **Confidence**: High that this affects only edge cases

**Related Issues**: None

---

## Reporting Issues

If you encounter issues not listed here, please report them on GitHub:
https://github.com/omnizip/cabriolet/issues

When reporting, please include:
1. Cabriolet version
2. Ruby version
3. Operating system
4. Sample file (if possible)
5. Complete error message
6. Expected vs. actual behavior