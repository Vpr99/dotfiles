#!/usr/bin/env bash
# Zero -> hero. Run on a fresh Mac:
#   git clone <this repo> ~/code/personal/dotfiles
#   cd ~/code/personal/dotfiles && ./install.sh
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES"

echo "==> 1/4  Homebrew + apps (Brewfile)"
bash scripts/bootstrap.sh

echo "==> 2/4  Symlink dotfiles"
bash scripts/link.sh

echo "==> 3/4  Runtimes, default shell, services"
bash scripts/runtimes.sh

echo "==> 4/4  macOS defaults"
read -rp "Apply macOS system defaults now? [y/N] " ans
case "$ans" in
  [yY]*) bash macos.sh ;;
  *) echo "Skipped. Run 'bash macos.sh' later." ;;
esac

cat <<'EOF'

Done. Remaining manual steps:
  - Sign in to 1Password, then enable the SSH agent (Settings -> Developer).
  - Fill in ~/.gitconfig-work email + signing key (see gitconfig-work).
  - gh auth login   (GitHub credential helper is already configured)
  - Sign in to Chrome, Slack, Discord, Dropbox, Spotify, etc.
  - Restart your terminal (or `exec fish`) to pick up the new shell.
EOF
