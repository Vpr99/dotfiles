# Git worktree helpers — operate on the current repository.
#
# Worktrees are created as siblings of the repo root in a `worktrees/` dir:
#   <parent>/<repo>            <- main checkout
#   <parent>/worktrees/<name>  <- worktrees
#
# If the worktree contains scripts/setup-secrets.sh it is run after creation.

function _wt_root --description "Print the main worktree (repo) root or fail"
    set -l root (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$root"
        echo "Not inside a git repository" >&2
        return 1
    end
    echo $root
end

function _wt_dir --description "Print the worktrees/ dir for the current repo"
    set -l root (_wt_root); or return 1
    echo (dirname $root)/worktrees
end

function wt-setup-secrets --description "Run scripts/setup-secrets.sh if present"
    if test -f scripts/setup-secrets.sh
        ./scripts/setup-secrets.sh
    end
end

function wt-new --description "Create a worktree: wt-new [--from <branch>] <name>"
    set -l from_branch ""
    set -l name ""
    set -l i 1
    while test $i -le (count $argv)
        if test "$argv[$i]" = "--from"
            set i (math $i + 1)
            test $i -le (count $argv); or begin; echo "Error: --from requires a branch"; return 1; end
            set from_branch $argv[$i]
        else
            set name $argv[$i]
        end
        set i (math $i + 1)
    end

    test -n "$name"; or begin; echo "Usage: wt-new [--from <branch>] <name>"; return 1; end

    set -l root (_wt_root); or return 1
    set -l wtdir (_wt_dir)
    pushd $root
    git pull

    if test -n "$from_branch"
        git fetch origin
        set -l ref ""
        if git rev-parse --verify "$from_branch" >/dev/null 2>&1
            set ref $from_branch
        else if git rev-parse --verify "origin/$from_branch" >/dev/null 2>&1
            set ref "origin/$from_branch"
        else
            echo "Error: branch '$from_branch' not found locally or on origin"; popd; return 1
        end
        git worktree add -b $name $wtdir/$name $ref; or begin; popd; return 1; end
    else
        git worktree add $wtdir/$name; or begin; popd; return 1; end
    end
    popd
    cd $wtdir/$name
    wt-setup-secrets
end

function wt-checkout --description "Check out an existing branch as a worktree: wt-checkout <branch>"
    test (count $argv) -gt 0; or begin; echo "Usage: wt-checkout <branch>"; return 1; end
    set -l branch $argv[1]
    set -l root (_wt_root); or return 1
    set -l wtdir (_wt_dir)
    set -l path $wtdir/$branch

    if test -d $path
        cd $path; git pull
    else
        pushd $root; git fetch origin
        git worktree add $path $branch; popd
        cd $path
    end
    wt-setup-secrets
end

function wt-ls --description "List worktrees for the current repo"
    set -l root (_wt_root); or return 1
    pushd $root; git worktree list; popd
end

function wt-prune --description "Prune stale worktree metadata"
    set -l root (_wt_root); or return 1
    pushd $root; git worktree prune; popd
end

function wt-rm --description "Remove worktrees: wt-rm [-f] <name> [<name>...]"
    set -l force false
    set -l names
    for arg in $argv
        if test "$arg" = "-f"; set force true; else; set names $names $arg; end
    end
    test (count $names) -gt 0; or begin; echo "Usage: wt-rm [-f] <name> [<name>...]"; return 1; end

    set -l root (_wt_root); or return 1
    set -l wtdir (_wt_dir)
    for name in $names
        set -l path $wtdir/$name
        if not test -d $path
            echo "Worktree '$name' does not exist, skipping"; continue
        end
        if not $force
            pushd $path
            if git status --porcelain | string match -q .
                echo "Worktree '$name' has changes, skipping (use -f to force)"; popd; continue
            end
            popd
        end
        pushd $root
        if $force; git worktree remove -f $path; else; git worktree remove $path; end
        popd
        echo "Removed worktree '$name'"
    end
end
