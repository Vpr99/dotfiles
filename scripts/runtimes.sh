#!/usr/bin/env bash
# Post-brew setup: default shell, package managers, language CLIs, services.
set -euo pipefail

BREW_PREFIX="$(brew --prefix)"

# --- Make fish the default shell ---
FISH="$BREW_PREFIX/bin/fish"
if [ -x "$FISH" ]; then
  if ! grep -qx "$FISH" /etc/shells; then
    echo "Adding $FISH to /etc/shells (sudo)..."
    echo "$FISH" | sudo tee -a /etc/shells >/dev/null
  fi
  if [ "$SHELL" != "$FISH" ]; then
    echo "Setting fish as default shell..."
    chsh -s "$FISH"
  fi
fi

# --- corepack: pnpm + yarn without separate installs ---
if command -v corepack >/dev/null 2>&1; then
  corepack enable || true
fi

# --- Python CLIs via uv (isolated) ---
if command -v uv >/dev/null 2>&1; then
  uv tool install ruff || true
fi

# --- Postgres service ---
if brew list postgresql@18 >/dev/null 2>&1; then
  brew services start postgresql@18 || true
fi

echo "Runtime setup complete."
echo "Note: bun/deno/node are managed by Homebrew. Global bun packages still land in ~/.bun/bin."
