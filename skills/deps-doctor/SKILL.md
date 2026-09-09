---
name: deps-doctor
description: MUST be used whenever the user asks to audit dependencies for outdated versions or known vulnerabilities across the whole project (not just a diff). This complements the separate `deps-summary` skill, which only reports version deltas already present in a git diff — this one actively audits the current lockfile state regardless of any diff. Always invoke this instead of running npm/pip/cargo audit commands manually.
allowed-tools: Bash(npm outdated:*), Bash(npm audit:*), Bash(pip list:*), Bash(pip-audit:*), Bash(cargo outdated:*), Bash(cargo audit:*), Bash(go list:*), Bash(go version:*), Read
model: haiku
context: fork
agent: general-purpose
background: false
---

# deps-doctor

Audit project dependencies for outdated versions and known vulnerabilities. Report only — never modify files, install packages, or run upgrade commands.

## Steps

1. **Detect ecosystems** present in the project root by checking for these files:
   - `package.json` → npm/yarn/pnpm (JS/TS)
   - `requirements.txt` or `pyproject.toml` → pip (Python)
   - `Cargo.toml` → cargo (Rust)
   - `go.mod` → Go modules

2. **For each detected ecosystem**, run the applicable commands. If a tool isn't installed or a command errors, note it briefly for that ecosystem and continue — do not fail the whole report.
   - **JS/TS**: `npm outdated` and `npm audit --json`
   - **Python**: `pip list --outdated`; if `pip-audit` is available, also run `pip-audit`
   - **Rust**: `cargo outdated` if installed; `cargo audit` if installed
   - **Go**: `go list -u -m all` for outdated modules. Go has no built-in vuln scanner — skip vulnerability scanning unless `govulncheck` is present, and note that it was skipped.

3. **Parse output** into a compact plain-English report. For each flagged package include: name, current version, latest available version, and vulnerability severity (critical/high/medium/low) if flagged by an audit tool.

4. **Sort the report** so critical/high-severity vulnerabilities appear first, clearly marked (e.g. "⚠ HIGH", "⚠ CRITICAL"), followed by medium/low vulnerabilities, then plain outdated-version-only entries. Group by ecosystem if more than one is present.

5. **Do not modify any files or run any upgrade/install commands.** This skill only reports findings.
