# TODO 20: DRY — Command handler with_archive pattern

## Priority: P2

## Problem
All 7 handlers reimplement validate_file_exists → open → yield → close.
The boilerplate is ~5 lines duplicated per method across list/info/extract.

## Solution
Add with_archive(file) helper to BaseCommandHandler that handles the
open/yield/close lifecycle. Each handler provides its decompressor class.
