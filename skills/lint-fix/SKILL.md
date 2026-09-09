---
name: lint-fix
description: MUST be used whenever the user asks to run linting/formatting or auto-fix lint issues. Always invoke this instead of manually running eslint/prettier/ruff/black/etc. yourself.
argument-hint: [path]
allowed-tools: Bash(ls:*), Bash(*lint*:*), Bash(*format*:*), Bash(npx:*), Bash(npm run:*), Bash(ruff:*), Bash(black:*), Bash(cargo fmt:*), Bash(rustfmt:*), Bash(gofmt:*), Bash(go fmt:*), Bash(git diff:*), Read, Edit
model: haiku
context: fork
agent: general-purpose
background: false
---

Target: $ARGUMENTS (if empty, use the whole project root).

Do this mechanically, step by step. Do not ask questions.

1. Detect lint/format tooling by checking the repo root for config/marker files (use `ls` and `Read`):
   - JS/TS: `package.json` (deps/scripts containing `eslint` and/or `prettier`), `.eslintrc*`, `eslint.config.*`, `.prettierrc*`, `prettier.config.*`
   - Python: `pyproject.toml` or `setup.cfg` (sections/deps for `ruff` and/or `black`)
   - Rust: `Cargo.toml` (implies `cargo fmt` / `rustfmt`)
   - Go: `go.mod` or any `*.go` files (implies `gofmt`)
   If none of these are found, output exactly: "No lint/format tooling detected." and stop. Make no changes.

2. For each tool detected, run its autofix command, scoped to $ARGUMENTS if given, else the whole project:
   - ESLint: `npx eslint --fix $ARGUMENTS` (or the project's `lint:fix`/`lint --fix` npm script if defined)
   - Prettier: `npx prettier --write $ARGUMENTS`
   - Ruff: `ruff check --fix $ARGUMENTS` and `ruff format $ARGUMENTS`
   - Black: `black $ARGUMENTS`
   - Rust: `cargo fmt`
   - Go: `gofmt -w $ARGUMENTS` (or `go fmt ./...` if no path given)
   Run every tool that is actually configured in the project — don't skip any that were detected in step 1.

3. Run `git diff --stat` to see what changed.

4. Summarize in 3-5 short lines: which tool(s) ran, how many files changed, and the general nature of the changes (e.g. formatting/whitespace, import ordering, quote style). Do not paste the full diff. Do not add extra commentary beyond this summary.
