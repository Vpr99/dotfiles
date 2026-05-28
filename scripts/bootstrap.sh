#!/usr/bin/env bash
# Install Homebrew (if missing) and everything in the Brewfile.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Xcode command line tools (git, compilers) — required before brew.
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Installing Xcode command line tools..."
  xcode-select --install || true
  echo "Re-run this script once the CLT install finishes."
  exit 0
fi

# Homebrew
if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Apple Silicon brew shellenv for this session
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo "Running brew bundle..."
brew bundle --file="$DOTFILES/Brewfile"

echo "Brew bundle complete."
