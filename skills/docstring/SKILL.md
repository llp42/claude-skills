---
name: docstring
description: MUST be used whenever the user asks to add, generate, or fill in missing docstrings/doc-comments for a file or symbol. Always invoke this instead of writing docstrings yourself.
argument-hint: [file] [symbol?]
allowed-tools: Read, Edit, Grep
model: haiku
context: fork
agent: general-purpose
background: false
---

Target file: $1
Symbol (optional, may be empty): $2

Steps:
1. Read the file at path $1.
2. Detect the file's language from its extension/syntax and identify that
   language's standard doc-comment convention (e.g. Python triple-quoted
   docstrings, JSDoc `/** */` for JS/TS, Rustdoc `///`, Godoc comments above
   the declaration, Javadoc, XML doc comments for C#, etc.).
3. If $2 is non-empty: find only the function/method/class named $2 in the
   file. If it already has a doc comment, leave it. If missing, add one.
   Do not touch any other symbol.
4. If $2 is empty: scan the whole file for functions, methods, and classes
   that have no doc comment (skip ones that already have one). Add one to
   each.
5. For each doc comment you add, base it strictly on what the code actually
   does — read the function body, parameter usage, and return statement(s).
   Do not guess intent beyond what the code shows. Include: a one- to
   two-sentence summary, each parameter (name + purpose inferred from
   usage), and the return value if any, using the target language's normal
   doc-comment tags/format (e.g. Args/Returns for Python, @param/@returns
   for JSDoc, etc.).
6. Only insert/edit comment text. Never change code logic, formatting of
   code lines, imports, or function signatures.
7. Use Grep first if the file is large, to locate function/class
   definitions efficiently, then Edit to insert each doc comment.
8. When done, report a short bullet list: which symbols got a new doc
   comment (with line numbers), and which were already documented and
   skipped.
