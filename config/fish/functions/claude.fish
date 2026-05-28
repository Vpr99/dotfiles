function claude --description "Claude Code with a task list keyed to the current git branch"
    set -l branch (git branch --show-current 2>/dev/null)
    if test -n "$branch"
        # Sanitize: replace / with -- and strip other special chars
        set -l safe_branch (string replace -a '/' '--' -- $branch | string replace -ra '[^a-zA-Z0-9_-]' '')
        set -x CLAUDE_CODE_TASK_LIST_ID "$safe_branch"
    end
    command claude --dangerously-skip-permissions $argv
end
