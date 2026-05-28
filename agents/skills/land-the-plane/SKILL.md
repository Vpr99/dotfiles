---
name: land-the-plane
description: >
  End-of-branch ritual: lint/format/check, consolidate plans, flush learnings to
  CLAUDE.md, and open a PR. Sequential pipeline that cleans up a branch before
  merge. Use when done with a feature branch and ready to PR. Triggers:
  "land the plane", "wrap up this branch", "prep for PR", "finalize branch".
disable-model-invocation: true
argument-hint: "[additional PR context]"
---

# Land the Plane

Sequential pipeline for closing out a feature branch. Each phase gates on the
previous — if something fails and can't be auto-fixed, stop and report.

## Input

$ARGUMENTS

Parse for:
- **Branch name** — defaults to current branch
- **Base branch** — defaults to `main`
- **Skip flags** — e.g., "skip lint", "skip plans" to bypass phases

## Phase 1: Lint & Format

Make the tools happy. No judgment calls.

1. Run `deno task fmt` — auto-format
2. Run `deno task lint` — capture errors
3. Run `deno check` — capture type errors
4. If fmt made changes, commit: `chore: format code`
5. Fix lint/type errors that are auto-fixable
6. Re-run to verify clean
7. If still failing, report remaining errors and stop

Load the `commit-format` skill. Commit fixes:
`chore(lint): fix lint and type errors`

**Gate:** All three commands must pass before proceeding.

## Phase 2: Consolidate Plans

Load the `summarize-plan` skill.

1. Check for plan docs: `docs/plans/*.md`
2. If plans exist, invoke summarize-plan to consolidate into a single
   source-of-record document
3. Delete outdated versions (`.v2.md`, `.v3.md`, etc.)
4. Delete review documents in `docs/reviews/` that were generated during this
   branch's development — but only AFTER remembering-learnings has mined them (Phase 3
   reads reviews before this deletes them)

**Important:** Do NOT delete review docs yet. Phase 3 needs them. Mark them for
deletion and clean up in Phase 4.

Load the `commit-format` skill. Commit:
`docs: consolidate plan docs for <feature>`

**Gate:** If no plan docs exist, skip this phase silently.

## Phase 3: Flush Learnings

Load the `remembering-learnings` skill.

1. Mine commit Key Learnings footers from `main..HEAD`
2. Read `docs/learnings/*.md` (team lead notes)
3. Read `docs/reviews/*.md` (code-review and polish findings)
4. Deduplicate, filter, classify
5. Propose CLAUDE.md changes to user
6. Apply approved changes
7. Delete consumed `docs/learnings/*.md` files

Load the `committing` skill. Commit:
`chore(meta): flush agent learnings to CLAUDE.md`

**Gate:** If no learnings pass the filter, skip the commit. Report "No
actionable learnings found."

## Phase 4: Clean Up Review Docs

Now that remembering-learnings has mined the review docs:

1. Delete `docs/reviews/*.md` files generated during this branch
2. Remove `docs/reviews/` directory if empty
3. Remove `docs/learnings/` directory if empty

Commit: `chore: clean up review and learnings artifacts`

**Gate:** Skip if no files to clean up.

## Phase 5: Open PR

Load the `opening-pr` skill. **Follow its PR format exactly** — including the
micro-poem at the top of the description. The poem is tradition, not optional.

1. Push branch to remote
2. Create PR using the opening-pr skill's format and process

Pass any $ARGUMENTS context to the opening-pr skill.

## Terminal Summary

```
Landing complete.
  Lint:      {pass/fail}
  Plans:     {consolidated N docs / skipped}
  Learnings: {flushed N items to CLAUDE.md / no actionable learnings}
  PR:        {PR URL}
```

## Error Handling

- **Lint/check fails after fix attempt** → Stop. Report errors. User decides.
- **No plan docs** → Skip Phase 2, note in summary
- **No learnings** → Skip Phase 3 commit, note in summary
- **PR creation fails** → Report error, but don't lose the other work
- **User rejects all proposed learnings** → Skip commit, note in summary

## Rules

- Phases are sequential — each gates on the previous
- Load commit-format before every commit
- The user approves CLAUDE.md changes (Phase 3) — don't auto-write
- Review docs are mined before deleted — ordering matters
- Don't expand scope — this is cleanup, not feature work
