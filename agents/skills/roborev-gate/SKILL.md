---
name: roborev-gate
description: Handles the roborev review ledger for a branch. Waits for the Codex commit reviews, runs a branch security review, gets each open finding adjudicated, then comments on it and closes it. Use before the final whole-branch review of a plan, and before opening a PR in a repo that roborev reviews (workshop, gal, coalmine, santa-mac, hermey, and their worktrees).
---

# roborev gate

roborev reviews every commit with Codex in the background through a post-commit hook. Findings stay open in its ledger until someone closes them. Handle them only here, once per branch. Run every command from the branch's worktree.

## Final gate (before the final whole-branch review)

1. Wait for pending reviews. Take the ids of queued and running jobs from `roborev list --json`, then run `roborev wait <ids> --quiet`.
2. Run `roborev review --branch --type security --reasoning high --wait --quiet`.
3. Collect the open findings: `roborev list --open --json`, then `roborev show --json <id>` for each one.
4. Give them to the final reviewer as "External reviewer findings (Codex via roborev), not verified. Adjudicate each one against the current code." Severity: critical → Critical, high → Important, medium and low → Minor unless the reviewer raises it. Confirmed findings go into the single fix pass.
5. For each finding, run `roborev comment <id> "fixed in <sha>"` or `roborev comment <id> "rejected: <reason>"`, then `roborev close <id>`.
6. If the plan has an executor ledger (`progress.md`), append `roborev final gate: HEAD <sha>`.

Do not use `roborev compact`. It has marked valid findings as fixed and has checked the wrong checkout.

## PR gate (replaces the local `cr review` step of the pull-request skill)

- `roborev list --open` on the branch must be empty. Do not run `cr review`.
- If findings are open and HEAD still matches the `roborev final gate` sha, adjudicate each one against the current code, then do step 5. If HEAD moved, run the whole final gate again.

## Never

- Run `roborev refine`, or turn on the roborev CI poller.
- Commit the `.gitignore` change that `roborev init` makes. Put `.roborev/` in `.git/info/exclude` instead.
