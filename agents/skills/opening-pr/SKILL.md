---
name: opening-pr
description: >
  Opens a pull request with a concise, informational description and a linked
  Linear ticket explaining the why. Triggers on "open a PR", "create PR",
  "opening-pr", "land this".
argument-hint: "[additional context for PR description]"
---

# Open PR

Open a PR matching the workshop house style: unprefixed title, terse body,
Linear ticket linked inline. Reviewers skim, so cut filler and decorative prose.

## Pre-fetched Context

Commit log:

!`git log main..HEAD --oneline 2>/dev/null || echo "No commits found"`

Changed files:

!`git diff --stat main...HEAD 2>/dev/null || echo "No diff found"`

## Input

$ARGUMENTS

## Process

1. **Load the writing skill.** Invoke `content-style` and write the body under
   its rules. Keep it brief but informative. A reviewer should learn what
   changed and why without wading through filler.
2. **Get the Linear ticket.** Scan `$ARGUMENTS`, the branch name, and recent
   commits for an `NPS-####` (or other Linear) reference. If none found, ask
   the user for the Linear ticket link or ID before continuing. A PR without a
   linked ticket is not acceptable. The ticket _is_ the why.
3. Review the commit log and changed files above.
4. Read any plan docs in `docs/plans/` that relate to the branch.
5. Draft the title and body per the format below.
6. Push the branch and create the PR with `gh pr create`.

## Title Format

`Imperative description of the outcome`

- **No scope prefix**: do not start titles with prefixes like `api:`, `ui:`,
  `db:`, `docs:`, `tests:`, or `build(deps):`.
- **Imperative mood**, sentence case, <70 chars total.
- No ticket ID in the title. The body links it.

Examples:

- `Trigger sync when tag<->group mappings change`
- `Add (host_id, execution_time) composite index on events`
- `Make / focus filter bar, add a hint`
- `Make telemetry filter expression docs clearer & accurate`

## Body Format

Match length to the change. Three tiers:

### Tier 1: Trivial change (most PRs)

Body is empty or one sentence. Title carries the meaning.

```
Fixes NPS-1234
```

or

```
Fixes NPS-1234

These files are all unused remnants from the old filter UI
```

### Tier 2: Non-trivial change

Lead with the ticket link, then 2–4 bullets stating what changed and any
non-obvious reasoning.

```
Fixes NPS-1234

* Document that an expression returning `TRUE` means to drop the event
* Document that all expressions must return `FALSE` for the event to be uploaded
* Fix several examples that had this logic backwards
```

### Tier 3: Substantial change

One-line summary, ticket link, then bolded inline labels for sub-areas. No
`## Summary` or `## Test Plan` headers. They aren't used in this repo.

```
Fixes NPS-1234

Adds break glass admin login via WebAuthn passkeys for when WorkOS is unreachable.

- **Backend**: new `passkeys` and `passkey_challenges` tables; RPCs to enroll,
  list, revoke, and authenticate via discoverable WebAuthn credentials.
- **Frontend**: `/passkey-login` entry point, enrollment UI under Settings →
  Passkeys, gated by an admin toggle.
- **Multi-replica safe**: WebAuthn challenges persist in the DB (single-use
  via `DELETE … RETURNING`), with a 5-minute sweep cron.
```

## Rules

- **`Fixes NPS-####` is mandatory.** Place it on its own line, near the top.
  Use `Fixes` (closes the ticket on merge); use `Refs NPS-####` only when the
  PR is partial work toward a ticket that should stay open.
- **No `## Summary` / `## Test Plan` / `## Why` headers.** Workshop PRs don't
  use them. Lead with the ticket link, then bullets or prose.
- **Describe what changed, not what didn't.** Skip negative-space lines like
  "no backend changes", "no schema migration", "doesn't touch the API". If an
  area is untouched, leave it out. Absence isn't worth a bullet.
- **No decorative content**: no poems, emoji headers, "this PR introduces…"
  preambles, or AI puffery.
- **Screenshots**: include for visible UI changes. A screenshot alone is a
  valid body for trivial UI tweaks.
- Fold `$ARGUMENTS` content into the body where it fits.

## Anti-patterns (don't do these)

- "This PR introduces a robust, seamless solution…" is slop. Cut it.
- "Refactoring for better maintainability" is vague. Name the specific win.
- "No backend changes / no migration needed" inverts it. Describe what the PR does, not
  what it doesn't. Omit untouched areas.
- Bullet lists that paraphrase the diff line by line.
- Em dashes, "delve", "leverage", "ensure", "showcase", "comprehensive".
- Skipping the Linear link because "the diff is self-explanatory". It isn't.
- Inventing `## Summary` / `## Test Plan` scaffolding the repo doesn't use.
