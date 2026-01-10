# Cabriolet Roadmap

This document outlines potential future enhancements for Cabriolet beyond v0.1.x.

## v0.1.x (Current - Maintenance)

**Status**: Feature complete, production ready

**Remaining Optional Work**:
- Resolve 58 pending specs (edge cases, best-effort)
- Performance optimization passes
- Additional test fixtures
- Documentation refinements

## v0.2.0 (Architectural Improvements)

**Target Release**: Q1 2026 (March 2026)
**Duration**: 8-12 weeks
**Status**: Planning Phase
**Detailed Plan**: See [`V0.2.0_ROADMAP.md`](V0.2.0_ROADMAP.md)

**Goal**: Address critical pending specs and improve code maintainability while maintaining 100% backward compatibility.

### Overview

Version 0.2.0 focuses on two main objectives:
1. **Fix Critical Issues**: Resolve LZX multi-folder extraction and implement LZX VERBATIM compression
2. **Architectural Improvements**: Refactor compressor architecture to reduce duplication and improve maintainability

### Success Metrics

- ✅ **LZX multi-folder**: 5 additional tests passing (reduces pending from 66 to 61)
- ✅ **LZX compression**: 7 additional tests passing (reduces pending from 61 to 54)
- ✅ **Code reduction**: 500-1000 lines removed via refactoring
- ✅ **Test coverage**: Maintain 0 failures, 100% libmspack parity (73/73)
- ✅ **Performance**: No regression (target: ±5%)
- ✅ **API stability**: Zero breaking changes

### Milestone 1: LZX Multi-Folder Extraction Fix
**Duration**: 2-3 weeks | **Priority**: High | **Impact**: <5% of CAB files

Currently, files at non-zero offsets in second+ LZX folders fail with "Invalid block type: 0". This affects a small percentage of multi-folder CAB files but is a significant limitation for comprehensive CAB support.

**Implementation Approach**:
- **Option A (Recommended)**: Decompressor state reuse matching libmspack architecture
- Maintain single decompressor instance per folder
- Reuse window state across multiple file extractions
- Fix Intel E8 preprocessing header positioning

**Key Changes**:
- Modify `CAB::Extractor` for folder-level state management
- Enhance `Decompressors::LZX` to support incremental decompression
- Update bitstream position tracking for correct offset handling

**Tests Resolved**: 5 specs
- Multi-folder file extraction (files 2-3)
- 24-permutation extraction test
- Mixed MSZIP/LZX extraction
- Single-folder validation improvement

### Milestone 2: LZX VERBATIM Block Implementation
**Duration**: 1-2 weeks | **Priority**: Medium | **Impact**: Enables compression features

Currently, LZX compressor only implements uncompressed blocks. VERBATIM blocks are needed for actual compression and to enable CHM/OAB creation with good compression ratios.

**Implementation Components**:
1. **Match Finder**: Hash chain-based match finding for LZ compression
2. **VERBATIM Encoding**: Literal/match encoding with Huffman trees
   - Main tree (literals + match positions)
   - Length tree (match lengths)
   - Distance trees (match distances)
3. **Block Management**: Optimal block size selection and encoding

**Tests Resolved**: 7 specs
- CHM compression round-trip (3 specs)
- OAB compression validation (3 specs)
- LZX repetitive data compression (1 spec)

**Note**: ALIGNED blocks deferred to v0.3.0 (optional for maximum compression)

### Milestone 3: BaseCompressor Refactoring
**Duration**: 4-6 weeks | **Priority**: Medium | **Impact**: Maintainability and extensibility

Extract common compressor patterns into reusable strategy components following object-oriented design principles.

**Component Extraction**:

1. **OffsetCalculator** (Strategy Pattern)
   - Purpose: Standardize file entry offset calculation
   - Implementations: CAB, CHM, SZDD, KWAJ, HLP, LIT, OAB
   - Interface: `calculate_offsets(files, options) → offsets_hash`

2. **HeaderBuilder** (Builder Pattern)
   - Purpose: Standardize format header construction
   - Implementations: Format-specific header generation
   - Interface: `build_header(files, options) → BinData::Record`

3. **FormatWriter** (Template Method Pattern)
   - Purpose: Standardize binary structure writing
   - Hooks: `write_header`, `write_data`, `write_footer`
   - Implementations: Format-specific write logic

**Migration Plan**:
- **Phase 1** (Weeks 1-2): Extract OffsetCalculator (base + 7 implementations)
- **Phase 2** (Weeks 3-4): Extract HeaderBuilder (base + 7 implementations)
- **Phase 3** (Weeks 5-6): Extract FormatWriter + complete migration

**Benefits**:
- Reduce code duplication by 500-1000 lines (~15-20% of compressor code)
- Easier to add new formats (follow established patterns)
- Better separation of concerns (single responsibility principle)
- Improved testability (component-level tests)
- Enhanced maintainability (changes in one place)

**Risk Mitigation**:
- Incremental approach (one component at a time)
- Binary output comparison (byte-for-byte verification)
- Comprehensive testing after each phase
- Feature flags for rollback if needed

### Milestone 4: Documentation & Polish
**Duration**: 1 week | **Priority**: High | **Impact**: Release quality

**Documentation Updates**:
- README.adoc: Version updates, new features, architecture changes
- CHANGELOG.md: Complete v0.2.0 release notes
- KNOWN_ISSUES.md: Remove resolved issues, update remaining
- API Documentation: YARD docs for new components
- Migration Guide: v0.1.x → v0.2.0 transition

