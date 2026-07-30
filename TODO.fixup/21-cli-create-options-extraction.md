# TODO 21: Extract CLI create-option helpers out of the Thor class

## Priority: P2 (structure)

## Problem
`lib/cabriolet/cli.rb` wraps six helpers in a single `no_commands do ... end`
block. The block is 87 lines against a `Metrics/BlockLength` limit of 66, so
the cop is currently excluded for that file in `.rubocop.yml`.

The exclusion is correct as far as it goes — a `no_commands` block's length
tracks how many Thor helpers exist, not how complex any of them is, so the
metric does not fit the idiom. But the underlying shape is still wrong: three
of those helpers are pure functions that have nothing to do with Thor.

- `detect_format_from_output(output, manual_format)`
- `normalize_create_options(options)`
- `parse_language_id(value)`

None of them reads `self`, an instance variable, or Thor's `options`.
Everything arrives as an argument. They are called only from `cli.rb:90`,
`cli.rb:93`, and `cli.rb:359`.

## Solution
Extract the three pure helpers into `Cabriolet::CLI::CreateOptions` and
`include` it. That drops roughly 55 lines from `cli.rb` (517 → ~460), brings
the `no_commands` block back under the limit on its own, and gives the
option/format logic a home outside a command class where it can be tested
directly.

Then drop the `Metrics/BlockLength` exclusion from `.rubocop.yml` and delete
the comment pointing at this file.

## Considered and rejected
- **Splitting `no_commands` into two blocks.** Two ~44-line blocks are not
  simpler than one 87-line block; the seam exists only to satisfy the counter.
- **Marking the helpers `private` and dropping `no_commands` entirely.** Thor's
  `method_added` skips non-public methods, so this works, but it changes the
  helpers' visibility and breaks the specs that call
  `cli.run_dispatcher(...)` and `cli.setup_verbose(...)` directly.

## Verification
- `bundle exec rubocop` passes with the `Metrics/BlockLength` exclusion removed
- `cli.rb` is under 470 lines
- CLI specs pass unchanged

## Credit
Raised by the thermo-nuclear review of the lint-sweep branch
`fix-rubocop-offenses`, which flagged the block split as metric-gaming and
identified the extraction as the real fix. Deferred out of that branch to keep
it a pure lint change.
