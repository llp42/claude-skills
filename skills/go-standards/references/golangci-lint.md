<!--
golangci-lint v2 reference, distilled from https://golangci-lint.run and the
official JSON schema (golangci.v2.jsonschema.json). Current as of v2.13.2
(2026-08-27). Bundled so this skill needs no network access.
-->

# golangci-lint v2

Runs many Go linters in one pass, sharing a single load of the package graph.
Since v2 it also runs **formatters** (`golangci-lint fmt`), which is how gofumpt
gets wired in — see `gofumpt.md`.

## Install

Binary install is the supported path. Upstream explicitly warns that
`go install`, the tools pattern, and `tool` directives "aren't guaranteed to
work" — the build depends on your local Go version and can pull untested deps.

```bash
# Recommended: pinned binary
curl -sSfL https://golangci-lint.run/install.sh | sh -s -- -b "$(go env GOPATH)/bin" v2.13.2

# macOS
brew install golangci-lint

# Discouraged, but works
go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.13.2
```

If a project insists on pinning through the module graph, isolate it in its own
module file so it cannot drag your app's dependencies around:

```bash
go mod init -modfile=golangci-lint.mod <module>/golangci-lint
go get -tool -modfile=golangci-lint.mod github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.13.2
go tool -modfile=golangci-lint.mod golangci-lint run
```

## Commands

| Command | What it does |
| --- | --- |
| `golangci-lint run` | Lint. Directories are **not** recursive unless you append `/...`. |
| `golangci-lint fmt` | Run the enabled formatters (v2 only). |
| `golangci-lint migrate` | Rewrite a v1 config file as v2. |
| `golangci-lint config verify` | Validate the config against the JSON schema. |
| `golangci-lint config path` | Print which config file is actually being used. |
| `golangci-lint linters` | Linters enabled by the current config. |
| `golangci-lint formatters` | Formatters enabled by the current config. |
| `golangci-lint help linters` / `help formatters` | Everything available, with enabled/disabled status. |
| `golangci-lint cache clean` | Drop cached analysis results. |
| `golangci-lint custom` | Build a binary with custom/private linters compiled in. |

Useful `run` flags: `--fix`, `--diff`, `--new-from-rev`, `--new-from-merge-base`,
`--timeout`, `--config`, `--default`, `-E`/`-D` (enable/disable a linter),
`--enable-only`, `--fast-only`, `--show-stats`, `--path-prefix`,
`--allow-parallel-runners`, `--max-issues-per-linter`, `--max-same-issues`,
`--issues-exit-code`, `--output` (`text` `json` `tab` `html` `checkstyle`
`code-climate` `junit-xml` `teamcity` `sarif`).

Useful `fmt` flags: `--config`, `--no-config`, `-E`, `--diff`, `--diff-colored`, `--stdin`.

`--new-from-merge-base=origin/main` is the flag that makes adopting a strict
config survivable on an existing codebase: only newly-touched lines are reported.

## Config file schema

`.golangci.yml` (also `.yaml`, `.toml`, `.json`). Top-level keys, and nothing else:

```
version      # string, must be "2" — this is what selects the v2 schema
run          # what to analyze
linters      # which linters, their settings, and what to exclude
formatters   # which formatters, their settings, and what to exclude
issues       # how many issues to report, and diff-scoping
output       # report formats and paths
severity     # severity mapping
```

### `run`

`go` (targeted Go version, default `1.17` — set this), `timeout` (default `1m`),
`tests` (default `true`), `build-tags`, `concurrency`, `issues-exit-code`
(default `1`), `modules-download-mode` (`mod` | `readonly` | `vendor`),
`relative-path-mode` (default `wd`), `allow-parallel-runners`,
`allow-serial-runners`, `enable-build-vcs`.

### `linters`

