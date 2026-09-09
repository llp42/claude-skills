---
name: test-gap
description: MUST be used whenever the user asks which changed lines lack test coverage, or to find test coverage gaps in the current diff. Always invoke this instead of manually cross-referencing a coverage report yourself.
argument-hint: [coverage-file]
allowed-tools: Bash(git diff:*), Read, Glob
model: haiku
context: fork
agent: general-purpose
background: false
---

Find test coverage gaps in the current diff.

1. Get the diff: run `git diff`. If it is empty, run `git diff HEAD~1` instead and note that the last commit was used instead of uncommitted changes.
2. Locate a coverage report:
   - If `$1` is given, use it as the path to the coverage report.
   - Otherwise, Glob for these common locations, in order: `coverage/lcov.info`, `coverage/coverage-final.json`, `coverage.xml`, `.coverage`, `coverage/clover.xml`.
   - If none are found, state plainly that no coverage report was found and stop. Do not guess or fabricate coverage data.
3. Parse the diff to determine, per changed file, which line numbers were added or modified. Ignore purely deleted lines.
4. Read and parse the coverage report according to its format:
   - lcov (`lcov.info`): `SF:` marks the start of a file section; `DA:<line>,<hits>` gives hit counts; a hit count of 0 means uncovered.
   - Cobertura (`coverage.xml`): `<class filename=...>` contains `<line number="N" hits="H"/>` entries; `hits="0"` means uncovered.
   - Istanbul JSON (`coverage-final.json`): each file entry has `statementMap`/`s` (or line-level data) mapping statement/line ids to hit counts; 0 means uncovered.
   - Clover (`clover.xml`): `<line num="N" count="C" .../>`; `count="0"` means uncovered.
   - `.coverage` (Python sqlite/binary): if it cannot be parsed directly, state that and skip it rather than guessing.
5. Cross-reference: for each changed file that appears in the coverage report, find which of its changed line numbers have zero hits.
6. Output a compact report, one section per file:
   - File path
   - List of uncovered changed line numbers (collapse consecutive runs into ranges, e.g. `12-15, 22, 40-41`)
   - If a changed file has no entry at all in the coverage report, list it separately under "Not covered by any test run" instead of guessing at its status.

Keep output terse and factual. Do not speculate about why a line is uncovered or suggest fixes unless asked.
