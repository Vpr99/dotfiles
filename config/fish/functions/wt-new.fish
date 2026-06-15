# Git worktree helpers — operate on the current repository.
#
# Worktrees are created as siblings of the repo root in a `worktrees/` dir:
#   <parent>/<repo>            <- main checkout
#   <parent>/worktrees/<name>  <- worktrees

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
        git worktree add -b $name $wtdir/$name; or begin; popd; return 1; end
    end
    popd
    cd $wtdir/$name
end
