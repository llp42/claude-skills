---
name: env-lint
description: MUST be used whenever the user asks to check .env file parity, find missing/extra environment variables, or validate .env against .env.example. Always invoke this instead of comparing env files manually.
argument-hint: [dir]
allowed-tools: Read, Glob
model: haiku
context: fork
agent: general-purpose
background: false
---

Check environment file parity in directory: $1 (if empty, use the project root).

Steps:

1. Determine the target directory from `$1`, defaulting to the project root if not given.
2. Glob the target directory for env files, and identify actual pairs that both exist, such as:
   - `.env` + `.env.example`
   - `.env.local` + `.env.example`
   - `.env` + `.env.sample`
   - Other `.env*` + `.env.example`/`.env.sample`/`.env.template` combinations present.
   If no such pair exists, report that no env file pair was found and stop.
3. For each file in a found pair, read it and extract ONLY variable names: for each non-blank, non-comment (`#`) line, take the substring before the first `=`. Never read, output, log, or repeat the values after `=` — `.env` files may contain real secrets.
4. Compute set differences between the two key lists:
   - Keys present in the real env file (`.env`/`.env.local`) but missing from the example/sample file — flag as "should probably be documented in the example file."
   - Keys present in the example/sample file but missing from the real env file — flag as "may be unset locally."
5. Report plainly, per pair checked:
   - File pair compared.
   - List of keys missing from the example file (names only).
   - List of keys missing from the real env file (names only).
   - If both lists are empty, state the files are in perfect parity.

Keep output concise: key names only, no values, no extra commentary beyond the lists above.
