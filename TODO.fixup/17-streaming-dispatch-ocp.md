# TODO 17: OCP — Streaming format dispatch table

## Priority: P1

## Problem
StreamParser#each_file uses case/when for format dispatch. Adding a streamable
format requires modifying this switch.

## Solution
Replace with a STREAM_HANDLERS hash mapping format symbols to method names.
New formats register their handler without modifying StreamParser.
