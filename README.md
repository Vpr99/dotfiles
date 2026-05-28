# dotfiles

Zero → hero macOS setup. One `brew bundle` + a few scripts reproduce the machine.

## New machine

```sh
git clone <this-repo> ~/code/personal/dotfiles
cd ~/code/personal/dotfiles
./install.sh
```

`install.sh` runs, in order:

1. **`scripts/bootstrap.sh`** — Xcode CLT, Homebrew, then `brew bundle` (all CLIs + apps).
2. **`scripts/link.sh`** — symlinks fish / git / Claude config into place (backs up anything it replaces to `*.bak-<timestamp>`).
3. **`scripts/runtimes.sh`** — sets fish as the default shell, enables corepack, installs `ruff`, starts Postgres.
4. **`macos.sh`** — system defaults (prompts y/N).

## Before you wipe the old machine

```sh
./scripts/backup-vscode.sh   # snapshots VS Code settings + extensions into ./vscode
git add -A && git commit && git push
```

VS Code is deliberately **not** in the Brewfile (you said: back it up, don't necessarily reinstall). Restore later with `./scripts/restore-vscode.sh` after installing VS Code.

## Layout

```
Brewfile              all packages + apps (parked extras are commented)
install.sh            orchestrator
macos.sh              system defaults (reconciled to the real machine)
scripts/
  bootstrap.sh        brew install + bundle
  link.sh             symlink dotfiles
  runtimes.sh         shell, package managers, services
  backup-vscode.sh    run on OLD mac
  restore-vscode.sh   optional restore
config/
  fish/               config.fish + functions (claude, wt-* worktree helpers)
  git/                gitconfig (+ work/personal identity splits) + global ignore
claude/               CLAUDE.md, settings.json, commands/, statusline scripts
agents/skills/        ~45 agent skills (symlinked to ~/.agents/skills + ~/.claude/skills)
vscode/               backed-up VS Code config (not auto-installed)
```

## Bootstrap order (the chicken-and-egg)

1Password is the keystone — it holds your SSH keys **and** your commit-signing key (there are no private keys on disk; `~/.ssh/config` just points at its agent). So:

1. **Install 1Password first** (download from 1password.com), sign in, and enable
   **Settings → Developer → Use the SSH agent**.
2. **Clone this repo.** If it's private, clone over HTTPS and authenticate in the
   browser, or `gh auth login` first. (SSH clone works only after step 1 +
   `link.sh` puts `~/.ssh/config` in place.)
3. `./install.sh` — brew, symlinks (incl. `~/.ssh/config`), runtimes, macOS.
4. Re-auth everything else (below).

## Secrets — NOT in this repo (by design)

These never get committed; recreate them on the new machine:

| Secret | Where it was | New machine |
| --- | --- | --- |
| SSH keys | 1Password | install 1Password, enable SSH agent — done |
| Commit signing key | 1Password (`op-ssh-sign`) | new gig → generate a new SSH key in 1Password, put its public key in `~/.gitconfig-work` |
| GitHub token | `GH_TOKEN` in fish universal vars | `gh auth login` (don't copy the token) |
| npm token | `~/.npmrc` (`_authToken`) | `npm login`, or copy from 1Password if you store it there |
| gcloud / kube / docker creds | `~/.config/gcloud`, `~/.kube`, `~/.docker` | old-gig; re-auth at the new gig as needed |

## Manual steps after install

- 1Password: sign in, enable the SSH agent (Settings → Developer) — git signing depends on it.
- `~/.gitconfig-work`: fill in your work email + 1Password signing key.
- `gh auth login`.
- Sign in to Chrome / Slack / Discord / Dropbox / Spotify / Linear / Figma.
- `exec fish` (or restart the terminal) to pick up the shell.

## What got pruned vs the old machine

- AI-tool graveyard (aider, codex, gemini, amp, crush, opencode, cline, …) — kept **Claude Code** only.
- Duplicate browsers/terminals/editors — kept **Chrome**, **cmux**, **Zed**.
- Old-gig infra (nats, temporal, supabase, neo4j, tempest tap) and the protobuf toolchain — **parked** (commented) in the Brewfile.
- vite-plus / minimal / pi shims — dropped; runtimes centralized on Homebrew.
- Hobby/maker apps, most menubar utilities — dropped (kept Hidden Bar, Rectangle, CleanShot).
