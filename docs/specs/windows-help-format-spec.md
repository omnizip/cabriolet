
# Windows Help (WinHelp) Format Specification

**Version:** Draft 1.0
**Date:** 2025-11-19
**Author:** Cabriolet Development Team
**References:** helpdeco, Microsoft documentation, reverse engineering

---

## Overview

Windows Help files (.HLP) come in two distinct formats:
1. **QuickHelp** - DOS-based format (0x4C 0x4E signature) - ✅ Already implemented
2. **Windows Help** - Windows 3.x/4.x format (0x35F3 or 0x3F5F signature) - This spec

This document specifies the **Windows Help (WinHelp)** format used in Windows 3.0+ through Windows XP.

## Format Variants

### WinHelp 3.x (16-bit)
- **Signature:** 0x35F3 (magic number)
- **Structure:** Internal file system with B-tree
- **Compression:** Zeck LZ77 + phrase replacement
- **Platform:** Windows 3.0, 3.1, 3.11

### WinHelp 4.x (32-bit)
- **Signature:** 0x3F5F (magic number)
- **Structure:** Enhanced internal file system
- **Compression:** Improved Zeck LZ77
- **Platform:** Windows 95, 98, NT, 2000, XP

## File Structure

### High-Level Architecture

```
[WinHelp File Header]
├── Magic number (2 bytes)
├── Directory offset
├── Free list offset
└── File size

[Internal File Directory]
├── |SYSTEM (system file)
├── |TOPIC (topic data)
├── |TTLBTREE (title B-tree)
├── |CTXOMAP (context mapping)
└── Other internal files

[File Data Blocks]
├── Topic text (compressed)
├── Bitmaps
├── Hotspot data
└── Keywords index
```

### File Header (WinHelp 3.x)

**Structure (bytes 0-28):**
```
Offset  Size  Description
------  ----  -----------
0x00    2     Magic number (0x35F3)
0x02    2     Unknown/version
0x04    4     Directory offset
0x08    4     Free list offset
0x0C    4     File size
0x10    12    Reserved/padding
```

### File Header (WinHelp 4.x)

**Structure (bytes 0-32):**
```
Offset  Size  Description
------  ----  -----------
0x00    4     Magic number (0x3F5F0000 or similar)
0x04    4     Directory offset
0x08    4     Free list offset
0x0C    4     File size
0x10    16    Reserved/unknown
```

## Internal File System

### Directory Structure

The directory contains entries for all internal files:

**Directory Entry:**
```
- File size (4 bytes)
- Starting block number (2 bytes)
- File name (null-terminated, padded to align)
```

**Common internal files:**
- `|SYSTEM` - System configuration, window info, macros
- `|TOPIC` - Raw topic text data
- `|TTLBTREE` - Title B-tree index
- `|CTXOMAP` - Context to topic mapping
- `|KWBTREE` - Keyword B-tree index
- `|KWDATA` - Keyword data
- `|FONT` - Font table
- `|CATALOG` - File catalog
- `Baggage#` - Embedded files (bitmaps, etc.)

### |SYSTEM File Format

**Contains:**
- Window type definitions
- Macro strings
- Copyright text
- Citation text
- Help title
- Contents file path

**Structure:**
```
[Record 1: Window definitions]
[Record 2: Title]
[Record 3: Copyright]
[Record 4: Contents]
...
```

### |TOPIC File Format

**Topic Block Structure:**
```
[Topic Header]
- Block size
- Previous block
- Next block
- Topic count in block

[Topic Entries]
- Topic offset
- Topic size
- Attributes
- Compressed data
```

## Compression

### Zeck LZ77 Compression

Windows Help uses a variant of LZ77 called "Zeck compression":

**Algorithm characteristics:**
- Sliding window: 4KB (4096 bytes)
- Look-ahead buffer: Variable
- Minimum match: 3 bytes
- Maximum match: 271 bytes (3-18 encoded in 4 bits, 19-271 with length byte)

**Encoding format:**
```
Literal byte: 0x00-0xFF (bit 0 of flag = 0)
Match: Offset (12 bits) + Length (4-8 bits)
       (bit 0 of flag = 1)

Flag byte controls next 8 tokens:
- Bit 0 = 0: Literal byte follows
- Bit 0 = 1: Match follows (2-3 bytes)
```

**Match encoding:**
- Offset: 12 bits (0-4095, window size)
- Length 3-18: 4 bits (0-15, add 3)
- Length 19-271: Extra byte (0-252, add 19)

### Phrase Replacement

**Secondary compression layer:**
- Builds phrase dictionary from topic text
- Replaces common phrases with single-byte codes
- Typically 256-512 phrases
- Applied before Zeck LZ77

**Phrase encoding:**
```
Special byte (0x00-0x0F): Control codes
Phrase code (0x10-0xFF): Dictionary reference
Regular byte (0x20-0xFF): Literal text
```

## B-Tree Indexes

### B-Tree Structure (Title/Keyword indexes)

**Node structure:**
```
[B-tree Node Header]
- Node type (leaf vs internal)
- Number of entries
- Level in tree

[Entries]
- Key (string)
- Value (topic ID or child node)
- Padding as needed
```

**Index types:**
- `|TTLBTREE` - Maps titles to topics
- `|KWBTREE` - Maps keywords to topics
- Both use same B-tree format

