<!--
Distilled from Effective Go, Go Code Review Comments (go.dev/wiki/CodeReviewComments),
the Google Go Style Guide, and the Go standard library's own conventions.
Reproduced here so this skill needs no network access. Where those sources
disagree, the stricter rule wins and the reason is stated.

Stdlib features are annotated with the release that introduced them; check the
`go` directive in go.mod before recommending one.
-->

# Idiomatic Go

The review order below is deliberate: a naming nit is never worth raising ahead
of a leaked goroutine. Work down, stop when the budget runs out.

1. Errors — silently dropped or destroyed context
2. Concurrency and context — leaks, races, unbounded fan-out
3. API shape — what the package forces on its callers
4. Package structure — dependency direction, global state
5. Naming, comments, documentation

Never mix a style rewrite into a behavior change. Two commits.

## 1. Errors

**Wrap with the operation and the operand.** An error message is read as a
chain, so each layer adds exactly what the layer below could not know.

```go
// no — destroys the chain, errors.Is stops working
return fmt.Errorf("error: %v", err)

// no — "failed to" repeated at six layers is noise
return fmt.Errorf("failed to read config: %w", err)

// yes
return fmt.Errorf("read config %s: %w", path, err)
```

Message style: lowercase, no trailing punctuation, no capitalized first word
unless it is a proper noun. Exactly one `%w` per layer; `errors.Join` when
several independent failures must all survive (validation, cleanup).

**Handle an error once.** Log it or return it, never both — double-logging is
how one failure becomes six lines in the log with no extra information.

**Sentinel vs. typed, decided by what the caller needs:**

```go
var ErrNotFound = errors.New("not found")      // caller needs identity only

type ValidationError struct{ Field, Reason string }  // caller needs detail
func (e *ValidationError) Error() string { ... }
```

Compare with `errors.Is` and `errors.As`. Never `==` on a wrapped error, never
`strings.Contains(err.Error(), ...)` — that turns a message into an API.

**The typed-nil trap.** A nil pointer in a non-nil interface is not nil:

```go
func do() error {
    var e *MyError   // nil
    ...
    return e         // err != nil is TRUE at the caller
}
```

Return the literal `nil`. Never declare a concrete error type as the return type
of a function; return `error`.

**panic is for programmer error only.** `regexp.MustCompile` at package scope,
an unreachable default in a closed switch. A library never panics on bad input
from its caller — that is what the error return is for. Recover only at the top
of a goroutine you own or in a request handler, and re-panic anything you cannot
classify.

**A discarded error needs a reason.** `_ = f()` is a claim that the failure is
genuinely uninteresting; write the one-line comment that says why, or handle it.
`defer f.Close()` on a file opened for writing is a dropped write error — use a
named return and assign to it, or close explicitly and check.

## 2. Context

- `ctx context.Context` is the first parameter, always, and it is never stored
  in a struct field. A context is per-call, and a struct outlives the call.
- Never pass `nil`. `context.TODO()` marks wiring that is not finished;
  `context.Background()` is for `main` and tests.
- `ctx.Value` is for request-scoped data crossing an API boundary — a trace ID,
  an auth subject. Never for optional parameters or dependencies. The key is an
  unexported named type, never a bare string.
- Every `WithCancel` / `WithTimeout` / `WithDeadline` gets `defer cancel()` on
  the next line, including when the deadline is expected to fire.
- Set the deadline at the entry boundary (handler, cron tick, CLI invocation),
  not in each helper down the stack. Helpers inherit it.
- Check `ctx.Err()` inside loops that do real work between blocking calls;
  otherwise a canceled request keeps burning CPU.
- `context.WithoutCancel` (1.21) for cleanup that must outlive the request;
  `context.AfterFunc` (1.21) to hook cancellation.

## 3. Concurrency

**Never start a goroutine without knowing how it ends.** Every goroutine has an
owner that waits for it, and a reason it will return. "It exits when the process
does" is only acceptable in `main`.

```go
var wg sync.WaitGroup
wg.Go(func() { work(ctx) })   // 1.25; replaces Add/Done/defer
wg.Wait()
```

For fan-out where the first failure should cancel the rest, use
`golang.org/x/sync/errgroup`, and `g.SetLimit(n)` for bounded concurrency — an
unbounded `for ... { go ... }` over an input you do not control is a resource
exhaustion bug, not a performance win.

- **Channel ownership**: the sender closes, never the receiver, never twice.
  Declare direction in signatures (`chan<- T`, `<-chan T`) so the compiler
  enforces the role.
- **Unbuffered by default.** A buffer is a queue whose capacity you must be able
  to justify; `make(chan T, 1)` for a handoff that must not block a shutdown
  path is a reason, "it seemed faster" is not.
- Every blocking send or receive that can outlive its request needs a
  `select` with `<-ctx.Done()`.
