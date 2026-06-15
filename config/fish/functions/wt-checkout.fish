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
end
