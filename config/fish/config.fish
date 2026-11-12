if status is-interactive
    # Commands to run in interactive sessions can go here
end

# -----------------------------------------------------------------------------
# PATH
# -----------------------------------------------------------------------------
# bun global bin (bun itself installed via Homebrew; globals still land in ~/.bun)
set --export BUN_INSTALL "$HOME/.bun"
fish_add_path $BUN_INSTALL/bin

# user-local bins (pipx, uv tools, misc)
fish_add_path $HOME/.local/bin

# go bins
fish_add_path $HOME/go/bin

# cargo bins
fish_add_path $HOME/.cargo/bin

# -----------------------------------------------------------------------------
# Prompt
# -----------------------------------------------------------------------------
starship init fish | source

# -----------------------------------------------------------------------------
# Aliases
# -----------------------------------------------------------------------------
alias cat='bat'
alias ls='lsd -Al --date=relative --group-dirs=first --icon=always --sort=extension'
alias reload='exec fish'

# -----------------------------------------------------------------------------
# Abbreviations
# -----------------------------------------------------------------------------
abbr --erase s &>/dev/null; abbr --add s "git status"
abbr --erase d &>/dev/null; abbr --add d "git diff"
abbr --erase ga &>/dev/null; abbr --add ga "git add"
abbr --erase gco &>/dev/null; abbr --add gco "git checkout"
abbr --erase gca &>/dev/null; abbr --add gca "git commit --amend"
abbr --erase gcm &>/dev/null; abbr --add gcm "git commit -m"
abbr --erase m &>/dev/null; abbr --add m "git merge"
abbr --erase pp &>/dev/null; abbr --add pp "git pull"
abbr --erase p &>/dev/null; abbr --add p "git push"
abbr --erase c &>/dev/null; abbr --add c "clear"
abbr --erase workshop &>/dev/null; abbr --add workshop "cd $HOME/code/work/workshop"
abbr --erase www &>/dev/null; abbr --add www "cd $HOME/code/work/www"
abbr --erase obs &>/dev/null; abbr --add obs 'cd ~/Vault'
abbr --erase nps &>/dev/null; abbr --add nps "cd $HOME/code/nps"

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :

# pnpm
set -gx PNPM_HOME "/Users/ericskram/Library/pnpm"
if not string match -q -- "$PNPM_HOME/bin" $PATH
  set -gx PATH "$PNPM_HOME/bin" $PATH
end
# pnpm end
test -f ~/.config/op/plugins.sh; and source ~/.config/op/plugins.sh

# -----------------------------------------------------------------------------
# 1Password-managed env (drain FIFO once per login → universal exported vars)
# -----------------------------------------------------------------------------
# First interactive shell after `set -Ue __OP_ENV_LOADED_AT` runs load-env;
# every subsequent shell inherits the universal vars. To refresh: `load-env`.
if status is-interactive; and not set -q __OP_ENV_LOADED_AT; and test -e ~/.config/.env
    load-env
end

# >>> minimal >>>
if test -f "$HOME/.minimal/shim/shell-init/fish.fish"; source "$HOME/.minimal/shim/shell-init/fish.fish"; end
# <<< minimal <<<

# Homebrew on Apple Silicon, MacPorts on the Intel home server.
test -x /opt/homebrew/bin/brew; and eval "$(/opt/homebrew/bin/brew shellenv fish)"
test -d /opt/local/bin; and fish_add_path /opt/local/bin /opt/local/sbin

# Load the git signing key into whatever agent this shell uses (passphrase from macOS keychain).
if status is-interactive
    ssh-add --apple-load-keychain -q 2>/dev/null
end
