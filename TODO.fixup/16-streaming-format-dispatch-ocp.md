# TODO 16: OCP — Streaming format dispatch

## Priority: P2 (Open/Closed Principle violation)

## Problem
`Streaming::StreamParser#each_file` uses `case @format` to dispatch to
format-specific streaming methods (stream_cab_files, stream_chm_files).
Adding a new streamable format requires modifying this switch.

## Solution
Register stream handlers in a hash and look up by format symbol:
```ruby
STREAM_HANDLERS = {
  cab: :stream_cab_files,
  chm: :stream_chm_files,
}.freeze
```
Then `send(STREAM_HANDLERS[@format])` — or better, use a registry that
plugins can extend.

## Verification
- Streaming specs pass
- New formats can add streaming without modifying StreamParser
