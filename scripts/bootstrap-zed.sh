#!/usr/bin/env bash
# Symlink Zed config into place. Standalone — run on a machine that already
# has the rest of the dotfiles linked:  bash scripts/bootstrap-zed.sh
# Existing files are backed up to *.bak-<ts>. Symlinks mean edits made in
# Zed's UI flow back into the repo.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$DOTFILES/config/zed"
DEST="$HOME/.config/zed"
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

echo "Linking Zed config from $SRC"
link "$SRC/settings.json" "$DEST/settings.json"
link "$SRC/keymap.json"   "$DEST/keymap.json"
echo "Done. Restart Zed to pick up changes."
