<!--
Go testing conventions, drawn from the standard library's own tests, the Go
blog, and the Google Go Style Guide. Bundled so this skill needs no network
access. Stdlib features are annotated with the release that introduced them.
-->

# Testing

## The default shape: table-driven with subtests

```go
func TestParse(t *testing.T) {
	t.Parallel()

	tests := map[string]struct {
		in      string
		want    Config
		wantErr error
	}{
		"empty input":     {in: "", wantErr: ErrEmpty},
		"trailing comma":  {in: "a,b,", want: Config{Keys: []string{"a", "b"}}},
	}

	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			t.Parallel()

			got, err := Parse(tc.in)
			if !errors.Is(err, tc.wantErr) {
				t.Fatalf("Parse(%q) error = %v, want %v", tc.in, err, tc.wantErr)
			}
			if diff := cmp.Diff(tc.want, got); diff != "" {
				t.Errorf("Parse(%q) mismatch (-want +got):\n%s", tc.in, diff)
			}
		})
	}
}
```

Why this shape:

- A `map` keyed by name makes duplicate cases a compile-time-adjacent error and
  removes the urge to number them. Iteration order is random, which is a
  feature: it catches cases that depend on each other. Use a slice only when the
  cases must run in a fixed order.
- One subtest per case means a failure names itself, and `-run
  'TestParse/trailing_comma'` re-runs exactly one.
- Failure messages state **what was called, what came back, what was wanted**,
  in that order, and always with `%q` for strings — otherwise a trailing space
  costs an hour.
- `t.Fatalf` when continuing would panic or produce noise; `t.Errorf` when the
  test can keep checking and report more in one run.

## Helpers the testing package already gives you

| Use | Instead of |
| --- | --- |
| `t.TempDir()` | `os.MkdirTemp` plus cleanup you will forget |
| `t.Setenv("K", "v")` | `os.Setenv` — never restores, and forbids `t.Parallel` |
| `t.Chdir(dir)` (1.24) | `os.Chdir` plus a deferred chdir back |
| `t.Context()` (1.24) | a hand-rolled context canceled in a defer |
| `t.Cleanup(fn)` | `defer` in a helper, which fires at the wrong time |
| `t.Helper()` | line numbers pointing at the assertion helper, not the test |

`usetesting` and `thelper` enforce the first four and the last one.

## Parallelism

- `t.Parallel()` on the top-level test *and* each subtest, unless the test uses
  `t.Setenv`, `t.Chdir`, or other process-global state — those two panic if the
  test is parallel, which is the correct design.
- Since 1.22 the loop variable is per-iteration, so the old `tc := tc` copy is
  dead code (`copyloopvar`).
- Parallel subtests run after the parent returns. Anything the parent defers is
  torn down *before* they run — use `t.Cleanup` in the subtest instead.
- `go test -shuffle=on` in CI. Order dependence between tests in a package is a
  bug that only appears when someone adds a test.

## Isolation and test doubles

- Black-box first: put the test in `package foo_test` and use only the exported
  API. It keeps the test honest about what the package promises, and it makes
  import cycles in test helpers impossible. Drop to the internal package only
  for something genuinely unreachable from outside.
- Prefer a hand-written fake to a generated mock. A fake is a real
  implementation of a small consumer-side interface, is readable, and does not
  encode call ordering that nobody actually requires.
- `net/http/httptest` for HTTP on both sides; `httptest.NewServer` beats
  intercepting the transport.
- `testing/synctest` (1.25) runs a test in a bubble with a fake clock, so code
  built on timers, `time.After`, and goroutine coordination becomes
  deterministic instead of `time.Sleep`-flavored.
- No `time.Sleep` as synchronization, anywhere. It is either a race the machine
  usually wins, or a slow test, and usually both.

## testdata and golden files

`testdata/` is ignored by the go tool, so fixtures live there. For large or
structured expected output, compare against a golden file and regenerate with a
flag:

