function wt-prune --description "Prune stale worktree metadata"
    set -l root (_wt_root); or return 1
    pushd $root; git worktree prune; popd
end
