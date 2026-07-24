# TODO 06: Eliminate instance_variable_set/get in specs

## Priority: P0 (explicit rule violation)

## Problem
Specs use `instance_variable_set` and `instance_variable_get` to poke at internal
state, both to set up test conditions and to assert on hidden state. This is
testing implementation, not behavior, and breaks encapsulation.

## Affected Files

### spec/plugin_spec.rb
- `:54` — `plugin.instance_variable_get(:@manager)` — assert on manager
- `:130` — `plugin.instance_variable_get(:@activated)` — assert on private flag
- `:182` — `manager.instance_variable_set(:@plugins, {})` — reset registry
**Fix**: 
- Expose `plugin.manager` as a reader (it's set in constructor, reading it is fine)
- The `@activated` flag is test-only state on an example plugin — remove it or
  expose via a proper method
- PluginManager should provide a `clear` or `reset` method instead of poking
  `@plugins`

### spec/file_manager_spec.rb
- `:153` — `manager.instance_variable_get(:@entries)` — assert entries not same
  object
**Fix**: Expose `entries` via a reader or test through public behavior.

### spec/plugin_manager_spec.rb
- `:60-61` — `manager.instance_variable_set(:@plugins, {})`, `:@formats, {}`
- `:80-81` — same on `new_manager`
- `:360` — `manager.instance_variable_get(:@mutex)` — assert mutex exists
**Fix**: Use `PluginManager.new` (fresh instance) or a `reset` method instead of
clearing ivars. For the mutex assertion, remove it — testing implementation
detail.

### spec/decompressors/quantum_spec.rb
- `:140` — `quantum.instance_variable_get(:@bitstream)` — get internal bitstream
- `:149` — same
**Fix**: Test through public decompress interface. If the bitstream needs
verification, expose it via a reader or restructure the test.

## Solution
1. Add proper public readers where the spec legitimately needs to inspect state
   (e.g., `plugin.manager`, `FileManager#entries`).
2. Add `PluginManager#reset` or rely on `PluginManager.new` for fresh state.
3. Remove tests that assert on pure implementation detail (mutex existence,
   private flags) — replace with behavior tests.

## Verification
- `grep -rn "instance_variable_set\|instance_variable_get" spec/` returns 0
- All specs pass
