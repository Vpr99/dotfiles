---
name: simplicity-review
description: Adversarial simplicity review of a spec or implementation plan by two independent reviewers in parallel, a fresh Opus subagent and Codex, both loaded with the Karpathy guidelines and ponytail. Run it automatically after superpowers brainstorming writes a spec and after writing-plans writes a plan, once the inline self-review is done and before the user approval gate. Also triggers on "/simplicity-review", "adversarial review this spec", "simplicity review the plan".
---

# simplicity-review

Two reviewers on different models, one shared rubric. The author (you) adjudicates in the open and the user rules at the existing approval gate.

## Inputs

- `DOC`: the spec or plan just written, usually the newest `<harness>/plans/*-spec.md` or `*-plan.md`.
- `CTX`: for a plan, its spec (same date and slug, `-spec.md`). For a spec, none.
- `REPO`: the child repo the doc targets, resolved via the dev-harness paths (worktree if one exists). If the doc spans repos, use the primary one. Reviewers must be able to grep real code.
- `OUT`: `<harness>/tmp/simplicity-review/<doc-basename>/`

## 1. Dispatch both reviewers in parallel (one message)

**Codex:** Bash, `run_in_background: true`:

```sh
mkdir -p "$OUT" && ~/.agents/skills/simplicity-review/run-codex.sh "$DOC" "$REPO" "$OUT/codex.md" ${CTX:+"$CTX"}
```

**Opus:** Agent, `subagent_type: general-purpose`, `model: opus`. Prompt:

> Read `~/.agents/skills/simplicity-review/reviewer-prompt.md` and follow it exactly. Rubrics: read `~/.agents/skills/karpathy-guidelines/SKILL.md` and the ponytail skill (`ls -d ~/.claude/plugins/cache/ponytail/ponytail/*/skills/ponytail | sort -V | tail -1`, then its `SKILL.md`). [If CTX: Context, the approved spec, which you check the plan does not exceed: `<CTX>`.] Document under review: `<DOC>`. Repository to ground every reuse claim in: `<REPO>`. Read-only: edit nothing. Write your output to `<OUT>/opus.md` and return it.

Don't pass your own reasoning or the conversation history. Independence is the point.

## 2. Merge

Once both are done, read `opus.md` and `codex.md`. Build one table, deduplicated by section and intent:

| # | Finding | Opus | Codex | Disposition |
|---|---------|------|-------|-------------|

- **Both flagged:** high confidence. Default is accept. Rejecting one needs concrete evidence (`path:line` or a quote of the explicit requirement), stated in the table.
- **One flagged:** verify it yourself. Check the cited `path:line`, grep for the claimed reuse. Then accept or reject with a one-line reason.
- A finding that touches a "Keep" item from either reviewer (security, validation, fail-closed, audit, requested scope) goes to the user as a question. Don't decide it yourself.
- `question` findings are always passed to the user.

You wrote the doc, so you're biased toward it. Never drop a finding silently. Every one appears in the table.

## 3. Apply and hand off

1. Edit `DOC` to apply the accepted findings. Keep it the same file; don't version it.
2. Show the user the table, the two verdict lines, and a short summary of the edits (or `npx difit` if large).
3. Continue into the normal superpowers user approval gate. The user can overturn any disposition there.

If Codex fails (auth, quota), report it and continue with Opus alone. Don't retry in a loop.
