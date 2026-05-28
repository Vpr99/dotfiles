#!/usr/bin/env bash
# Symlink dotfiles into place. Existing files are backed up to *.bak-<ts>.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TS="$(date +%Y%m%d%H%M%S)"

link() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ "$(readlink "$dest" 2>/dev/null)" = "$src" ]; then
      echo "  ok    $dest"
      return
    fi
    mv "$dest" "$dest.bak-$TS"
    echo "  bak   $dest -> $dest.bak-$TS"
  fi
  ln -sfn "$src" "$dest"
  echo "  link  $dest"
}

copy() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    mv "$dest" "$dest.bak-$TS"
    echo "  bak   $dest -> $dest.bak-$TS"
  fi
  cp "$src" "$dest"
  echo "  copy  $dest"
}

echo "Linking from $DOTFILES"

# --- fish ---
link "$DOTFILES/config/fish/config.fish"            "$HOME/.config/fish/config.fish"
link "$DOTFILES/config/fish/functions/claude.fish"  "$HOME/.config/fish/functions/claude.fish"
link "$DOTFILES/config/fish/functions/wt.fish"      "$HOME/.config/fish/functions/wt.fish"

# --- ssh (routes auth through the 1Password agent) ---
link "$DOTFILES/config/ssh/config" "$HOME/.ssh/config"

# --- git ---
link "$DOTFILES/config/git/gitconfig"          "$HOME/.gitconfig"
link "$DOTFILES/config/git/gitconfig-work"     "$HOME/.gitconfig-work"
link "$DOTFILES/config/git/gitconfig-personal" "$HOME/.gitconfig-personal"
link "$DOTFILES/config/git/ignore"             "$HOME/.config/git/ignore"

# --- claude / agents ---
# skills chain:  ~/.claude/skills -> ~/.agents/skills -> repo/agents/skills
link "$DOTFILES/agents/skills"                  "$HOME/.agents/skills"
link "$HOME/.agents/skills"                     "$HOME/.claude/skills"
link "$DOTFILES/claude/CLAUDE.md"               "$HOME/.claude/CLAUDE.md"
link "$HOME/.claude/CLAUDE.md"                  "$HOME/.agents/agents.md"
link "$DOTFILES/claude/commands"                "$HOME/.claude/commands"
link "$DOTFILES/claude/statusline-command.sh"   "$HOME/.claude/statusline-command.sh"
link "$DOTFILES/claude/statusline-wrapper.sh"   "$HOME/.claude/statusline-wrapper.sh"
chmod +x "$DOTFILES/claude/statusline-command.sh" "$DOTFILES/claude/statusline-wrapper.sh"

# settings.json is mutated by Claude at runtime — copy, don't link.
copy "$DOTFILES/claude/settings.json"           "$HOME/.claude/settings.json"

echo "Done linking."
