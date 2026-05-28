# =============================================================================
# Brewfile — zero -> hero machine setup
#
#   brew bundle --file=~/code/personal/dotfiles/Brewfile
#
# Philosophy: install as much as possible through Homebrew so a single
# `brew bundle` reproduces the machine. Anything commented out is deliberately
# parked — uncomment to re-enable. Pruned: the AI-tool graveyard, old-gig
# infra, hobby/maker apps, duplicate browsers/terminals/editors.
# =============================================================================

# ----------------------------------------------------------------------------
# Taps
# ----------------------------------------------------------------------------
tap "homebrew/bundle"
tap "oven-sh/bun"         # bun

# ----------------------------------------------------------------------------
# Shell & prompt
# ----------------------------------------------------------------------------
brew "fish"
brew "starship"
brew "coreutils"          # GNU coreutils (gln, gsed, etc.)

# ----------------------------------------------------------------------------
# Core CLI — search, view, navigate
# ----------------------------------------------------------------------------
brew "ast-grep"           # structural code search (preferred over grep)
brew "fd"                 # fast find
brew "fzf"                # fuzzy finder
brew "bat"                # cat with wings
brew "lsd"                # ls with icons
brew "tree"
brew "jq"                 # JSON
brew "yq"                 # YAML/JSON
brew "git-delta"          # better git diffs
brew "gh"                 # GitHub CLI
brew "glow"               # markdown in the terminal

# ----------------------------------------------------------------------------
# Languages & runtimes  (centralized on Homebrew)
# ----------------------------------------------------------------------------
brew "node"
brew "oven-sh/bun/bun"
brew "deno"
brew "rust"
brew "go"
brew "uv"                 # python package/runtime manager
brew "pipx"               # isolated python CLIs

# ----------------------------------------------------------------------------
# Formatters / linters
# ----------------------------------------------------------------------------
brew "prettier"
brew "biome"
brew "shfmt"
brew "gofumpt"
brew "golangci-lint"
brew "sqlfluff"

# ----------------------------------------------------------------------------
# Dev tooling
# ----------------------------------------------------------------------------
brew "jj"                 # jujutsu VCS
brew "mkcert"             # local TLS certs
brew "cloudflared"        # tunnels
brew "act"                # run GitHub Actions locally
brew "actionlint"         # lint GH Actions workflows
brew "opentofu"           # terraform fork

# ----------------------------------------------------------------------------
# Data / databases
# ----------------------------------------------------------------------------
brew "postgresql@18"
brew "libpq"
brew "duckdb"

# ----------------------------------------------------------------------------
# Media
# ----------------------------------------------------------------------------
brew "ffmpeg"
brew "yt-dlp"
brew "pngquant"
brew "svgo"

# ----------------------------------------------------------------------------
# Fonts
# ----------------------------------------------------------------------------
cask "font-fira-code-nerd-font"
cask "font-ibm-plex-mono"
cask "font-iosevka"
cask "font-sf-mono-nerd-font-ligaturized"

# ----------------------------------------------------------------------------
# Apps — daily drivers
# ----------------------------------------------------------------------------
cask "1password"
cask "1password-cli"
cask "google-chrome"
cask "cmux"                   # ghostty-based terminal for AI coding agents
cask "zed"                    # editor
cask "claude"                 # Claude desktop app
cask "claude-code"            # Claude Code CLI
cask "raycast"
cask "cleanshot"
cask "rectangle"              # window snapping
cask "hiddenbar"             # menubar tidy
cask "obsidian"
cask "docker-desktop"

# ----------------------------------------------------------------------------
# Apps — comms & work
# ----------------------------------------------------------------------------
cask "slack"
cask "discord"
cask "signal"
cask "zoom"
cask "spotify"
cask "linear-linear"
cask "figma"
cask "dropbox"

# =============================================================================
# PARKED — uncomment per project / as needed
# =============================================================================

# --- Protobuf / gRPC toolchain (was Tempest; generic enough to reuse) -------
# brew "buf"
# brew "protoc-gen-go"
# brew "sqlc"
# brew "grpcui"
# brew "stern"            # multi-pod kube log tailing
# brew "goreman"         # Procfile process runner

# --- Local infra services (re-enable per project) ---------------------------
# brew "nats-io/nats-tools/nats"
# brew "nats-server"
# brew "temporal"
# brew "supabase/tap/supabase"
# brew "ollama"

# --- WASM toolchain ---------------------------------------------------------
# brew "wabt"
# brew "binaryen"

# --- Cloud SDKs -------------------------------------------------------------
# cask "gcloud-cli"

# --- Other GUIs you had (currently dropped) --------------------------------
# cask "db-browser-for-sqlite"
# cask "ghostty"
# cask "visual-studio-code"   # config backed up under ./vscode (see README)
