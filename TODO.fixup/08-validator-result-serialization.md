# TODO 08: Clean up Validator::Result serialization

## Priority: P2 (code cleanliness)

## Problem
`lib/cabriolet/validator.rb:314-335` defines `to_h` and `to_json` on a
`Validator::Result` class. While this is a result/report value object (not a
domain model), hand-rolled serialization is a code smell.

The project rule targets model classes specifically: "NEVER write `def to_h`...
on a model class." A validation Result is a value object, not a model, so this
doesn't strictly violate the rule. However, the `to_json` method does
`require "json"` inline and calls `to_h.to_json` — the `require` should be at
file top.

## Solution
1. Move `require "json"` from inside `to_json` to the top of `validator.rb`
   (under the `require_relative` cleanup, this becomes a top-level autoload or
   require).
2. Keep `to_h` and `to_json` — they are appropriate for a result/report value
   object that callers serialize for tooling output. This is not a domain model.
3. Alternatively, use `Struct` with `:valid, :format, :level, :path, :errors,
   :warnings` members which gets `to_h` for free.

## Verification
- `to_json` works without inline require
- Validator specs pass
