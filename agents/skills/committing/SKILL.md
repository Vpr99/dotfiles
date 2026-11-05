---
name: committing
description: 'Formats scoped commit messages (scope: subject) with a structured progress footer. Loaded when making commits as part of task execution — used by implementing-tasks and any other skill that commits code.'
---

# Commit

Scoped commits, not Conventional Commits. The **scope** — the area of code that
changed — is the most useful thing in a log: it's what you scan for when catching
up, hunting a regression, or triaging an incident. The *type* (`feat`/`fix`/`chore`)
is noise: redundant (the subject already tells you what kind of change it is) and
restrictive (real changes are often part fix, part refactor, part feature). So
scope leads, and there is no type prefix.

## Message Structure

```
<scope>: <subject>

<body - what and why>

## Progress
- Task: <task ID and subject>
- Decisions: <key decisions and reasoning>
- Files: <files changed>
```

## Rules

- **Scope:** mandatory, lowercase, comes first. Use the project's natural unit of
  organization — package path (`net/http/cookiejar`), module/subsystem (`auth`,
  `storage`, `es-client`), or service name. Match whatever the surrounding git
  log already uses. Tree-wide change with no single area? Use `treewide:`.
- **Subject:** imperative mood, lowercase, no period, <72 chars. Write it so the
  *kind* of change is obvious without a type prefix.
- **Body:** explain *what* changed and *why* — not *how*. Wrap at ~72 cols.
- **Progress footer:** always include when working on a task. Omit only for
  trivial standalone commits (lint fixes, typos)
- **One logical change per commit** — don't bundle unrelated changes
- **Shared worktrees:** `git add` picks up other teammates' staged files —
  always use `git add <specific-files> && git commit -m "msg"`, never
  `git add .` or `git add -A`. Do NOT use `git commit -- <files> -m` —
  `--` terminates option parsing and git treats `-m` as a pathspec

## Examples

```
auth: reject tokens with a future-dated nbf claim
storage: batch object deletes to cut S3 round-trips
cli: add --dry-run flag to santactl sync
treewide: bump go module path to v2
```