```go
var update = flag.Bool("update", false, "rewrite testdata golden files")

got := render(input)
golden := filepath.Join("testdata", t.Name()+".golden")
if *update {
	if err := os.WriteFile(golden, got, 0o600); err != nil {
		t.Fatal(err)
	}
}
want, err := os.ReadFile(golden)
```

Golden files are reviewed in the diff like any other code. Regenerating without
reading the diff defeats the whole mechanism.

## Benchmarks and profiling

```go
func BenchmarkEncode(b *testing.B) {
	b.ReportAllocs()
	input := makeInput()
	for b.Loop() {        // 1.24: keeps input alive, excludes setup, no b.N
		Encode(input)
	}
}
```

- `b.Loop()` (1.24) replaces `for range b.N` and stops the compiler optimizing
  the call away; before 1.24, assign to a package-level sink.
- `b.ReportAllocs()` always — allocation counts are the stable signal;
  wall time on a shared CI runner is not.
- Compare runs with `benchstat`, not by eyeballing two numbers. A single run is
  not a measurement.
- `go test -run '^$' -bench . -cpuprofile cpu.out`, then `go tool pprof -http=:
  cpu.out`. Optimize what the profile shows, never what the code review guesses.

## Fuzzing

```go
func FuzzParse(f *testing.F) {
	f.Add("a,b")                    // seeds also run as regular unit tests
	f.Fuzz(func(t *testing.T, s string) {
		got, err := Parse(s)
		if err != nil {
			return
		}
		if _, err := Parse(got.String()); err != nil {
			t.Errorf("round trip failed for %q", s)
		}
	})
}
```

Worth writing for anything that parses untrusted input. Crashers are written to
`testdata/fuzz/` and become permanent regression cases — commit them.

## Coverage

- `go test -race -covermode=atomic -coverprofile=coverage.out ./...`.
  `atomic` is required with `-race`; the default `set` mode undercounts.
- `-coverpkg=./...` to attribute coverage from an integration test back to the
  packages it exercises.
- Read coverage as a map of what is untested, never as a target. A team chasing
  a percentage writes tests for getters and leaves the error paths bare — which
  is exactly backwards, since the error paths are the ones nobody ever runs by
  hand.

## Integration and slow tests

Guard them so the default `go test ./...` stays fast:

```go
//go:build integration
```

with `go test -tags integration ./...` in a separate CI job, or
`if testing.Short() { t.Skip("requires postgres") }` with `-short` locally.
Pick one convention per repo and apply it everywhere.

## Assertions

The standard library plus `github.com/google/go-cmp/cmp` covers almost
everything: `cmp.Diff` produces a readable diff, and `cmpopts` handles unexported
fields and float tolerance. `reflect.DeepEqual` compares nil and empty slices as
different and prints nothing useful on failure — prefer `cmp.Diff`.

`testify` is acceptable where it is already in use; enable `testifylint`, which
catches the swapped want/got arguments and `assert.Equal` on errors that make
its failures misleading. Do not mix both libraries in one package.

## Common causes of a flaky test

1. `time.Sleep` used as synchronization.
2. A hardcoded port instead of `:0` plus the listener's actual address.
3. Iterating a map and asserting on the order.
4. Shared package-level state between tests, exposed by `-shuffle=on`.
5. A parallel subtest reading something the parent tore down in a `defer`.
6. Real clocks, real DNS, or the real network in a unit test.
7. A goroutine started by the test with nothing waiting for it.

## Checklist

1. Table-driven with named subtests; failures name the case.
2. `t.Parallel()` everywhere it is safe; `-shuffle=on` in CI.
3. `t.TempDir`/`t.Setenv`/`t.Cleanup`/`t.Context` instead of manual setup.
4. Helpers call `t.Helper()`.
5. Error paths asserted with `errors.Is`/`errors.As`, not string matching.
6. Tests in `package foo_test` unless there is a reason not to.
7. No `time.Sleep`, no real network, no fixed ports.
8. `-race` in CI, `-covermode=atomic` alongside it.
9. Fuzz target for every parser of untrusted input.
10. Benchmarks report allocations and are compared with `benchstat`.
