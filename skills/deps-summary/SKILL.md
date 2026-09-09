---
name: deps-summary
description: MUST be used whenever the user asks what dependencies changed, to review a lockfile/manifest diff, or to summarize version bumps. Always invoke this instead of reading the lockfile diff manually.
argument-hint: [ref]
allowed-tools: Bash(git diff:*), Read
model: haiku
context: fork
agent: general-purpose
background: false
---

Ref to diff against: $1 (if empty, use HEAD).

1. Detect which dependency manifest/lockfile files exist in the repo root (and nested dirs if relevant). Check for: `package.json` + `package-lock.json`/`pnpm-lock.yaml`/`yarn.lock`, `requirements.txt`/`poetry.lock`/`uv.lock`, `Cargo.toml`/`Cargo.lock`, `go.mod`/`go.sum`, `Gemfile`/`Gemfile.lock`, and similar ecosystem files.
2. For each one found, run `git diff <ref-or-HEAD> -- <file>` to get the changes.
3. Parse the diff and extract only actual dependency version changes: package name, old version → new version.
4. Classify each change as major, minor, or patch bump (semver: major = first number changed, minor = second, patch = third; for non-semver ecosystems use the closest equivalent).
5. Output a short plain-English bullet list, one line per changed package: `name: old → new (patch/minor/major)`. Group by manifest file if multiple are present.
6. Clearly flag any major-version bumps at the top or with a visible marker (e.g. "⚠ MAJOR") since these are more likely to be breaking.
7. Do not explain what any dependency does or does research beyond the diff — only report version deltas. If no manifest/lockfile changes are found, say so briefly and stop.
