---
name: wt
description: Drive the `wt` git-worktree CLI to create, list, check out, remove, and clean worktrees in wt's envelope layout (a `repo/` checkout beside a `worktrees/` dir). Use when the user wants to spin up, switch into, or tear down a git worktree, work on a branch in isolation, or mentions `wt`, `wt new`, `wt checkout`/`co`, `wt ls`, `wt rm`, `wt clean`, or `wt prune`.
---

# wt — git worktree manager

`wt` manages worktrees inside a project _envelope_ and resolves it from the cwd,
so every command works from the main checkout, from inside a worktree, or from
the envelope root — no `cd`-ing to the main checkout first.

```
<envelope>/
├── repo/                 # main checkout (conventionally "repo")
└── worktrees/
    └── <branch>/         # one worktree per branch (nested dirs for feature/foo)
```

## The one gotcha: wt can't cd your shell

A subprocess can't change its parent's directory, so `wt new` and `wt checkout`
print `→ Next: cd <abs-path>` instead of moving you. To actually land in the
worktree, capture that path and run the `cd` yourself before working there:

```bash
wt new my-feature           # prints: → Next: cd /…/worktrees/my-feature
cd /…/worktrees/my-feature  # cd persists across later Bash calls
```

## Commands

| Command | What it does |
| --- | --- |
| `wt new [--from <ref>] <name>` | Branch `<name>` off main (or `--from`) + worktree at `worktrees/<name>`. Pulls main first. Errors if the path exists → use `checkout`. |
| `wt checkout <branch>` (`co`) | Land in `<branch>`'s worktree: create it if missing, else `git pull` the existing one. |
| `wt ls` (`list`) | List worktrees: main first, then alphabetical. `●` current, `*` dirty, `! relpath → branch` misplaced. `-v`/`--paths` appends abs paths. |
| `wt rm [<name>…]` (`remove`) | Remove worktrees by name; branches survive for a later `checkout`. No args → interactive picker (needs a TTY). Refuses the worktree you're in. |
| `wt clean [-y] [-n]` | Remove worktrees whose PRs merged (via `gh`) and delete their branches. `-n` dry-run, `-y` skip confirm. The only command that deletes branches. |
| `wt prune` | `git worktree prune` — clear stale metadata after a manual `rm`. |

## Running non-interactively (you, in a Bash tool)

- **`wt ls`** auto-switches to tab-separated porcelain when stdout isn't a TTY:
  columns `name  branch  dirty  path`, no color or markers. Parse that, not the
  styled view. (`--porcelain` forces it even in a terminal.)
- **`wt rm`** with no args opens a picker that _needs a terminal_ and refuses
  otherwise — always pass explicit names: `wt rm foo bar`.
- **`wt clean`** prompts to confirm unless `-y`, and the prompt needs a TTY. Use
  `wt clean -n` to preview safely; `wt clean -y` to proceed unattended
  (destructive — removes worktrees and deletes branches). Requires `gh` on PATH.
- Add `--debug` to any command for a stack trace instead of the one-line error.

## `--from` semantics (wt new)

- omitted → branch off freshly-pulled `main`
- `--from origin/x` → fetch, then base on `origin/x`
- `--from x` where `x` is a local branch → base on it, no fetch
- `--from x` where `x` isn't local → fetch, base on `origin/x`

## Workflows

- **Start a feature:** `wt new feat-x`, then `cd` into the printed path and work.
- **Resume a branch (yours or a teammate's):** `wt co branch-name`, then `cd` in.
  Creates the worktree from origin if you don't have one yet; pulls it if you do.
- **Survey:** `wt ls` (use `-v` for paths). Watch for `*` dirty and `!` misplaced.
- **Tear down after merge:** `wt clean -n` to preview, then `wt clean` (or `-y`).
- **Drop one worktree, keep its branch:** `cd` to main, then `wt rm <name>`.
- **Stale metadata after a manual `rm -rf`:** `wt prune`.

## Notes

- A pull that has no upstream or would clobber local changes soft-warns (`⚠`) and
  proceeds — it never aborts `new`/`checkout`.
- `--separate-git-dir` and bare-only layouts are unsupported (clear error, exit 1).
- No `--version` flag — confirm it's installed with `wt --help` or `wt ls`.