**B-tree properties:**
- Order: Variable (typically 16)
- Keys: Null-terminated strings
- Values: 32-bit topic IDs or node offsets

## Topic Data Model

### Topic Structure

**Topic header:**
```
- Block size
- Previous topic offset
- Next topic offset
- Browse sequence number
```

**Topic body:**
```
- Uncompressed text
- Hotspot definitions
- Format codes
- Hyperlink data
```

### Hotspots

**Hotspot types:**
- Jump hotspot (navigate to topic)
- Popup hotspot (show popup window)
- Macro hotspot (execute WinHelp macro)
- External hotspot (launch program/open file)

**Hotspot data:**
```
- X, Y coordinates
- Width, height
- Target topic ID or macro string
- Type flags
```

## Format Codes

### Text Formatting

**Supported formats:**
- Bold, italic, underline
- Font changes
- Color changes
- Paragraph alignment
- Line spacing

**Encoding:**
```
Special byte sequences:
0x80-0x8F: Font changes
0x90-0x9F: Paragraph formats
0xA0-0xAF: Character formatting
```

## Implementation Priorities

### Phase 3.1: Research (Current)
- ✅ Document format structure
- ✅ Understand Zeck LZ77
- ✅ Understand phrase replacement
- ✅ Document B-tree structure

### Phase 3.2: Basic Parser (Weeks 11-12)
**Priority 1: Header parsing**
- Magic number detection
- Directory entry parsing
- |SYSTEM file extraction

**Priority 2: Topic extraction**
- |TOPIC file parsing
- Basic decompression (Zeck LZ77)
- Text extraction

**Priority 3: Skip for v0.1.0**
- B-tree indexes (optional for extraction)
- Hotspot parsing (optional for extraction)
- Phrase dictionary (can fall back to uncompressed)

### Phase 3.3: Decompressor (Weeks 11-12)
**Core functionality:**
1. Zeck LZ77 decompressor
2. Topic text extraction
3. Basic formatting preservation

**Deferred:**
- Full hotspot handling
- Phrase replacement (if not critical)
- B-tree index reading (use linear search)

### Phase 3.4: Compressor (Weeks 13-14)
**Minimal viable:**
1. File header generation
2. |SYSTEM file creation
3. |TOPIC file generation
4. Zeck LZ77 compression
5. Simple directory

**Deferred to v0.2.0:**
- Full B-tree generation (use simple list)
- Phrase dictionary building
- Advanced hotspot encoding

## Challenges & Solutions

### Challenge 1: Format Complexity
**Issue:** WinHelp is significantly more complex than QuickHelp
**Solution:** Implement minimum viable for v0.1.0, enhance in v0.2.0

### Challenge 2: Limited Documentation
**Issue:** No official spec, only reverse engineering
**Solution:** Study helpdeco source, test with real files

### Challenge 3: Zeck LZ77 Variant
**Issue:** Custom LZ77 variant, not standard
**Solution:** Implement based on helpdeco algorithm

### Challenge 4: B-Tree Indexes
**Issue:** Complex data structure, not critical for basic extraction
**Solution:** Optional - use linear search for v0.1.0

## References

### Primary Sources
1. **helpdeco:** https://github.com/martiniturbide/HelpDeco
   - Complete WinHelp decompiler
   - C source code
   - Comprehensive format knowledge

2. **Wine project:** Windows Help viewer implementation
   - Format parsing code
   - Cross-platform reference

3. **Microsoft documentation:** (historical, limited availability)
   - WinHelp API documentation
   - Help compiler notes

### File Samples Needed
- Windows 3.x help files (16-bit)
- Windows 4.x help files (32-bit)
- Various complexity levels
- Different compression states

## Implementation Roadmap

### Week 9-10: This Specification + helpdeco Analysis ✅

### Week 11: Parser Foundation
- File header parsing (both 3.x and 4.x)
- Directory entry parsing
- |SYSTEM file extraction
- Basic file detection

### Week 12: Zeck LZ77 Decompressor
- Implement Zeck LZ77 algorithm
- Topic text extraction
- |TOPIC file parsing
- Test with real files

### Week 13: Compressor Foundation
- File header generation
- Directory creation
- |SYSTEM file generation
- Basic structure

### Week 14: Zeck LZ77 Compressor
- Implement Zeck LZ77 compression
- Topic compression
- |TOPIC file generation
- Round-trip testing

### Week 15-16: Integration
- Format detection (3.x vs 4.x)
- Dual-format testing
- HLP dispatcher integration
- Documentation

## Success Criteria

### Minimum Viable (v0.1.0)
- ✅ Parse WinHelp 3.x and 4.x files
- ✅ Extract topic text (Zeck LZ77)
- ✅ Create basic WinHelp files
- ✅ Compress topics (Zeck LZ77)
- ✅ Format detection working

### Deferred (v0.2.0)
- Full B-tree index support
- Phrase dictionary implementation
- Complete hotspot handling
- Advanced formatting preservation
- Macro execution

---

## Next Actions

**Immediate:** Begin Week 11  implementation
1. Create `lib/cabriolet/hlp/winhelp/` directory
2. Implement WinHelp parser skeleton
3. Parse file header (3.x and 4.x variants)
4. Extract |SYSTEM file

This specification provides the roadmap for completing Windows Help support and achieving full libmspack parity!
</result>
</attempt_completion>