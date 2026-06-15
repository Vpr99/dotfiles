function _wt_dir --description "Print the worktrees/ dir for the current repo"
    set -l root (_wt_root); or return 1
    echo (dirname $root)/worktrees
end