```yaml
linters:
  default: standard   # standard | all | none | fast
  enable: [...]
  disable: [...]
  settings:           # per-linter config, keyed by linter name
    revive: {...}
  exclusions:
    generated: strict # strict | lax | disable
    warn-unused: false
    presets: [comments, std-error-handling, common-false-positives, legacy]
    paths: ["third_party/.*"]
    paths-except: [...]
    rules:
      - path: '_test\.go'
        linters: [dupl, funlen]
```

`default: standard` is the five linters that run with zero config: **errcheck,
govet, ineffassign, staticcheck, unused**. `default: all` enables everything and
is not a serious starting point — it contains mutually contradictory linters
(`nlreturn` vs `wsl`, `exhaustruct` vs almost every real struct literal).

An `exclusions.rules` entry needs at least one of `path`, `path-except`,
`linters`, `text`, `source`.

### `formatters`

Separate section from `linters`, same shape:

```yaml
formatters:
  enable: [gofumpt, goimports]   # gci | gofmt | gofumpt | goimports | golines | swaggo
  settings:
    gofumpt:
      module-path: github.com/you/proj
      extra-rules: false
      extra:                # granular alternative to extra-rules
        group-params: false
        clothe-returns: false
        balance-calls: false
    goimports:
      local-prefixes: [github.com/you/proj]
    gci:
      sections: [standard, default, prefix(github.com/you/proj), blank, dot, alias, localmodule]
      custom-order: true
      no-inline-comments: false
      no-prefix-comments: false
      no-lex-order: false
    golines:
      max-len: 100
      tab-len: 4
      shorten-comments: false
      reformat-tags: true
      chain-split-dots: true
  exclusions:
    generated: strict
    paths: [...]
    warn-unused: false
```

Pick **one** import organizer: `goimports` *or* `gci`, never both — they fight.
`gofumpt` composes with either.

### `issues`

`fix`, `max-issues-per-linter` (default 50), `max-same-issues` (default 3),
`uniq-by-line`, `whole-files`, `new`, `new-from-rev`, `new-from-merge-base`,
`new-from-patch`.

The default caps silently truncate reports. On a first run over an existing
codebase set both to `0` or you will fix 50 issues and think you are done.

### `output`

`formats` (`text` `json` `tab` `html` `checkstyle` `code-climate` `junit-xml`
`teamcity` `sarif`), `path-mode`, `path-prefix`, `show-stats`, `sort-order`.

## Migrating a v1 config

Do not hand-convert. v2 moved formatters out of `linters`, renamed
`linters.disable-all` to `linters.default: none`, moved `issues.exclude-*` to
`linters.exclusions.*`, dropped `linters.presets`, and changed several defaults
(`run.timeout`, `run.concurrency`, `issues.show-stats`, `run.relative-path-mode`,
`issues.exclude-generated`).

```bash
golangci-lint migrate                 # rewrites the config in place, keeps format
golangci-lint migrate --format yaml   # yml | yaml | toml | json
golangci-lint config verify           # confirm the result
```

`migrate` validates against the v1 schema first; `--skip-validation` bypasses that.
It also expands `linters.presets` into explicit `linters.enable` entries.

## Suppressing a finding

```go
//nolint:errcheck // the write can only fail if the buffer is full, checked above
```

Rules that keep `nolint` honest:

- Always name the linter. Bare `//nolint` disables everything on that line.
- Always give a reason after ` // `. The `nolintlint` linter enforces both, and
  is worth enabling for exactly that reason.
- Scope it to the narrowest line. A `//nolint` on a function declaration covers
  the whole function.
- Prefer an `exclusions.rules` entry when the exception is categorical (e.g.
  `dupl` in `_test.go` files). Reserve `//nolint` for genuine one-offs.

## Linters

115 available in v2.13.2:

