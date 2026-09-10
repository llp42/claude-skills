<!--
gofumpt reference, distilled from https://github.com/mvdan/gofumpt (README.md,
current as of v0.12.0, 2026-09-07). Bundled so this skill needs no network access.
-->

# gofumpt

A stricter `gofmt`. gofumpt accepts a strict *subset* of what gofmt accepts, so
running `gofmt` after `gofumpt` produces no changes — it never fights the
standard formatter, it only removes choices gofmt left open.

It is a fork of `gofmt` as of Go 1.27.0 and requires Go 1.26 or later. It vendors
frozen copies of `go/printer` and `go/doc/comment`, so a pinned gofumpt version
formats identically no matter which Go toolchain runs it. That is the property
that makes it safe in CI.

```bash
go install mvdan.cc/gofumpt@latest
gofumpt -l -w .
```

`vendor` and `testdata` directories are skipped unless passed as explicit
arguments, as are `ignore` directives in `go.mod`. The added rules do not apply
to generated files unless those files are named explicitly.

## Flags

```
-l          list files whose formatting differs
-w          write the result back to the file
-d          print diffs instead of rewriting
-e          report all errors, not just the first 10 on distinct lines
-extra      enable the extra rules (see below); also -extra=group_params,clothe_returns
-lang  str  target Go version, "go1.X" (default: from go.mod)
-modpath str  module path containing the source (default: from go.mod)
-version    print version and exit
```

`-r` is gone — use `gofmt -r` for rewrites. `-s` is hidden because
simplification is always on.

`-lang` and `-modpath` matter: the octal-literal rule is gated on Go 1.13+, and
import grouping needs the module path to tell first-party from third-party. Both
default correctly from `go.mod`, so only set them when formatting outside a module.

## Added rules

Each block is before → after.

**No newline after a simple assignment's operator**

```go
foo :=
    "bar"
```
```go
foo := "bar"
```

**No empty lines around function bodies**

```go
func foo() {

	println("bar")

}
```
```go
func foo() {
	println("bar")
}
```

**Functions separate `) {` where the indentation helps readability**

```go
func foo(s string,
	i int) {
	println("bar")
}
```
```go
func foo(s string,
	i int,
) {
	println("bar")
}
```

**No empty lines around a lone statement (or comment) in a block**

```go
if err != nil {

	return err
}
```
```go
if err != nil {
	return err
}
```

**No empty lines before a simple error check**

```go
foo, err := processFoo()

if err != nil {
	return err
}
```
```go
foo, err := processFoo()
if err != nil {
	return err
}
```

**Composite literals use newlines consistently** — a newline anywhere forces
newlines for the braces and between every element.

```go
var ints = []int{1, 2,
	3, 4}

var matrix = [][]int{
	{1},
	{2}, {
		3,
	},
}
```
```go
var ints = []int{
	1, 2,
	3, 4,
}

var matrix = [][]int{
	{1},
	{2},
	{
		3,
	},
}
```

**Empty field lists use a single line**

```go
var V interface {
} = 3

type T struct {
}

func F(
)
```
```go
var V interface{} = 3

type T struct{}

func F()
```

**`std` imports go in a separate group at the top**

```go
import (
	"foo.com/bar"

	"io"

	"io/ioutil"
)
```
```go
import (
	"io"
	"io/ioutil"

	"foo.com/bar"
)
```

**Short case clauses take a single line**

```go
switch c {
case 'a', 'b',
	'c', 'd':
}
```
```go
switch c {
case 'a', 'b', 'c', 'd':
}
```

**Multiline top-level declarations are separated by empty lines**

```go
func foo() {
	println("multiline foo")
}
func bar() {
	println("multiline bar")
}
```
```go
func foo() {
	println("multiline foo")
}

func bar() {
	println("multiline bar")
}
```

**Single var declarations are not grouped with parentheses**

```go
var (
	foo = "bar"
)
```
```go
var foo = "bar"
```

**Contiguous top-level declarations are grouped together**

```go
var nicer = "x"
var with = "y"
var alignment = "z"
```
```go
var (
	nicer     = "x"
	with      = "y"
	alignment = "z"
)
```

**Simple var-declaration statements use short assignments**

```go
var s = "somestring"
```
```go
s := "somestring"
```

**`-s` simplification is always on**

```go
var _ = [][]int{[]int{1}}
```
```go
var _ = [][]int{{1}}
```

**Octal literals use the `0o` prefix** (modules on Go 1.13+)

```go
const perm = 0755
```
```go
const perm = 0o755
```

**Non-directive comments start with whitespace**

```go
//go:noinline

//Foo is awesome.
func Foo() {}
```
```go
//go:noinline

// Foo is awesome.
func Foo() {}
```

**Composite literals have no leading or trailing empty lines**

