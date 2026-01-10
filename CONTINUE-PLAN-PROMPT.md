# Cabriolet Pending Specs Fix - Continuation Prompt

**Last Updated**: 2025-11-24
**Context**: Post v0.1.2 release - Address critical pending specs
**Priority**: High-value specs that improve production readiness

---

## Session Kickoff Prompt

```
I need to address pending specs in Cabriolet v0.1.3/v0.2.0. Please read:
1. PENDING_SPECS_ANALYSIS.md - Full spec categorization
2. V0.2.0_ROADMAP.md - Implementation plan
3. KNOWN_ISSUES.md - Current limitations

We'll focus on the HIGH and MEDIUM priority specs first, following the
implementation plan in V0.2.0_ROADMAP.md. Start with LZX multi-folder
extraction (5 specs) as it has the highest user impact.

Current status: 66 pending specs, target to resolve 12 critical ones.
```

---

## Quick Context

**Current State** (v0.1.2):
- 1,273 tests, 0 failures
- 100% libmspack parity (73/73)
- 66 pending specs (5.2%)
- All formats bidirectional and production-ready

**Goal**: Resolve 12 critical pending specs in phases
- Phase 1: LZX multi-folder (5 specs) - Milestone 1
- Phase 2: LZX compression (7 specs) - Milestone 2
- Future: Optional specs as needed

---

## Priority Matrix

### HIGH PRIORITY ⭐ (5 specs) - Start Here

**LZX Multi-Folder Extraction** - Affects <5% of CAB files but critical gap

Files to fix:
- `lib/cabriolet/cab/extractor.rb` - Add folder-level state management
- `lib/cabriolet/decompressors/lzx.rb` - Support incremental decompression
- `lib/cabriolet/binary/bitstream.rb` - Fix position tracking

Specs to enable:
1. `spec/cab/libmspack_parity_spec.rb:613` - Extract file 2 (lzx1.txt)
2. `spec/cab/libmspack_parity_spec.rb:618` - Extract file 3 (lzx2.txt)
3. `spec/cab/libmspack_parity_spec.rb:624` - All 24 permutations test
4. `spec/cab/libmspack_parity_spec.rb:655` - Mixed MSZIP/LZX extraction
5. `spec/cab/libmspack_parity_spec.rb:502` - Single-folder validation

**Implementation Approach**: See V0.2.0_ROADMAP.md Milestone 1 (lines 51-133)

**Estimated Effort**: 20-24 hours over 2-3 weeks

---

### MEDIUM PRIORITY (7 specs) - After High Priority

**LZX VERBATIM Block Implementation** - Enables CHM/OAB compression

Files to create/modify:
- Create: `lib/cabriolet/compressors/lzx_match_finder.rb`
- Modify: `lib/cabriolet/compressors/lzx.rb`

Specs to enable:
1. `spec/chm/compressor_spec.rb:214` - CHM single file
2. `spec/chm/compressor_spec.rb:249` - CHM multiple files
3. `spec/chm/compressor_spec.rb:303` - CHM large files
4. `spec/oab/decompressor_spec.rb:94` - OAB round-trip
5. `spec/oab/compressor_spec.rb:191` - OAB validation
6. `spec/oab/compressor_spec.rb:211` - OAB binary data
7. `spec/oab/compressor_spec.rb:228` - OAB multiple blocks

**Implementation Approach**: See V0.2.0_ROADMAP.md Milestone 2 (lines 135-205)

**Estimated Effort**: 12-16 hours over 1-2 weeks

---

### LOW PRIORITY (54 specs) - Optional/Future

**Categories**:
- Quantum compression edge cases (27 specs) - Best effort, use MSZIP/LZX instead
- Test fixtures missing (16 specs) - Community contributions welcome
- MSZIP test data (4 specs) - Already well-tested
- CAB integration (4 specs) - Redundant with other tests
- Platform-specific (1 spec) - Inherent limitation
- Minor gaps (2 specs) - Existing functionality sufficient

**Resolution**: v0.3.0+ or community contributions

---

## Implementation Plan

### Phase 1: LZX Multi-Folder Fix (HIGH PRIORITY)

**Week 1: State Management** (8-10 hours)

Tasks:
1. Create `lib/cabriolet/cab/folder_state.rb`
   ```ruby
   module Cabriolet
     module CAB
       class FolderState
         attr_reader :decompressor, :folder_index
         
         def initialize(folder, folder_index)
           @folder = folder
           @folder_index = folder_index
           @decompressor = create_decompressor
         end
         
         def extract_file(file, output_handle)
           # Reuse decompressor state
         end
         
         private
         
         def create_decompressor
           # Factory method for algorithm selection
         end
       end
     end
   end
   ```

2. Modify `lib/cabriolet/cab/extractor.rb`
   - Add `@folder_states` hash to maintain state per folder
   - Modify `extract_file` to use folder state
   - Add cleanup on folder completion

3. Write tests for state management
   - Create folder state
   - State reuse across files
   - State cleanup
   - Memory leak prevention

