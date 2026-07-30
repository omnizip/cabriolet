# TODO 21: Extract CAB extractor extraction state into a state object

## Priority: P2 (duplication, silent-drift risk)

## Problem
`CAB::Extractor` keeps its per-folder extraction state in four instance
variables: `@current_input`, `@current_decomp`, `@current_folder` and
`@current_offset`. Two methods in `lib/cabriolet/cab/extractor.rb` each
hand-list all four:

- `reset_state` clears them
- `idle?` reports whether they are all clear

Nothing keeps the two lists in step. Add a fifth piece of extraction state and
clear it in `reset_state` without adding it to `idle?`, and every
`expect(extractor).to be_idle` assertion silently stops guarding that field
while the suite stays green. A pointer comment on each method is the current
mitigation; it depends on the next editor reading it.

Surfaced by the Gate A review of TODO 06, which replaced the specs'
`instance_variable_get` pokes with `idle?`.

## Solution
Extract the four fields into a small state object (for example
`CAB::Extractor::FolderState`) owning the enumeration once:

1. The object holds input, decompressor, folder and offset.
2. `#release` closes the input, frees the decompressor and clears the fields.
3. `#idle?` derives from the same enumeration rather than repeating it.
4. `Extractor#reset_state` and `Extractor#idle?` delegate to it.

This touches every extraction-state read in `extractor.rb`, including
`setup_decompressor_for_folder`, `skip_to_file_offset` and `write_file_data`,
so it belongs in its own change rather than riding along with a spec cleanup.

## Verification
- `reset_state` and `idle?` no longer enumerate the fields independently
- Mutation check: removing any single field's clearing from the state object
  turns at least one `be_idle` example red
- `spec/cab/extractor_spec.rb` and `spec/cab/memory_spec.rb` pass unchanged