```go
var _ = []string{

	"foo",

}
```
```go
var _ = []string{
	"foo",
}
```

**Field lists have no leading or trailing empty lines**

```go
type Person interface {

	Name() string

	Age() int

}
```
```go
type Person interface {
	Name() string

	Age() int
}
```

**Definitely useless parentheses are removed**

```go
type C chan (int)

var _ = f((3))
```
```go
type C chan int

var _ = f(3)
```

Parens around binary/unary expressions, and around types that require them
(`chan (<-chan T)`), are left alone.

## Extra rules, behind `-extra`

Off by default. Enable all with `-extra`, or individually with
`-extra=group_params,clothe_returns,balance_calls`.

**`group_params` — adjacent parameters of the same type are grouped**

```go
func Foo(bar string, baz string) {}
```
```go
func Foo(bar, baz string) {}
```

**`clothe_returns` — no naked returns**

```go
func Foo() (err error) {
	return
}
```
```go
func Foo() (err error) {
	return err
}
```

**`balance_calls` — a multi-line call opened at end of line closes at start of line**

```go
result := compute(
	a,
	b,
	c)
```
```go
result := compute(
	a,
	b,
	c,
)
```

These three are the only rules that change program text rather than whitespace
(`clothe_returns` in particular). They are also the ones most likely to produce a
large first-run diff on an existing codebase — land them in a separate commit.

## Wiring it in

### Through golangci-lint (preferred when it is already in the project)

One tool, one config, one CI step. See `golangci-lint.md`.

```yaml
formatters:
  enable:
    - gofumpt
    - goimports
  settings:
    gofumpt:
      module-path: github.com/you/proj
      extra-rules: false
      extra:
        group-params: false
        clothe-returns: false
        balance-calls: false
```

```bash
golangci-lint fmt          # rewrite
golangci-lint fmt --diff   # check only; non-zero exit if unformatted
```

Caveat: golangci-lint vendors a specific gofumpt version, which can trail the
standalone release. If a developer's `gofumpt` binary and CI's `golangci-lint fmt`
disagree, that version skew is the reason — pin both.

### Standalone

```bash
gofumpt -l .        # check: prints the offending files, empty output means clean
gofumpt -l -w .     # rewrite
gofumpt -d .        # review the diff first
```

### Editors

All the gopls-based editors share one switch: gopls has gofumpt support built in,
and using it is better than shelling out to the binary on save.

VS Code — `settings.json`:
```json
"go.useLanguageServer": true,
"gopls": { "formatting.gofumpt": true }
```

Neovim (`lspconfig`):
```lua
require('lspconfig').gopls.setup({
    settings = { gopls = { gofumpt = true } }
})
```

vim-go:
```vim
let g:go_fmt_command="gopls"
let g:go_gopls_gofumpt=1
```

govim: `call govim#config#Set("Gofumpt", 1)`

Emacs, lsp-mode ≥ 8.0.0: `(setq lsp-go-use-gofumpt t)`

Emacs, eglot:
```elisp
(setq-default eglot-workspace-configuration
 '((:gopls . ((gofumpt . t)))))
```

Helix — `~/.config/helix/languages.toml`:
```toml
[language-server.gopls.config]
"formatting.gofumpt" = true
```

Sublime Text (LSP package): `"initializationOptions": { "gofumpt": true }` plus
`"lsp_format_on_save": true`.

Zed:
```json
"lsp": { "gopls": { "initialization_options": { "gofumpt": true } } }
```

GoLand does not use gopls. Add a File Watcher: Custom Template, file type `.go`,
scope Project Files, program `gofumpt`, arguments `-w $FilePath$`, output path to
refresh `$FilePath$`, working directory `$ProjectFileDir$`, environment
`GOROOT=$GOROOT$;GOPATH=$GOPATH$;PATH=$GoBinDirs$`. Disable everything under
*Advanced* to avoid redundant runs.

## Two things that trip people up

**"My module's imports are grouped with the standard library."** Import paths
without a dot in the first segment are reserved by the Go toolchain, so gofumpt
treats them as stdlib. Give the module a domain-ish path (`foo.local/mod` is
enough). For backwards compatibility gofumpt also treats anything sharing a
prefix with the current module path as third-party — which is why `-modpath` /
`go.mod` needs to be correct.

**"I already use goimports."** They do different jobs: goimports adds and removes
imports, gofumpt formats. Let the editor's language server handle imports and use
gofumpt for formatting, or chain them: `goimports file.go && gofumpt file.go`.
Under golangci-lint, enable both formatters — the ordering is handled for you.

**Reporting a formatting bug**: insert a `//gofumpt:diagnose` comment and run
gofumpt; the comment is rewritten in place with the version and flags actually in
effect.
