---
name: standup-gen
description: MUST be used whenever the user asks for a daily standup update, activity summary, or "what did I do yesterday/this week" from git history. Always invoke this instead of manually running git log yourself.
argument-hint: [since]
allowed-tools: Bash(git log:*), Bash(git shortlog:*)
model: haiku
context: fork
agent: general-purpose
background: false
---

Generate a standup summary from git history.

1. Determine the time range: if `$1` is given, use it as the `--since` value (it may be a relative phrase like "yesterday" or "2 days ago", a date, or a git ref). If `$1` is empty, default to `--since=yesterday` (last 24h).

2. Get the current git user with `git config user.name`. Run:
   `git log --since=<range> --author=<current git user> --pretty=format:%ad%x09%s --date=short --no-merges`
   If this returns no commits, retry without `--author` (all authors). If that fallback is what produced results, note in the output: "No commits found for <user>; showing all authors instead."
   If there are still no commits, state plainly that no commits were found in the given range and stop.

3. Group the returned commit subjects by date (the date is the first tab-separated field).

4. Output terse standup-style bullets, one section per day (most recent first), each with a short list of bullets describing what was done. Base bullets strictly on the commit subject text — lightly rephrase for readability (e.g. drop conventional-commit prefixes, make it read naturally) but do not invent details, scope, or intent not present in the subject line.

5. Do NOT include a "planned next" or "blockers" section. Only report what was actually done, per git history.
