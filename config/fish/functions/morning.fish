function morning --description "Run all daily software updates: brew, pnpm, bun, skills"
    # ponytail: each step guarded by `type -q`; a failing step prints its own
    # error but doesn't abort the rest. Add a tool by copying a block.
    set -l step_num 0

    function __morning_step
        set -g __morning_n (math $__morning_n + 1)
        set_color --bold cyan
        echo ""
        echo "==> $argv[1]"
        set_color normal
    end
    set -g __morning_n 0

    # Ask for the password now, then keep the sudo timestamp fresh (default
    # expiry is 5 min) so cask upgrades don't stall waiting on a prompt.
    # ponytail: capped at ~50 min so a Ctrl-C'd run can't keep sudo warm forever.
    sudo -v; or return 1
    bash -c "for i in {1..60}; do kill -0 $fish_pid 2>/dev/null || exit; sudo -n true; sleep 50; done" &
    set -l sudo_keepalive $last_pid
    disown $sudo_keepalive

    if type -q brew
        __morning_step "Homebrew"
        # -y: skip Homebrew 6's default ask-before-upgrade confirmation
        brew update; and brew upgrade -y; and brew cleanup
    end

    if type -q pnpm
        __morning_step "pnpm global packages"
        # no `pnpm self-update`: Homebrew owns the pnpm binary, upgraded above.
        pnpm update -g
    end

    if type -q bun
        __morning_step "bun runtime"
        bun upgrade
    end

    if type -q npx
        __morning_step "Claude skills"
        npx -y skills update -g
    end

    if type -q nps-cleanup
        __morning_step "Dev cleanup"
        # Prunes only what can't lose work; merged worktrees are reported,
        # not removed. Run `nps-cleanup --apply-worktrees` to act on them.
        nps-cleanup
    end

    kill $sudo_keepalive 2>/dev/null
    sudo -k
    functions -e __morning_step
    set -e __morning_n
    set_color --bold green
    echo ""
    echo "Done. Go get coffee."
    set_color normal
end
