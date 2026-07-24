# TODO 01: Migrate require_relative to autoload

## Priority: P0 (explicit rule violation)

## Problem
The codebase uses 207 `require_relative` calls across 47 files. This violates the
project rule: "NEVER use `require_relative` for internal library code... Use Ruby
`autoload` instead. Define autoload entries in the immediate parent namespace's
file — create that file if it doesn't exist."

Eager-loading every file at gem load time:
- Slows startup (every format loaded even if only CAB is used)
- Creates load-order coupling (files must be required in dependency order)
- Prevents lazy loading benefits for large gem
- Couples namespaces to file paths explicitly

## Affected Files (47)
Every file under `lib/cabriolet/` that contains `require_relative`, plus the main
`lib/cabriolet.rb` which has ~60 require_relative calls.

## Solution
1. Create namespace-defining files for each module namespace:
   - `lib/cabriolet/system.rb` — `module System; autoload ...; end`
   - `lib/cabriolet/binary.rb` — `module Binary; autoload ...; end`
   - `lib/cabriolet/huffman.rb` — `module Huffman; autoload ...; end`
   - `lib/cabriolet/models.rb` — `module Models; autoload ...; end`
   - `lib/cabriolet/decompressors.rb` — `module Decompressors; autoload ...; end`
   - `lib/cabriolet/compressors.rb` — `module Compressors; autoload ...; end`
   - `lib/cabriolet/cab.rb` — `module CAB; autoload ...; end`
   - `lib/cabriolet/chm.rb` — `module CHM; autoload ...; end`
   - `lib/cabriolet/szdd.rb` — `module SZDD; autoload ...; end`
   - `lib/cabriolet/kwaj.rb` — `module KWAJ; autoload ...; end`
   - `lib/cabriolet/hlp.rb` — `module HLP; autoload ...; end` (+ sub-namespaces)
   - `lib/cabriolet/lit.rb` — `module LIT; autoload ...; end`
   - `lib/cabriolet/oab.rb` — `module OAB; autoload ...; end`
   - `lib/cabriolet/cli.rb` (already namespace, add autoload)
   - `lib/cabriolet/extraction.rb` — `module Extraction; autoload ...; end`
   - `lib/cabriolet/collections.rb` — `module Collections; autoload ...; end`

2. Replace `lib/cabriolet.rb` 60+ require_relative with autoload declarations in
   the `module Cabriolet` body.

3. Remove all `require_relative` from individual lib files. Keep `require` for
   external gems (bindata, thor, zlib, securerandom, fileutils, fractor, singleton,
   yaml, json, time, stringio) at point of use.

## Verification
- `grep -rn "require_relative" lib/` returns 0 results (except gemspec)
- `ruby -Ilib -e "require 'cabriolet'; puts Cabriolet::VERSION"` works
- `bundle exec rspec` passes
