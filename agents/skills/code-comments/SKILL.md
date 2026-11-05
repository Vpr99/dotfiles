---
name: code-comments
description: Kill-first comments. Keep a short list; delete the rest from the files. Use when writing or reviewing comments, docs, TODOs, suppressions, or workaround sermons.
license: MIT
user-invocable: true
---

# Code Comments

Hate comments. Keep-list or delete. Unsure? Delete. Do not rewrite meat. Do not flag. Do not touch application code.

Restates the code? Dead. Why the code already proves (`so it never drifts`)? Dead.

## Keep

- License headers
- Gotcha forced by an **external** dep, platform, vendor, or protocol. Our-code surprises are meat.
- `prettier-ignore`. Other suppressions only if the rule is faulty, pedantic, or style-only.
- Public API contract docs (what, constraints, ambiguous returns, side effects). No getters or obvious helpers.
- Issue/RFC link for a constraint code cannot express. Reason stays in the comment; link is the way out.
- `TODO`/`FIXME`/`HACK`: owner, reason, way out.
- `ponytail:` ceiling + upgrade path.

`IMPORTANT`, `do not remove`, `too risky`, `fine for now`, banners, narration, commented-out code: delete.

Hunt nearby code before keeping. Doubt after the hunt: delete.

`eslint-disable` / `@ts-ignore` / `@ts-expect-error`: look up the rule. Pedantic or style? Delete. Catches real bugs? Keep.

## Survivors

Load **content-style**. Terse. Active. Specific. No plan/PR/"user story" cites. Date expiry. Reference constants (`STALE_THRESHOLD_SECS`), don't copy values. `1048576 // 1MB` is a unit, not a dupe.

## Review

Scope: named files, else the diff, else diff vs `main`. Edit files. Burn every comment off the keep-list. Report files, deletions, skips (which keep clause).
