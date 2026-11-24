# claude-skills

My [Claude Code](https://claude.com/claude-code) skills and subagents, kept
under version control so they survive a machine rebuild and stay in sync.

Everything here is the portable part of `~/.claude`. Session state, caches,
transcripts, and credentials live in that directory too and are deliberately
excluded — see `.gitignore`.

## Layout

```
skills/<name>/SKILL.md     one directory per skill
skills/<name>/references/  bundled docs a skill reads on demand
skills/<name>/assets/      bundled files a skill copies into a project
agents/<name>.md           one file per subagent
```

## Skills

| Skill | What it does |
| --- | --- |
| `changelog` | Write changelog / release-notes entries from git history. |
| `commit` | Make a git commit, message included. |
| `csv-summary` | Profile a CSV — row/column counts, nulls, ranges, distributions. |
| `deps-doctor` | Audit the whole project's dependencies for outdated and vulnerable versions. |
| `deps-summary` | Summarize version bumps already present in a lockfile/manifest diff. |
| `doc-format` | Fix markdown structure — headers, links, TOC, list style, whitespace. |
| `docstring` | Add or fill in missing docstrings for a file or symbol. |
| `env-lint` | Check `.env` parity against `.env.example` by variable name only, never values. |
| `flaky-detector` | Find flaky tests by re-running the suite. |
| `go-standards` | Lay out a Go project, configure golangci-lint v2 and gofumpt, review Go for idiomatic practice, verify with vet/race/govulncheck. |
| `grilling` | Stress-test a plan or decision with relentless questioning. |
| `grill-me` | A relentless interview to sharpen a plan or design. |
| `lint-fix` | Run the project's linter/formatter and auto-fix. |
| `pr-storyteller` | Write a PR title, description, and test plan for the current branch. |
| `standup-gen` | Build a standup update from git history. |
| `test-gap` | Find changed lines in the current diff that lack test coverage. |

`deps-doctor` and `deps-summary` are complementary: one audits current lockfile
state regardless of any diff, the other only reports deltas already in a diff.

`go-standards` carries its own copies of the Standard Go Project Layout, the
golangci-lint v2 reference, the gofumpt rule set, and its own references for
idiomatic Go, testing, and modules/builds — so it works offline.

## Agents

Read-only, narrowly scoped subagents. Each exists to keep noisy output — grep
hits, branch listings, raw log lines — out of the main conversation.

| Agent | What it does |
| --- | --- |
| `branch-hygiene` | Report stale, merged, or orphaned branches. Never deletes. |
| `code-searcher` | Locate symbols and references, returning compact `file:line` hits. |
| `error-log-triage` | Group and count recurring errors in a log by signature. |
| `secret-guard` | Scan for secrets, keys, and tokens without echoing them. |
| `todo-scanner` | Find and triage TODO/FIXME/HACK/XXX markers. |

## Install

Symlink into `~/.claude` so edits here take effect immediately:

```bash
git clone git@github.com:llp42/claude-skills.git
cd claude-skills
ln -s "$PWD/skills" ~/.claude/skills
ln -s "$PWD/agents" ~/.claude/agents
```

Move any existing `~/.claude/skills` and `~/.claude/agents` out of the way
first — `ln -s` will not replace a directory.

## License

SQLite Blessing (`blessing`). See `LICENSE`.
