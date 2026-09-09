---
name: flaky-detector
description: MUST be used whenever the user asks to detect flaky tests or check test stability by running the suite multiple times. Always invoke this instead of manually re-running tests yourself.
argument-hint: [test-command] [runs?]
allowed-tools: Bash(*test*:*), Bash(npm test:*), Bash(npm run:*), Bash(pytest:*), Bash(go test:*), Bash(cargo test:*), Read
model: haiku
context: fork
agent: general-purpose
background: false
---

Detect flaky tests by running the test suite multiple times and comparing results.

1. Determine the test command:
   - If `$1` is given, use it as the test command.
   - Otherwise auto-detect, in this order:
     - `package.json` has a `test` script -> use `npm test`
     - `pytest.ini` or `pyproject.toml` exists -> use `pytest`
     - `go.mod` exists -> use `go test ./...`
     - `Cargo.toml` exists -> use `cargo test`
   - If none found and no `$1` given, report that no test command could be detected and stop.

2. Determine number of runs: use `$2` if given as an integer, else default to 5.

3. Run the test command that many times in a row, one after another. Capture the full stdout/stderr of each run. Do NOT stop early if a run fails — always complete all configured runs.

4. For each run's output, parse individual test names and their pass/fail status, using best-effort text parsing appropriate to the detected framework's typical output (e.g. Jest/Mocha "✓ name" / "✗ name" or "PASS/FAIL", pytest "PASSED"/"FAILED" per test id, go test "--- PASS:"/"--- FAIL:" per test name, cargo test "test X ... ok/FAILED").

5. Aggregate results per test name across all runs:
   - If a test passed in all runs, or failed in all runs, it is NOT flaky.
   - If a test passed in some runs and failed in others, it IS flaky. Report it with its failure rate, e.g. "test_foo: 2/5 runs failed".

6. Output a final summary:
   - List each flaky test found with its failure rate.
   - If no flaky tests were found, state that plainly in one line (e.g. "No flaky tests detected across 5 runs.").
