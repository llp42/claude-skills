---
name: go-standards
description: MUST be used whenever the user asks to structure or scaffold a Go project (cmd/internal/pkg layout), set up or migrate golangci-lint, or enforce strict Go formatting with gofumpt. Always invoke this instead of inventing a Go directory tree or hand-writing a .golangci.yml.
argument-hint: [layout|lint|fmt|audit] [module-path?]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(go:*), Bash(golangci-lint:*), Bash(gofumpt:*), Bash(gofmt:*), Bash(ls:*), Bash(mkdir:*), Bash(cp:*), Bash(git status:*), Bash(git mv:*), Bash(git remote:*), Bash(git log:*)
model: sonnet
context: fork
agent: general-purpose
background: false
---

Target: $ARGUMENTS. The first word selects the mode; if it is absent or is not
one of the four below, run `audit`, then `layout`, `lint`, `fmt` in that order.

| Mode | Does |
| --- | --- |
| `layout` | Shape the directory tree to the Standard Go Project Layout. |
| `lint` | Install, configure, migrate, and run golangci-lint v2. |
| `fmt` | Wire up gofumpt and reformat. |
| `audit` | Report findings only. Create, move, and modify nothing. |

Everything needed is bundled in this skill's directory. Never fetch it from the
network, and never state anything about a config key, linter name, or formatting
rule without reading the file first:

| File | Holds |
| --- | --- |
| `references/project-layout.md` | The Standard Go Project Layout, verbatim from upstream. |
| `references/layout-directories.md` | Per-directory notes; the source for each new directory's `README.md`. |
| `references/golangci-lint.md` | v2 config schema, all 115 linters, CLI, CI, `nolint`, v1→v2 migration. |
| `references/gofumpt.md` | Every added rule with before/after, flags, editor setup. |
| `assets/golangci.yml` | Strict v2 config, validated against the official JSON schema. |
| `assets/golangci-lint.yml` | GitHub Actions workflow. |
| `assets/Makefile` | `fmt` / `lint` / `test` / `verify` targets. |
| `assets/editorconfig` | Tabs for Go, spaces for everything else. |

## 0. Context — always, before any mode

Gather, without commentary: module path and `go` directive from `go.mod`; the
number of `.go` files and packages (`go list ./...`); which layout directories
already exist; whether any `.golangci.{yml,yaml,toml,json}` is present and
whether it declares `version: "2"`; whether `main` packages exist.

No `go.mod`: derive the module path from `git remote get-url origin`, else from
the second word of $ARGUMENTS, then `go mod init <path>`. If neither is
available, stop and say so — the module path is the one thing that cannot be
guessed, and everything downstream encodes it.

## 1. `layout`

Read `references/project-layout.md` first.

**Size gate.** Upstream is explicit that this layout is overkill for a small
project. If the repo is a single package under roughly ten files, do not
scaffold: say so, name the one or two moves that are actually worth making, stop.

**Never create a directory you cannot immediately fill.** Git does not track
empty directories. Every directory you create gets real content, or the matching
section from `references/layout-directories.md` as its `README.md`.

Then apply, in this order:

1. `/cmd/<name>` — one per executable, directory name equal to the binary name.
   `main` stays small: parse flags, wire dependencies, call into a package.
2. `/internal` — the default home for this project's code. Privacy is enforced
   by the compiler, not by convention. Split into `/internal/app/<name>` and
   `/internal/pkg/<lib>` only once there is more than one app sharing code.
3. `/pkg` — only when the project genuinely publishes code for outside importers
   **and** the root is crowded. It is a contested pattern; default to
   `/internal`. Never place the same package under both.
4. `/api`, `/web`, `/configs`, `/init`, `/scripts`, `/build`, `/deployments`,
   `/test`, `/docs`, `/tools`, `/examples`, `/third_party`, `/githooks`,
   `/assets`, `/website` — each only when a file exists to go in it.
5. `/vendor` — only ever via `go mod vendor`. Never for a library.
6. `/src` — never create it. If one exists, report it as a finding.

Moving existing code: `git mv` so history follows, then fix import paths, then
`go build ./...` and `go test ./...`. Both must pass before you report done; if
either breaks, fix it or revert the move. Never leave the tree not building.

Copy in `assets/editorconfig` → `.editorconfig` and `assets/Makefile` →
`Makefile` if the repo has neither, substituting `MODULE_PATH` and `BINARY_NAME`.

## 2. `lint`

1. `golangci-lint version`. If it is missing or v1, print the pinned binary
   install command from `references/golangci-lint.md` for the user to run, and
   stop this mode. Do not `go install` it — upstream states that path is not
   guaranteed to work.
2. Existing config:
   - **v1** (no `version: "2"`): run `golangci-lint migrate`. Never hand-convert;
     v2 moved formatters out of `linters`, renamed keys, and changed defaults.
   - **v2**: do not clobber it. Compare against `assets/golangci.yml`, report
     what is missing, and apply only what the user asked for.
   - **none**: copy `assets/golangci.yml` → `.golangci.yml`, replace both
     `MODULE_PATH` occurrences with the module path, and set `run.go` from the
     `go` directive in `go.mod`.
3. `golangci-lint config verify`.
4. `golangci-lint run ./...`. Summarize as counts per linter — never paste the
   full report.
5. A large first-run count on an existing codebase is expected, not a crisis. Do
   not start fixing and do not water down the config. Report the count and the
   adoption path: gate CI on `--new-from-merge-base=origin/main` now, burn the
   backlog down separately.
6. Never silence a finding by deleting a linter from `enable` or by adding a
   blanket `//nolint`. A justified suppression names its linter and its reason.
7. If `.github/workflows/` exists with no lint workflow, add
   `assets/golangci-lint.yml`.

## 3. `fmt`

Read `references/gofumpt.md` first.

- **With golangci-lint present**, gofumpt belongs in the `formatters` block —
  one tool, one config, one CI step. It is already there in `assets/golangci.yml`.
  Run `golangci-lint fmt`, then confirm `golangci-lint fmt --diff` is silent.
- **Standalone**: `gofumpt -l .` to see the blast radius first, then
  `gofumpt -l -w .`.
- Leave the extra rules off on the first pass. `extra-rules` / `-extra` rewrites
  code rather than whitespace — naked returns, grouped parameters, balanced call
  parens — and belongs in its own commit.
- After reformatting: `go build ./...` and `go test ./...`.
- Report the editor snippet for the user's editor. For anything gopls-based it
  is one setting: `formatting.gofumpt: true`.
- Note the version-skew trap if both are in play: golangci-lint vendors its own
  gofumpt, which can trail the standalone binary. Pin both.

## 4. `audit`

Run every check above in read-only form. Create nothing, move nothing, format
nothing. Report: layout deviations, missing or v1 lint config, unformatted file
count (`gofumpt -l .`), and `//nolint` comments lacking a linter name or reason.

## 5. Report

Six short sections, omitting any that is empty:

1. **Context** — module path, Go version, package and file counts.
2. **Layout** — directories created or code moved, one line each.
3. **Lint** — config action taken, then findings as counts per linter.
4. **Format** — how gofumpt was wired in, and how many files were reformatted.
5. **Skipped** — every part of the standard layout you deliberately did not
   apply, each with its one-line reason. This section is not optional; it is
   what stops the next reader from re-litigating the same decisions.
6. **Next** — the exact commands to run, and anything needing a human decision.

Do not paste full lint output, full diffs, or the contents of the reference files.
