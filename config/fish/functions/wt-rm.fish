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
