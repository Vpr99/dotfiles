#!/usr/bin/env bash
# Optional: restore the backed-up VS Code config onto a machine that has VS Code.
# (VS Code is not installed by the Brewfile by default — install it first, e.g.
#  `brew install --cask visual-studio-code`.)
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$DOTFILES/vscode"
DEST="$HOME/Library/Application Support/Code/User"

if [ ! -d "$SRC" ]; then
  echo "No backup found at $SRC"; exit 1
fi
mkdir -p "$DEST/snippets"

for f in settings.json keybindings.json; do
  [ -f "$SRC/$f" ] && cp "$SRC/$f" "$DEST/$f" && echo "  restored $f"
done
[ -d "$SRC/snippets" ] && cp -R "$SRC/snippets/." "$DEST/snippets/" && echo "  restored snippets/"

if [ -f "$SRC/extensions.txt" ] && command -v code >/dev/null 2>&1; then
  echo "Installing extensions..."
  while read -r ext; do
    [ -n "$ext" ] && code --install-extension "$ext" || true
  done < "$SRC/extensions.txt"
fi

echo "VS Code config restored."