- **Mutex**: zero value is ready to use, so no constructor. Keep it immediately
  above the fields it guards, with a comment naming them. Never embed one in an
  exported struct — that exports `Lock`/`Unlock` as API. Never copy a value
  containing one (`go vet copylocks`).
- Prefer the atomic types (`atomic.Int64`, `atomic.Pointer[T]`) over the loose
  `atomic.AddInt64` functions — the type makes the invariant unavoidable.
- `defer ticker.Stop()` / `timer.Stop()`. A leaked ticker keeps a goroutine and
  its captured state alive forever.
- `sync.Pool` only with a profile in hand. It is a GC hint, not a cache.
- No mutable package-level state. It is the same problem as a global variable in
  any other language, plus it makes tests order-dependent.
- `go test -race` is not optional, and it belongs in CI, not just locally.
  `testing/synctest` (1.25) makes concurrent code deterministically testable.

## 4. API design and interfaces

- **Accept interfaces, return concrete types.** The caller can always narrow;
  it can never widen.
- **The interface belongs to the consumer**, not the implementation. One to
  three methods. A ten-method interface is a package boundary drawn in the wrong
  place.
- Do not define an interface with exactly one implementation "so it can be
  mocked". Use the concrete type; extract the interface when a second
  implementation actually appears.
- Take `io.Reader` / `io.Writer` where streaming is plausible; `[]byte` and
  `string` force the whole payload into memory at every layer.
- Constructors return `(*T, error)` and a fully usable value — never a
  half-built struct with an `Init()` to call later. Better still, make the zero
  value useful (`bytes.Buffer`, `sync.Mutex`, `slog.Logger` handlers).
- More than three optional knobs: functional options. All-required: a config
  struct parameter. Never a constructor with seven positional arguments.
- No `GetFoo()`. The getter is `Foo()`; the setter is `SetFoo()`.
- Export the minimum. If it compiles under `internal/`, it belongs there — an
  exported identifier is a support commitment.
- Return early. The happy path stays at the left margin, error handling
  indents.
- More than four parameters, or two adjacent parameters of the same type that
  can be swapped without a compile error: use a struct.

## 5. Naming

- **Packages**: short, lowercase, one word, no underscores, no plurals. The name
  is part of every identifier it exports, so `chunk.New`, never
  `chunk.NewChunk`; `http.Server`, never `http.HTTPServer`.
- **Banned package names**: `util`, `common`, `helpers`, `misc`, `base`,
  `shared`, `models`. They have no boundary, so they collect everything and
  become the center of every import cycle. Name the package for what it
  provides.
- **Variables**: name length is proportional to scope. `i`, `r`, `b` inside
  three lines; `remainingBudget` across a forty-line function. A package-level
  identifier is read far from its declaration and gets a full name.
- **Receivers**: one or two letters, the same on every method of the type.
  Never `self`, never `this`.
- **Interfaces**: single-method interfaces take the `-er` suffix — `Reader`,
  `Formatter`, `Validator`.
- **Initialisms keep their case**: `userID`, `HTTPServer`, `ServeHTTP`,
  `parseURL`, `xmlHTTPRequest`. Never `Url`, `Id`, `Http`.
- **Errors**: sentinel values are `ErrFoo`, error types are `FooError`.
- **Constants** are MixedCaps like everything else. `MaxRetries`, never
  `MAX_RETRIES`.
- **Booleans** read as positive assertions: `IsValid`, `HasNext`, `CanRetry`.
  `notReady` produces `if !notReady`, which nobody parses correctly at speed.
- **Files**: lowercase, underscores only where meaningful. Beware the implicit
  build constraint — `cache_windows.go` compiles on Windows only, and
  `helpers_test.go` is a test file. A file named for a platform or `test` by
  accident silently disappears from the build.

## 6. Package and program structure

- Dependencies point one way: `cmd` → `internal/app` → domain packages. A
  domain package importing an app package is a layering inversion, and it is how
  import cycles start.
- An import cycle means the two packages are really one package, or a third
  package should hold the shared type. Never break it with an interface at a
  random midpoint.
- No `init()` that reads the network, the filesystem, flags, or the environment.
  `init()` runs before `main` can decide anything, including whether to run at
  all, and it cannot return an error.
- `main` is: parse configuration → construct dependencies → run → map the error
  to an exit code. Everything else lives in a package that can be tested.

```go
func main() {
    if err := run(context.Background(), os.Args[1:], os.Stdout); err != nil {
        fmt.Fprintln(os.Stderr, "myapp:", err)
        os.Exit(1)
    }
}

func run(ctx context.Context, args []string, stdout io.Writer) error {
    ctx, stop := signal.NotifyContext(ctx, os.Interrupt, syscall.SIGTERM)
    defer stop()
    ...
}
```

- `os.Exit` and `log.Fatal` never appear outside `main` — neither runs deferred
  functions, so both skip every flush, close, and unlock on the stack.