**Performance Benchmarking**:
- Establish v0.2.0 baselines for all operations
- Compare against v0.1.2 performance
- Document any trade-offs
- Profile memory usage
- Cross-platform validation

**Release Preparation**:
- Version bump and reference updates
- Generate complete YARD documentation
- Security review
- Cross-platform testing (Linux, macOS, Windows)
- Ruby version compatibility (2.7, 3.0, 3.1, 3.2, 3.3)

### Timeline Summary

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| M1: LZX Multi-Folder Fix | 2-3 weeks | 5 tests passing, <5% CAB files working |
| M2: LZX VERBATIM Blocks | 1-2 weeks | 7 tests passing, CHM/OAB compression |
| M3: BaseCompressor Refactoring | 4-6 weeks | Clean architecture, -500 LOC |
| M4: Documentation & Polish | 1 week | Complete docs, benchmarks, release |
| **Total** | **8-12 weeks** | **v0.2.0 Release** |

**Critical Path**: M1 → M2 → M3 → M4 → Release

### Breaking Changes

**None** - Version 0.2.0 maintains 100% backward compatibility:
- All existing public APIs remain unchanged
- Binary output format identical (unless explicitly documented)
- No deprecations (all code continues to work)
- Dependencies unchanged (bindata ~> 2.5, thor ~> 1.3)

### Post-Release

**v0.2.1** (Bug Fixes):
- Critical bug fixes if needed
- Performance tuning based on feedback
- Documentation clarifications
- Release within 2-4 weeks if required

**Community Engagement**:
- Gather feedback on refactored architecture
- Accept test fixture contributions
- Prioritize v0.3.0 features based on user needs
- Office hours for migration support (optional)

### References

For complete details, see:
- **Comprehensive Plan**: [`V0.2.0_ROADMAP.md`](V0.2.0_ROADMAP.md)
- **Pending Specs Analysis**: [`PENDING_SPECS_ANALYSIS.md`](PENDING_SPECS_ANALYSIS.md)
- **Current Issues**: [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md)

## v0.3.0 (Extended Format Support)

**Goal**: Add support for related Microsoft formats.

### Additional Formats

#### 1. CHM Enhancements
- Multiple compression sections
- Advanced index support
- Full-text search index

#### 2. MSI (Windows Installer)
- Extract files from MSI packages
- Parse installer database
- Handle embedded CABs

#### 3. PDB (Program Database)
- Symbol file parsing
- Debug information extraction

#### 4. WIM (Windows Imaging)
- Windows deployment image support
- Multi-volume handling
- Compression algorithm support

### Benefits
- Broader format coverage
- More use cases
- Enterprise adoption

## v0.4.0 (Advanced Features)

**Goal**: Enterprise-grade features and performance.

### Planned Features

#### 1. Streaming API
- Progressive extraction without loading entire archive
- Memory-mapped file support
- Chunked processing

#### 2. Advanced Parallel Processing
- Multi-threaded extraction
- Thread pool management
- Progress tracking

#### 3. Archive Modification
- Update files in-place
- Add/remove files from existing archives
- Recompression support

#### 4. Format Conversion
- CAB ↔ ZIP conversion
- CHM ↔ EPUB conversion
- LIT ↔ EPUB conversion

### Benefits
- Production-grade performance
- Enterprise deployment
- Advanced use cases

## v1.0.0 (Stable Release)

**Goal**: Long-term stable release with guaranteed API compatibility.

### Requirements for 1.0
- 6+ months in production use
- No critical bugs
- API stability proven
- Performance benchmarked
- Security audited
- Complete test coverage (target: 0 pending)

### 1.0 Guarantees
- Semantic versioning strict adherence
- No breaking API changes in 1.x series
- Long-term support (2+ years)
- Security updates
- Bug fixes

## Future Considerations (2.0+)

### Potential Directions

#### 1. Native Extensions (Optional)
- C extension for critical paths
- Keep pure Ruby as fallback
- Maintain cross-platform support
- Target: 5-10x performance boost

#### 2. Additional Compression Algorithms
- Brotli support
- Zstandard support
- Modern algorithms via plugins

#### 3. Cloud Integration
- Azure Blob Storage support
- AWS S3 support
- Direct cloud extraction

#### 4. Enterprise Features
- Audit logging
- Access control
- Encryption at rest
- Compliance reporting

## Non-Goals

**Explicitly NOT planned**:
- DRM/encryption support (intentional limitation)
- GUI applications (CLI-first philosophy)
- Platform-specific optimizations breaking pure Ruby
- Breaking backward compatibility

## Contributing

We welcome contributions in these areas:

**High Priority**:
- Performance optimization (pure Ruby)
- Additional test fixtures
- Bug reports and fixes
- Documentation improvements

**Medium Priority**:
- Plugin development
- Format enhancements
- Example applications

**Low Priority**:
- GUI wrappers (community-maintained)
- Language bindings (community-maintained)

## Version Timeline (Estimated)

- **v0.1.x**: Current - Maintenance releases
- **v0.2.0**: +3-6 months - Architectural improvements
- **v0.3.0**: +6-12 months - Extended formats
- **v0.4.0**: +12-18 months - Advanced features
- **v1.0.0**: +18-24 months - Stable release

*Timeline is approximate and subject to change based on community needs and contributions.*

## Feedback Welcome

Have ideas for Cabriolet's future? Open an issue on GitHub:
https://github.com/omnizip/cabriolet/issues

---

**Last Updated**: 2025-11-19
**Current Version**: 0.1.2
**Status**: Feature complete, production ready