---
name: go-standards
description: MUST be used whenever the user asks to structure or scaffold a Go project (cmd/internal/pkg layout), set up or migrate golangci-lint, enforce strict formatting with gofumpt, review Go code against idiomatic Go practice, or verify a Go module (vet, race tests, go mod tidy, govulncheck). Always invoke this instead of inventing a Go directory tree, hand-writing a .golangci.yml, or reviewing Go from memory.
argument-hint: [layout|lint|fmt|review|verify|audit] [module-path?]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(go:*), Bash(golangci-lint:*), Bash(gofumpt:*), Bash(gofmt:*), Bash(govulncheck:*), Bash(ls:*), Bash(mkdir:*), Bash(cp:*), Bash(git status:*), Bash(git mv:*), Bash(git remote:*), Bash(git log:*), Bash(git diff:*), Bash(git merge-base:*)
model: sonnet
context: fork
agent: general-purpose
background: false
---

Target: $ARGUMENTS. The first word selects the mode. If it is absent or is not
one of the six below, run `audit`, then `layout`, `lint`, `fmt`, `verify`, in
that order. `review` runs only when named: it is a reading task with a different
output, and it is worth nothing on a tree that does not build.

| Mode | Does |
| --- | --- |
| `layout` | Shape the directory tree to the Standard Go Project Layout. |
| `lint` | Install, configure, migrate, and run golangci-lint v2. |
| `fmt` | Wire up gofumpt and reformat. |
| `review` | Review Go code against idiomatic Go practice. Findings, not rewrites. |
| `verify` | Build, vet, race-test, `go mod tidy -diff`, govulncheck. |
| `audit` | Report findings only. Create, move, and modify nothing. |

Everything needed is bundled in this skill's directory. Never fetch it from the
network, and never state anything about a config key, linter name, formatting
rule, or Go convention without reading the file first:

| File | Holds |
| --- | --- |
| `references/project-layout.md` | The Standard Go Project Layout, verbatim from upstream. |
| `references/layout-directories.md` | Per-directory notes; the source for each new directory's `README.md`. |
| `references/golangci-lint.md` | v2 config schema, all 115 linters, CLI, CI, `nolint`, v1→v2 migration. |
| `references/gofumpt.md` | Every added rule with before/after, flags, editor setup. |
| `references/idiomatic-go.md` | Errors, context, concurrency, API shape, naming, docs — with a review checklist. |
| `references/testing.md` | Table-driven tests, parallelism, golden files, benchmarks, fuzzing, coverage. |
| `references/modules-and-builds.md` | go.mod directives, toolchain, tool deps, build flags, govulncheck. |
| `assets/golangci.yml` | Strict v2 config, validated against the official JSON schema. |
| `assets/golangci-lint.yml` | GitHub Actions workflow: lint and format check. |
| `assets/go-ci.yml` | GitHub Actions workflow: build, vet, race tests, coverage, govulncheck. |
| `assets/Makefile` | `fmt` / `vet` / `lint` / `test` / `bench` / `vuln` / `verify` targets. |
| `assets/editorconfig` | Tabs for Go, spaces for everything else. |

## Rules that hold in every mode

1. **Never leave the tree not building.** `go build ./...` and `go test ./...`
   pass before you report done, or you revert what you did.
2. **Never silence a finding to make a step green** — not by deleting a linter,
   not by a blanket `//nolint`, not by dropping `-race`, not by deleting a test.
   A justified suppression names its linter and its reason.
3. **Style and behavior are two commits.** A reformat mixed into a logic change
   is unreviewable.
4. **Report counts, not dumps.** Never paste full lint output, full diffs, or
   the contents of a reference file.
5. **Do not widen the ask.** A request to fix formatting is not permission to
   restructure the tree.

## 0. Context — always, before any mode

Gather, without commentary: module path, `go` directive, and `toolchain` line
from `go.mod`; the number of `.go` files and packages (`go list ./...`); which
layout directories already exist; whether any `.golangci.{yml,yaml,toml,json}`
is present and whether it declares `version: "2"`; whether `main` packages
exist; whether the working tree is clean.

No `go.mod`: derive the module path from `git remote get-url origin`, else from
the second word of $ARGUMENTS, then `go mod init <path>`. If neither is
available, stop and say so — the module path is the one thing that cannot be
guessed, and everything downstream encodes it.

A dirty working tree before a mode that moves or rewrites files: say so and let
the user decide before touching anything. `git mv` and a reformat are hard to
untangle from uncommitted work.

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
   `main` stays small: parse flags, wire dependencies, call into a package. The
   shape to aim for is in `references/idiomatic-go.md` §6.
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

Package names carry the same weight as the tree: reject `util`, `common`,
`helpers`, `misc`, `shared`, `models` as directory names and say why
(`references/idiomatic-go.md` §5) rather than creating them.

