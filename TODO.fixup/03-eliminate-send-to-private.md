# TODO 03: Eliminate .send to private methods

## Priority: P0 (explicit rule violation)

## Problem
The codebase uses `.send` to invoke private methods, bypassing encapsulation.
This violates: "NEVER use `send` to call private methods. Private methods are
private for a reason. If you need to call it from outside, the API boundary is
wrong — redesign, don't bypass."

## Affected Locations

### plugin_manager.rb (5 occurrences)
- `:139` — `plugin.send(:update_state, :loaded)`
- `:144` — `plugin.send(:update_state, :failed)`
- `:182` — `plugin.send(:update_state, :active)`
- `:187` — `plugin.send(:update_state, :failed)`
- `:221` — `plugin.send(:update_state, :loaded)`

`Plugin#update_state` is declared `protected`. The PluginManager (which owns the
plugin's lifecycle) calls it via `.send` to transition states. This is exactly
the anti-pattern the rule forbids.

**Fix**: The PluginManager is the rightful owner of plugin state transitions.
Make `Plugin#transition_to(new_state)` a public method (rename from
`update_state` to convey the state-machine semantics), or move state management
entirely into PluginManager (the manager already tracks `entry[:state]`
separately — the duplicate state on the plugin instance is a MECE violation).

Best approach: **Remove `@state` from Plugin entirely.** The PluginManager
already tracks state in its registry `entry[:state]`. Having state in two places
is a DRY + MECE violation. Delete `Plugin#state`, `Plugin#update_state`, and
the `STATES` constant from Plugin. Expose state via the manager only.

### streaming.rb (1 occurrence)
- `:171` — `@file.send(method, ...)` inside `method_missing`

The `LazyFile` wrapper delegates unknown methods to the wrapped file via
`method_missing` + `send`. This also uses `respond_to_missing?` with
`respond_to?`.

**Fix**: `LazyFile` should use `Forwardable` or explicit delegation for known
methods, and not use `method_missing` at all. Define the full interface
explicitly (name, size, attributes, date, time, data, stream_data). Remove
`method_missing` and `respond_to_missing?`.

## Verification
- `grep -rn '\.send(' lib/` returns 0
- Plugin specs pass
- Streaming specs pass
