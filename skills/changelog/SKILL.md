---
name: changelog
description: MUST be used whenever the user asks to update, generate, or write changelog/release-notes entries from git history. Always invoke this instead of writing changelog entries manually.
argument-hint: [since-ref]
allowed-tools: Bash(git log:*), Bash(git tag:*), Bash(git describe:*), Read, Edit, Write
model: haiku
context: fork
agent: general-purpose
background: false
---

Generate a new CHANGELOG.md section from git history. Follow these steps exactly, no extra commentary.

1. Determine the commit range:
   - If `$1` is given, use range `$1..HEAD`.
   - Else run !`git describe --tags --abbrev=0` to find the last tag.
     - If a tag exists, use range `<tag>..HEAD`.
     - If no tag exists, use the last 20 commits (`-20`, no range).
2. Run `git log` over that range with `--no-merges --pretty=format:%s` to get one commit subject per line.
3. Categorize each commit subject into one of: Features, Fixes, Refactors, Docs, Chores.
   - Use conventional-commit prefixes when present: `feat` -> Features, `fix` -> Fixes, `refactor` -> Refactors, `docs` -> Docs, `chore`/`build`/`ci`/`test`/`style` -> Chores.
   - If no prefix, infer the best-fit category from the message wording. Default to Chores if unclear.
   - Strip any conventional-commit prefix (e.g. `feat:`, `fix(scope):`) from the entry text.
4. Read the existing CHANGELOG.md at the project root (if it exists). If it does not exist, create it with a single `# Changelog` header line.
5. Build a new section:
   - Heading: `## YYYY-MM-DD` using today's date.
   - One sub-heading per non-empty category, in this order: Features, Fixes, Refactors, Docs, Chores. Skip categories with no commits.
   - Under each sub-heading, one terse bullet per commit, exact commit subject text (prefix stripped), no rewording, no editorializing, no extra explanation.
6. Suggest a semver bump for the section heading: MAJOR if any commit subject contains a breaking-change marker (`!` after type/scope, e.g. `feat!:`, or the word "BREAKING"), else MINOR if any commit is categorized Features, else PATCH. Append it to the heading, e.g. `## YYYY-MM-DD (suggested: minor)`.
7. Prepend the new section to CHANGELOG.md, directly under the `# Changelog` header (existing content below stays unchanged). Write the file.
8. Output only the final list of category headings used, the count of commits filed under each, and the suggested bump. No other commentary.
