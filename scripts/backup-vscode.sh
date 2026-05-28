#!/usr/bin/env bash
# Run on the OLD machine: snapshot VS Code config + extension list into ./vscode.
# VS Code is intentionally NOT in the Brewfile — this is a safety net so the
# config survives the move. To restore later: install VS Code, then run
# scripts/restore-vscode.sh (or copy the files + `cat extensions.txt | xargs -n1 code --install-extension`).
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$HOME/Library/Application Support/Code/User"
DEST="$DOTFILES/vscode"
mkdir -p "$DEST/snippets"

for f in settings.json keybindings.json; do
  if [ -f "$SRC/$f" ]; then
    cp "$SRC/$f" "$DEST/$f"
    echo "  saved $f"
  fi
done

if [ -d "$SRC/snippets" ]; then
  cp -R "$SRC/snippets/." "$DEST/snippets/" 2>/dev/null || true
  echo "  saved snippets/"
fi

if command -v code >/dev/null 2>&1; then
  code --list-extensions > "$DEST/extensions.txt"
  echo "  saved extensions.txt ($(wc -l < "$DEST/extensions.txt" | tr -d ' ') extensions)"
else
  echo "  'code' CLI not on PATH — skipping extensions list"
fi

echo "VS Code config backed up to $DEST"
