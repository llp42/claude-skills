<!--
Go modules, the toolchain, builds, and vulnerability scanning. Bundled so this
skill needs no network access. Behavior described here was checked against the
`go` command's own help output; features are annotated with the release that
introduced them.
-->

# Modules, toolchain, builds

## go.mod

```
module github.com/acme/widget      // the import path; the one thing that cannot be guessed

go 1.24                            // LANGUAGE version — gates syntax and stdlib symbols
toolchain go1.24.3                 // minimum toolchain that may build it (optional)

require (
	github.com/lib/pq v1.10.9
	golang.org/x/sync v0.10.0      // indirect
)

tool golang.org/x/vuln/cmd/govulncheck   // 1.24: a build-time tool dependency
```

- **`go` is not "the Go version installed"**, it is the language version the
  module is written against. Raise it deliberately: raising it lets new syntax
  in and drops support for every older toolchain. `stdversion` in `go vet`
  reports stdlib symbols newer than this line.
- **`toolchain`** pins the toolchain that actually builds, independent of the
  language version. With `GOTOOLCHAIN=auto` (the default) the go command
  downloads and uses it, so builds are reproducible across developer machines;
  `GOTOOLCHAIN=local` forces whatever is installed and fails loudly instead.
- **`// indirect`** means nothing in this module imports it directly. A large
  block of them is normal; a *direct* dependency marked indirect means `go mod
  tidy` has not run.
- **`replace`** is for local development and emergencies. It is ignored when the
  module is consumed as a dependency, so a `replace` that fixes a bug fixes it
  only for you. Never ship one on a released library; `gomoddirectives` can ban
  them.
- **`exclude`** skips a known-broken version. **`retract`** (in *your* module)
  tells consumers a version you published should not be used — the correct
  response to a bad release, better than deleting the tag.

## The commands that keep it honest

| Command | Use |
| --- | --- |
| `go mod tidy` | Add what is imported, drop what is not. Run before every commit that touches imports. |
| `go mod tidy -diff` | Same analysis, changes nothing, non-zero exit if it would. This is the CI check. |
| `go mod verify` | Confirm the module cache matches the hashes in go.sum. |
| `go mod why -m <mod>` | Which import chain drags a dependency in. |
| `go list -m -u all` | Available upgrades, without applying any. |
| `go get -u ./...` | Upgrade direct and indirect deps; follow with `tidy` and the tests. |
| `go get pkg@none` | Drop a dependency outright. |

`go.sum` is not a lockfile — `go.mod` already pins exact versions via minimal
version selection. `go.sum` records hashes. Commit both, never edit either by
hand, and never delete `go.sum` to "fix" a checksum mismatch: that error means
the content behind a version changed, which is the exact attack it exists to
catch. For private modules set `GOPRIVATE=github.com/acme/*`, which implies
`GONOPROXY` and `GONOSUMDB`.

## Tool dependencies (1.24+)

```bash
go get -tool golang.org/x/vuln/cmd/govulncheck
go tool govulncheck ./...
```

This records the tool in `go.mod`, versions it with the rest of the module, and
runs it without installing anything globally. It replaces the old `tools.go`
file with blank imports and a build tag. `go tool` with no arguments lists what
the module declares. Prefer this over `go run <pkg>@latest` in a Makefile —
`@latest` is a different tool on every machine and every day, and needs the
network.

## Major versions

Anything past v1 carries the major version in the import path:

```
module github.com/acme/widget/v2
```

Without the `/v2` suffix, consumers can never import v1 and v2 side by side, and
`go get` will refuse the upgrade. Tag `v2.0.0` and update every internal import
path in the same commit. Below v1 the compatibility promise does not apply, and
that is the honest place to be while the API is still moving.

## Workspaces

`go.work` (1.18) makes several modules resolve to each other locally without a
`replace`:

```bash
go work init ./api ./service
```

It is a developer convenience. Do not commit it in a repository that is consumed
as a library — it changes resolution for anyone who checks the repo out. Add it
to `.gitignore` unless the repo *is* the multi-module workspace.

## Vendoring

`go mod vendor` only, never a hand-edited `/vendor`. Once the directory exists
the go command uses it by default (`-mod=vendor`), so it must be regenerated and
committed with every dependency change or the build silently uses stale code.
Worth it for an air-gapped or audited build; a cost with no benefit for a
library.

## Building

```bash
go build -trimpath -ldflags '-s -w -X main.version=1.4.2' -o bin/app ./cmd/app
```

- `-trimpath` strips local filesystem paths from the binary. Required for a
  reproducible build, and it stops `/home/you/src/...` shipping to users.
- `-ldflags -X importpath.name=value` stamps a value into an existing
  **string** variable. It silently does nothing if the path, the name, or the
  type is wrong — print the version once after wiring it up.
- `-s -w` drop the symbol table and DWARF data: a smaller binary, but panics
  lose some detail and delve stops working. Skip both while debugging.
- `CGO_ENABLED=0` produces a static binary with no libc dependency — the right
  default for a container, and required for `FROM scratch`. It also disables
  cgo-dependent stdlib paths (the system resolver, `os/user`), which is usually
  what you want and occasionally is not.
- `GOOS`/`GOARCH` cross-compile with no toolchain install: `GOOS=linux
  GOARCH=arm64 go build ./cmd/app`.
- `-buildvcs` (default `auto`) stamps commit and dirty state into the binary.
  Read it, and the module versions, at runtime with `runtime/debug.ReadBuildInfo`
  — that is a version command with no linker flags at all.
- Build tags gate files, not functions: `//go:build linux && !purego` on the
  first line, before the package clause, followed by a blank line.

## govulncheck

```bash
go run golang.org/x/vuln/cmd/govulncheck@latest ./...   # source
go run golang.org/x/vuln/cmd/govulncheck@latest -mode=binary ./bin/app
```

It reports vulnerabilities in the Go vulnerability database that are **reachable
from your code**, using call-graph analysis — not every advisory that touches a
version range. That distinction is the whole point: a finding is a real code
path, so it deserves triage rather than a mechanical bump. It also flags
vulnerabilities in the *standard library* of the toolchain in use, which is the
most commonly missed class of Go CVE.

Findings come back in two tiers: called symbols (act on these) and imported-but-
unreachable modules (upgrade at leisure). Run it in CI as its own job, and on
release binaries with `-mode=binary` — that catches what was actually shipped,
including dependencies stripped at build time.

`gosec` and `govulncheck` do not overlap: `gosec` looks for insecure patterns you
wrote, `govulncheck` for known-vulnerable code you imported. Run both.

## Checklist

1. `go` directive raised deliberately, not to whatever is installed.
2. `go mod tidy -diff` passes in CI.
3. `go.mod` and `go.sum` both committed; no hand edits.
4. No `replace` directives on a published module.
5. Tools declared with `go get -tool`, not `@latest` in a Makefile.
6. `/v2`+ in the module path for any major version past v1.
7. Release builds use `-trimpath`; version stamped via `-ldflags -X` or
   `debug.ReadBuildInfo`.
8. `CGO_ENABLED=0` unless something genuinely needs cgo.
9. `govulncheck ./...` green, or every finding triaged in writing.
