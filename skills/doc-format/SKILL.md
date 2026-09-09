---
name: doc-format
description: MUST be used whenever the user asks to clean up, fix, or reformat markdown/doc file structure (headers, links, TOC, list style, whitespace). Always invoke this instead of hand-editing markdown formatting yourself.
argument-hint: [file]
allowed-tools: Read, Edit, Grep, Glob
model: haiku
context: fork
agent: general-purpose
background: false
---

Clean up markdown formatting in the file at $1. Do not rewrite prose, change wording, or alter meaning — structure and formatting only.

Read the file, then fix:
1. Header levels — make them consistent and properly nested (no skipped levels, e.g. h2 straight to h4).
2. Links — fix broken/malformed markdown link syntax `[text](url)`; flag any link whose target file/anchor you cannot verify instead of guessing a fix.
3. Table of contents — if one exists, regenerate it to match the current headers (correct entries, order, and nesting). If none exists, do not add one.
4. List bullets — make bullet style consistent within each list (pick one of `-`, `*`, `+` and use it throughout; don't mix).
5. Trailing whitespace — remove trailing spaces/tabs at line ends.
6. Blank lines — collapse 3+ consecutive blank lines down to a single blank line.

Apply fixes with Edit. After editing, output a short bullet-point summary of exactly what was changed (or state that no issues were found).
