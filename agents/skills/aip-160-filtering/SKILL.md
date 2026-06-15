---
name: aip-160-filtering
description: Audit and review API designs against Google AIP-160 filter conventions. Use when reviewing List/Search endpoints, designing filter query strings, evaluating whether a proposed filter syntax matches AIP-160, or critiquing protobuf request messages with filter fields. Covers operator precedence, type coercion, traversal rules, and the `has` operator.
---

# AIP-160 Filtering Audit

Audits API filter designs against [AIP-160](https://google.aip.dev/160). For `List`/`Search` endpoints, proto request messages, or TS request types with a filter query.

## When to invoke

- PR adds or changes a `filter` field on a List/Search endpoint
- New collection endpoint needs query-style filtering
- Structured filter object (`FilterRequest { name, status, created_after }`) should be a single string instead
- Verifying operator semantics, type coercion, or traversal rules

Not for: CEL expressions, full-text ranking, SQL-style WHERE clauses.

## Quick audit checklist

Flag anything that fails these:

**Shape**
- [ ] Exactly one filter field on the request message, typed as `string`, named `filter`
- [ ] No parallel structured filter fields (`status_filter`, `created_after`, etc.) — these belong inside the string
- [ ] Documented which fields bare literals match against (if literal matching is supported)

**Operators**
- [ ] Binary: `AND`, `OR` supported; `OR` has **higher** precedence than `AND` (opposite of most languages)
- [ ] Negation: both `NOT a` and `-a` supported (must support both if either)
- [ ] Comparison: `=`, `!=`, `<`, `>`, `<=`, `>=` for string/numeric/timestamp/duration — **not** for booleans or enums
- [ ] Has: `:` operator implemented for repeated fields, maps, and messages
- [ ] Field name on LHS of comparisons; literal/logical on RHS only

**Types & coercion**
- [ ] Enums: case-sensitive string form
- [ ] Booleans: literal `true` / `false`
- [ ] Durations: numeric + `s` suffix (`20s`, `1.2s`)
- [ ] Timestamps: RFC-3339 (`2012-04-21T11:30:00-04:00`)
- [ ] String equality supports `*` wildcard (`a = "*.foo"`)

**Traversal (`.` operator)**
- [ ] Uses real proto field names (snake_case), not aliases
- [ ] Does **not** traverse through repeated fields (except via `:`)
- [ ] Returns `INVALID_ARGUMENT` for undefined fields on messages
- [ ] Documents behavior for undefined keys on maps/structs
- [ ] Skips entries where any non-primitive link in the chain is unset (even for `!=`)

**Validation**
- [ ] Invalid filter strings return `INVALID_ARGUMENT` (not 500, not silently ignored)
- [ ] Type mismatches caught (`age=hello` for an int field rejected)
- [ ] Enum values validated against the allowed set
- [ ] Any deviation from AIP-160 is explicitly documented

## Anti-patterns to flag

1. **Structured filter objects** — `FilterRequest { name, status, created_after }` should collapse into `string filter`.
2. **`<`/`>` on bool or enum** — only `=` and `!=` are valid. `status > ACTIVE` is nonsense.
3. **RHS field references** — `a = b.c` is invalid. RHS accepts literals only.
4. **Indexed repeated access** — `tags[0] = "x"` and `tags.0 = "x"` are invalid. Use `tags:"x"`.
5. **camelCase traversal without docs** — proto fields are snake_case; auto-conversion must be documented.
6. **Silent failure on bad filter** — empty list or 500 instead of `INVALID_ARGUMENT`.
7. **Examples without parens** — `a AND b OR c` is ambiguous (OR binds tighter). Docs should use explicit parens.
8. **Custom operators** — extensions must go through `call(arg...)` and be documented.

## Workflow

1. Find the request type for the List/Search endpoint
2. Run the [checklist](#quick-audit-checklist) against the diff
3. Cite the AIP-160 section for each failure and propose a fix
4. Report findings grouped by severity (must-fix vs should-fix)

Deep semantics and worked examples live in [REFERENCE.md](REFERENCE.md).

## Output format

```
## AIP-160 Audit: <endpoint name>

### Must fix
- <issue> (<file>:<line>) — <citation>

### Should fix
- <issue> (<file>:<line>) — <citation>

### Notes
- <observations, deviations that are documented and acceptable>
```

## Reference

- [REFERENCE.md](REFERENCE.md) — operator tables, type coercion, traversal and has-operator edge cases
- [AIP-160](https://google.aip.dev/160)
- [EBNF grammar](https://google.aip.dev/assets/misc/ebnf-filtering.txt)