- Configuration is read at one place, validated once at startup, and passed
  down as values. Deep code reading `os.Getenv` is untestable and undiscoverable.
- Graceful shutdown: cancel the context, stop accepting work, wait for in-flight
  work with a bounded timeout, then exit.

## 7. Data: slices, maps, strings, time

- A nil slice is a usable empty slice. Return `nil`, not `[]T{}`, and never
  build an API where the caller must tell them apart.
- Preallocate when the length is known: `make([]T, 0, len(src))`. `make([]T,
  len(src))` followed by `append` is the classic double-length bug (`makezero`).
- A slice you did not allocate is aliased memory. `slices.Clone` before
  retaining or mutating it, and the same for a `[]byte` handed to you by a
  caller.
- Use `slices` and `maps` (1.21) rather than hand-rolled loops; `slices.SortFunc`
  with `cmp.Compare` for ordering. `min`, `max`, `clear` are builtins (1.21).
- Map iteration order is randomized deliberately. Any user-visible or
  test-asserted output over a map must sort its keys first.
- `strings.Builder` for concatenation in a loop; `+=` on strings is quadratic.
- `[]byte(s)` and `string(b)` copy. In a hot path use the mirrored API
  (`bytes.Contains` vs `strings.Contains`) instead of converting back and forth.
- Keep `time.Time` in UTC internally, compare with `Equal`, and express
  durations as `time.Duration` — an API taking `timeoutSeconds int` will be
  called with milliseconds eventually.
- Check numeric conversions at boundaries. `int64` → `int32` truncates silently
  (`gosec` G115).

## 8. Generics

Reach for a type parameter when the same algorithm or container is genuinely
identical across types and the alternative is `any` plus type assertions, or
code generation. Do not reach for one when an interface already expresses the
requirement, when there is a single call site, or when it only saves a
five-line function — a type parameter is permanent API surface and it degrades
inference at every call. Prefer the existing constraints (`cmp.Ordered`, `any`,
`comparable`) over inventing new ones.

## 9. Logging and observability

- `log/slog` (1.21) is the baseline. One logger, constructed in `main` and
  injected. A package-level logger in library code is global state.
- A constant message, with the variable parts as attributes:

```go
// no
slog.Info(fmt.Sprintf("user %s failed login from %s", id, ip))
// yes
slog.Info("login failed", "user_id", id, "remote_addr", ip)
```

- A library that returns an error does not also log it. The caller owns the
  decision about severity and destination.
- Levels mean something: Debug is developer detail, Info is a state change worth
  keeping, Warn is recoverable *and actionable*, Error is "the operation
  failed". There is no Fatal outside `main`.
- Never log secrets, tokens, or PII. Give types that carry them a `LogValue`:

```go
func (t Token) LogValue() slog.Value { return slog.StringValue("REDACTED") }
```

- Log an error once, at the boundary where it stops propagating, with the full
  wrapped chain intact.

## 10. Documentation

- Every exported identifier has a doc comment, and it starts with the
  identifier's name: `// Client sends requests to ...`.
- One package comment per package, in the file named after the package or in
  `doc.go` when it is long.
- Document the contract — what it guarantees, what it does with nil, whether it
  is safe for concurrent use — not the implementation.
- Runnable `Example` functions live in the `_test` package, are compiled, and
  are verified against their `// Output:` comment. They are better than prose.
- Deprecation is a paragraph of its own: `// Deprecated: use NewClient instead.`
- Comments explain why. The code already says what. Commented-out code is
  deleted; that is what version control is for.
- `//go:generate` sits next to what it generates, and generated files keep the
  standard `// Code generated ... DO NOT EDIT.` first line so tooling can skip
  them.

## Review checklist

Run down this list; each item is a real defect class, not a preference.

1. Every error either handled or wrapped with `%w` plus operation context.
2. No `err` compared with `==`, no error text matched with `strings.Contains`.
3. No error both logged and returned.
4. `ctx` first parameter everywhere; no context in a struct; every `cancel`
   deferred.
5. Every goroutine has an owner that waits for it and a path that ends it.
6. Fan-out over caller-controlled input is bounded.
7. No mutable package-level state; no `init()` with side effects.
8. Interfaces defined by the consumer, small, and returning concrete types.
9. No `os.Exit`/`log.Fatal`/`panic` outside `main` or genuine programmer error.
10. Slices retained from callers are cloned; maps sorted before output.
11. Exported identifiers documented, starting with their own name.
12. Nothing exported that could live under `internal/`.

## Sources

- Effective Go — https://go.dev/doc/effective_go
- Go Code Review Comments — https://go.dev/wiki/CodeReviewComments
- Google Go Style Guide — https://google.github.io/styleguide/go/
- Go Proverbs — https://go-proverbs.github.io/
- Organizing a Go module — https://go.dev/doc/modules/layout
