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
abbr --erase notes &>/dev/null; abbr --add notes "code $HOME/Dropbox/notes.md"