```
arangolint asasalint asciicheck bidichk bodyclose canonicalheader clickhouselint
containedctx contextcheck copyloopvar cyclop decorder depguard dogsled dupl
dupword durationcheck embeddedstructfieldcheck errcheck errchkjson errname
errorlint exhaustive exhaustruct exhaustruct_v5 exptostd fatcontext forbidigo
forcetypeassert funcorder funlen ginkgolinter gocheckcompilerdirectives
gochecknoglobals gochecknoinits gochecksumtype gocognit goconst gocritic gocyclo
godoclint godot godox err113 goheader gomoddirectives gomodguard gomodguard_v2
goprintffuncname gosec gosimple gosmopolitan govet grouper iface importas
inamedparam ineffassign interfacebloat intrange iotamixing ireturn lll
loggercheck maintidx makezero mirror misspell mnd modernize musttag nakedret
nestif nilerr nilnesserr nilnil nlreturn noctx noinlineerr nolintlint
nonamedreturns nosprintfhostport paralleltest perfsprint prealloc predeclared
promlinter protogetter reassign recvcheck revive rowserrcheck sloglint
sqlclosecheck staticcheck stylecheck tagalign tagliatelle testableexamples
testifylint testpackage thelper tparallel unconvert unparam unused usestdlibvars
usetesting varnamelen wastedassign whitespace wrapcheck wsl wsl_v5 zerologlint
```

Ones worth knowing when tuning a config:

| Linter | Catches |
| --- | --- |
| `errcheck` | Unchecked errors. The single highest-value linter in Go. |
| `govet` | The `go vet` suite, including `shadow` and `fieldalignment` (opt-in via settings). |
| `staticcheck` | The SA/S/ST/QF checks; absorbed `gosimple` and `stylecheck`. |
| `unused` | Unused unexported identifiers. |
| `ineffassign` | Assignments never read. |
| `revive` | Configurable style/lint rules; the maintained successor to the dead `golint`. |
| `gocritic` | Broad diagnostic/style/performance checks, tunable by tag. |
| `gosec` | Security issues (weak crypto, command injection, unhandled `os.*` perms). |
| `errorlint` | `%v` on errors instead of `%w`, `==` comparison instead of `errors.Is`. |
| `bodyclose` / `sqlclosecheck` / `rowserrcheck` | Leaked HTTP bodies, SQL statements, unchecked `rows.Err()`. |
| `noctx` | Requests built without a `context.Context`. |
| `contextcheck` / `containedctx` / `fatcontext` | Context that is dropped, struct-embedded, or rebuilt in a loop. |
| `copyloopvar` | Pre-1.22 loop-variable capture workarounds now redundant. |
| `modernize` | Constructs with a newer stdlib equivalent (`min`, `max`, `slices`, `maps`). |
| `usetesting` | `os.Setenv`/`os.MkdirTemp` in tests where `t.Setenv`/`t.TempDir` exist. |
| `testifylint` | Misused testify assertions (swapped want/got, `Equal` on errors). |
| `nolintlint` | `//nolint` without a linter name or without a reason. |
| `depguard` | Imports you have banned by policy. |
| `wrapcheck` | Errors from other packages returned without wrapping. |

Deliberately noisy, opt in only with a reason: `exhaustruct`, `varnamelen`,
`ireturn`, `gochecknoglobals`, `nlreturn`, `wsl`, `lll`, `funlen`, `godox`,
`err113`, `dupl`, `cyclop`, `gocognit`, `maintidx`.

Deprecated aliases kept for compatibility: `gosimple` and `stylecheck` are now
part of `staticcheck`; `golint` is gone (use `revive`).

## CI

```yaml
name: golangci-lint
on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

jobs:
  golangci:
    name: lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-go@v6
        with:
          go-version: stable
      - uses: golangci/golangci-lint-action@v9
        with:
          version: v2.13
```

The action needs `pull-requests: read` as well if you use its `only-new-issues`
option. Pin `version:` — an unpinned linter turns an unrelated PR red the day a
new check ships.

Run the formatter check separately from the linter so a formatting failure is
distinguishable from a real finding:

```yaml
      - run: golangci-lint fmt --diff   # non-zero exit if anything is unformatted
```
