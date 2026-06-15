function _wt_root --description "Print the main worktree (repo) root or fail"
    set -l root (git rev-parse --show-toplevel 2>/dev/null)
    if test -n "$root"
        echo $root
        return 0
    end

    # Fallback: PWD may be the <parent> dir that holds the checkout and worktrees/.
    # Look for exactly one git checkout among PWD's immediate subdirs (skip worktrees/).
    set -l candidates
    for d in (find . -maxdepth 1 -mindepth 1 -type d -not -name worktrees 2>/dev/null)
        if test -e "$d/.git"
            set candidates $candidates (path resolve $d)
        end
    end

    switch (count $candidates)
        case 1
            echo $candidates[1]
        case 0
            echo "Not inside a git repository" >&2
            return 1
        case '*'
            echo "Multiple git checkouts in "(pwd)":" >&2
            for c in $candidates
                echo "  $c" >&2
            end
            echo "cd into one to disambiguate" >&2
            return 1
    end
end