**Week 2: LZX State Reuse** (8-10 hours)

Tasks:
1. Check if `lib/cabriolet/decompressors/lzx.rb` exists
   - If not, create from base decompressor pattern
   - Implement Intel E8 preprocessing
   - Implement block type handling

2. Add incremental decompression support
   ```ruby
   def reset_to_offset(offset)
     # Maintain window state
     # Reset position trackers
     # Preserve preprocessing state
   end
   ```

3. Fix bitstream positioning in `lib/cabriolet/binary/bitstream.rb`
   - Add position tracking
   - Fix Intel E8 header reads
   - Ensure correct block type detection

**Week 3: Testing & Validation** (4-6 hours)

Tasks:
1. Enable 5 pending specs
   - Remove `pending:` markers
   - Verify tests pass
   - Check MD5 checksums

2. Cross-platform validation
   - Test on Linux, macOS, Windows
   - Verify Ruby 2.7, 3.0, 3.1, 3.2, 3.3

3. Performance regression testing
   - Benchmark extraction speed
   - Check memory usage
   - Ensure within ±5% of v0.1.2

**Success Criteria**:
- ✅ All 5 LZX multi-folder specs passing
- ✅ 100% libmspack parity maintained (73/73)
- ✅ Zero regression in existing tests
- ✅ Performance within ±5%

---

### Phase 2: LZX VERBATIM Blocks (MEDIUM PRIORITY)

**Week 4: Match Finder** (6-8 hours)

Tasks:
1. Create `lib/cabriolet/compressors/lzx_match_finder.rb`
   ```ruby
   module Cabriolet
     module Compressors
       class LZXMatchFinder
         def initialize(window_size)
           @window_size = window_size
           @hash_chain = {}
         end
         
         def find_match(data, position)
           # Hash chain match finding
           # Return {length, distance}
         end
         
         private
         
         def hash(data, position)
           # 3-byte hash for match lookup
         end
       end
     end
   end
   ```

2. Implement sliding window management
3. Calculate position slots for LZX format
4. Write comprehensive tests

**Week 5: VERBATIM Encoding** (6-8 hours)

Tasks:
1. Modify `lib/cabriolet/compressors/lzx.rb`
   - Add VERBATIM block encoding
   - Implement main tree construction
   - Implement length tree construction
   - Implement distance tree construction

2. Integrate match finder
   - Use matches vs literals decision
   - Encode literals and matches
   - Build Huffman trees

3. Enable 7 pending specs
4. Verify round-trip functionality
5. Measure compression ratios

**Success Criteria**:
- ✅ All 7 compression specs passing
- ✅ Round-trip: compress → decompress → identical
- ✅ Compression ratio >50% for repetitive data
- ✅ No regression in decompression

---

## Testing Strategy

### Before Starting
1. Run full test suite: `bundle exec rspec`
2. Verify current state: 1,273 examples, 0 failures, 66 pending
3. Create Git branch: `git checkout -b fix-pending-specs`

### During Implementation
1. Run affected tests after each change
2. Use `--tag ~pending` to run only non-pending tests
3. Use `--tag pending` to check newly fixed specs
4. Profile memory with large files
5. Benchmark performance regularly

### After Each Phase
1. Full test suite: `bundle exec rspec`
2. RuboCop check: `bundle exec rubocop`
3. Cross-platform CI run
4. Update CHANGELOG.md
5. Commit with semantic message

---

## Reference Documents

**Primary References**:
- [`PENDING_SPECS_ANALYSIS.md`](PENDING_SPECS_ANALYSIS.md:1) - Full categorization (588 lines)
- [`V0.2.0_ROADMAP.md`](V0.2.0_ROADMAP.md:1) - Detailed plan (1,148 lines)
- [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md:5) - LZX multi-folder details

**Specifications**:
- `ms-cab-spec.pdf` - Microsoft CAB format specification
- libmspack source code - Reference implementation

**Existing Code**:
- [`lib/cabriolet/cab/extractor.rb`](lib/cabriolet/cab/extractor.rb:1) - Current extraction logic
- [`lib/cabriolet/decompressors/base.rb`](lib/cabriolet/decompressors/base.rb:1) - Decompressor pattern
- [`lib/cabriolet/compressors/lzx.rb`](lib/cabriolet/compressors/lzx.rb:1) - Current LZX compressor

**Tests**:
- [`spec/cab/libmspack_parity_spec.rb`](spec/cab/libmspack_parity_spec.rb:1) - Parity tests
- [`spec/support/md5_helpers.rb`](spec/support/md5_helpers.rb:1) - Test utilities

---

## Git Workflow

### Branch Strategy
```bash
# Create feature branch
git checkout -b fix-lzx-multifolder

# After Phase 1 complete
git add .
git commit -m "fix(lzx): implement multi-folder extraction state reuse"
git push origin fix-lzx-multifolder

# Create PR for review
gh pr create --title "Fix LZX multi-folder extraction" --body "Resolves 5 pending specs..."

# After merge, create next branch
git checkout main
git pull
git checkout -b implement-lzx-verbatim
```

