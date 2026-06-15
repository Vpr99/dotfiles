function wt-ls --description "List worktrees for the current repo"
    set -l root (_wt_root); or return 1
    pushd $root; git worktree list; popd
end