Moving existing code: `git mv` so history follows, then fix import paths, then
`go build ./...` and `go test ./...`. Both must pass before you report done; if
either breaks, fix it or revert the move.

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
3. `golangci-lint config verify`, then **one real `golangci-lint run`**. Verify
   only checks the config against the JSON schema; it accepts any string in
   `enable`, so a removed linter name (`gosimple`, `interfacer`) passes verify
   and aborts the run.
4. Summarize `golangci-lint run ./...` as counts per linter — never the full
   report.
5. A large first-run count on an existing codebase is expected, not a crisis. Do
   not start fixing and do not water down the config. Report the count and the
   adoption path: gate CI on `--new-from-merge-base=origin/main` now, burn the
   backlog down separately.
6. If `.github/workflows/` exists with no lint workflow, add
   `assets/golangci-lint.yml`; with no build/test workflow, add
   `assets/go-ci.yml`.

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

## 4. `review`

Read `references/idiomatic-go.md` and `references/testing.md` first. Review
against what those files say, not from memory.

**Scope it, and say what you scoped to.** In order of preference: the paths named
in $ARGUMENTS; else the diff against the merge base
(`git diff --name-only $(git merge-base HEAD origin/main)`); else the packages
containing uncommitted changes. Never review an entire repository unprompted —
an unscoped review produces a list nobody reads.

**Run the linter first if it is configured.** Anything golangci-lint already
catches is the linter's job. Reporting it again buries the findings that
actually need a human, which are the ones no analyzer can see: a goroutine with
no owner, an interface drawn at the wrong boundary, a package named for nothing.

Order findings by the severity ladder at the top of `references/idiomatic-go.md`
— errors, then concurrency and context, then API shape, then structure, then
naming and docs. Within a class, order by blast radius: an exported API problem
outranks an internal one, because only one of them is still fixable next month.

Each finding is four things and no more:

```
internal/store/pg.go:88 — rows.Err() never checked; a partial scan reads as success
  rule: idiomatic-go.md §1, handle an error once and never drop it
  fix:  check rows.Err() after the loop and wrap it with the query name
```

- Read the code around every finding before reporting it. A grep hit is a
  candidate, not a defect, and a confidently-reported false positive costs more
  trust than the finding was worth.
- Collapse repeats: one finding, with a count and the worst example, beats
  forty identical lines.
- Cap the report at roughly fifteen findings. Beyond that, report the classes
  and their counts, and say which class to fix first.
- Say what is good, in one line, if it genuinely is. A review that only ever
  finds fault gets read as noise.
- **Findings, not rewrites.** Change code only when the user asks for fixes,
  and then one concern per commit.

## 5. `verify`

Run in this order, and stop at the first step that fails — a vet finding on a
tree that does not compile is noise:

1. `go build ./...`
2. `go vet ./...` — the installed toolchain's analyzer set, which is newer than
   the one golangci-lint vendors.
3. `go test -race -shuffle=on ./...` — `-race` is the point of running tests at
   all in CI; `-shuffle=on` exposes order dependence between tests.
4. `go mod tidy -diff` — non-zero exit means `go.mod`/`go.sum` are stale.
   Report it; run plain `go mod tidy` only if the user asked to fix.
5. `govulncheck ./...`, or `go run golang.org/x/vuln/cmd/govulncheck@latest ./...`
   if it is not installed. Read `references/modules-and-builds.md` before
   interpreting the output: findings split into symbols actually called (act on
   these) and modules merely imported (upgrade at leisure), and stdlib
   vulnerabilities are fixed by moving the toolchain, not a dependency.

Report each step as pass/fail with a count, and for each failure a one-line
diagnosis — not the raw output. A failure is never fixed by removing the check.

## 6. `audit`

Run every check above in read-only form. Create nothing, move nothing, format
nothing, install nothing. Report: layout deviations, missing or v1 lint config,
unformatted file count (`gofumpt -l .`), `//nolint` comments lacking a linter
name or reason, `go mod tidy -diff` staleness, whether CI runs lint, race tests,
and govulncheck at all, and the top three findings a `review` would raise.

## 7. Report

Eight short sections, omitting any that is empty:

1. **Context** — module path, Go version, package and file counts.
2. **Layout** — directories created or code moved, one line each.
3. **Lint** — config action taken, then findings as counts per linter.
4. **Format** — how gofumpt was wired in, and how many files were reformatted.
5. **Review** — findings in severity order, in the four-line form above.
6. **Verify** — build, vet, test, tidy, govulncheck, each pass/fail.
7. **Skipped** — every part of the standard layout, config, or check you
   deliberately did not apply, each with its one-line reason. This section is not
   optional; it is what stops the next reader from re-litigating the same
   decisions.
8. **Next** — the exact commands to run, and anything needing a human decision.