### Commit Message Format
```
<type>(<scope>): <subject>

Types: feat, fix, refactor, test, docs
Scopes: lzx, cab, compressor, decompressor
```

Examples:
- `fix(lzx): add decompressor state reuse for multi-folder extraction`
- `feat(lzx): implement VERBATIM block compression`
- `test(cab): enable 5 LZX multi-folder libmspack parity specs`

---

## Success Metrics

### Phase 1 (LZX Multi-Folder)
- [ ] 5 pending specs now passing
- [ ] 0 test failures (maintain 100%)
- [ ] 100% libmspack parity (73/73)
- [ ] Performance within ±5%
- [ ] Memory usage within ±10%
- [ ] KNOWN_ISSUES.md updated (remove LZX section)

### Phase 2 (LZX VERBATIM)
- [ ] 7 pending specs now passing
- [ ] Total pending reduced to 54 (from 66)
- [ ] CHM compression working
- [ ] OAB compression working
- [ ] Compression ratio >50% for test data
- [ ] Round-trip validation passing

### Overall Project (After Both Phases)
- [ ] 1,285 tests passing (12 more than before)
- [ ] 54 pending specs (down from 66)
- [ ] 0 test failures
- [ ] 100% libmspack parity maintained
- [ ] Documentation updated
- [ ] Ready for v0.1.3 or v0.2.0-alpha release

---

## Troubleshooting Guide

### Common Issues

**Issue**: Tests still fail after implementing state reuse
**Solution**: Check bitstream position tracking, ensure Intel E8 header reads at correct offset

**Issue**: Memory usage increases significantly
**Solution**: Verify decompressor cleanup on folder completion, check for state leaks

**Issue**: Performance regression >5%
**Solution**: Profile hot paths, consider state initialization overhead, may need optimization pass

**Issue**: Round-trip compression fails
**Solution**: Verify Huffman tree construction, check match encoding, compare with libmspack

**Issue**: Cross-platform test failures
**Solution**: Check endianness handling, verify file path separators, test on actual platform

---

## Release Checklist

### After Phase 1
- [ ] All Phase 1 tests passing
- [ ] RuboCop clean
- [ ] Documentation updated
- [ ] CHANGELOG.md entry added
- [ ] Performance benchmarks documented
- [ ] Create tag: `git tag v0.1.3-alpha1`

### After Phase 2
- [ ] All Phase 2 tests passing
- [ ] Combined testing with Phase 1
- [ ] Full regression suite
- [ ] README examples updated
- [ ] Consider v0.2.0-alpha release
- [ ] Announce to community for feedback

### Final Release (v0.1.3 or v0.2.0-alpha)
- [ ] Version bump
- [ ] Complete CHANGELOG
- [ ] Update README stats
- [ ] Generate YARD docs
- [ ] Cross-platform CI green
- [ ] Security review
- [ ] Tag and push
- [ ] Release to RubyGems (if appropriate)
- [ ] GitHub release notes
- [ ] Announce to community

---

## Quick Start Command

To begin implementing:

```bash
# 1. Ensure clean state
git status
bundle exec rspec --tag pending | grep -c "pending"  # Should show 66

# 2. Create branch
git checkout -b fix-lzx-multifolder

# 3. Start with folder state
mkdir -p lib/cabriolet/cab
touch lib/cabriolet/cab/folder_state.rb

# 4. Follow V0.2.0_ROADMAP.md Milestone 1 implementation plan
# 5. Test incrementally
# 6. Commit frequently
```

---

## Notes & Considerations

**Architecture**:
- Follow existing patterns in codebase
- Maintain separation of concerns
- Keep components <200 lines when possible
- Write tests for each new component

**Performance**:
- Profile before and after changes
- Benchmark with real CAB files
- Use `benchmark-ips` for micro-benchmarks
- Memory profiling with `memory_profiler` gem

**Documentation**:
- Update YARD comments for all new methods
- Add inline comments for complex algorithms
- Update architecture docs if needed
- Keep CHANGELOG.md current

**Community**:
- Consider early alpha release for feedback
- Document any breaking changes (should be none)
- Provide migration examples if needed
- Welcome contributions and bug reports

---

## Contact & Resources

**Project**: https://github.com/omnizip/cabriolet
**Issues**: https://github.com/omnizip/cabriolet/issues
**Discussions**: https://github.com/omnizip/cabriolet/discussions

**References**:
- libmspack: https://www.cabextract.org.uk/libmspack/
- CAB format: Microsoft Cabinet Format Specification
- LZX algorithm: Microsoft LZX Compression Format

---

**Ready to start? Use the session kickoff prompt at the top of this document!**

**Estimated Total Time**: 32-48 hours over 4-6 weeks for both phases
**Expected Result**: 12 fewer pending specs, production-ready LZX support
**Risk Level**: Low-Medium (well-documented, incremental approach)

🚀 **Let's fix these specs and make Cabriolet even better!**