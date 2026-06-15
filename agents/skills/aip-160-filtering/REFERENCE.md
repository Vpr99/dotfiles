# AIP-160 Reference

Filter syntax reference for [AIP-160](https://google.aip.dev/160). Companion to [SKILL.md](SKILL.md).

## Premise

One `string filter` field per request. Query-like syntax for non-technical users. Structured filter objects are an anti-pattern — they couple filter semantics to API revisions; the string form lets servers add fields without client changes. Related-object filtering goes through traversal or functions, never extra filter fields.

## Literals

A bare literal (`42`, `Hugo`) matches any field value on the object. Services restricting literal matching to specific fields **must** document the set; expanding it later risks breaking existing queries.

Whitespace separates literals as a fuzzy `AND`: `Victor Hugo` ≈ `Victor AND Hugo`.

## Logical operators

| Operator | Example       | Meaning                                |
| -------- | ------------- | -------------------------------------- |
| `AND`    | `a AND b`     | True if `a` and `b` are true.          |
| `OR`     | `a OR b OR c` | True if any of `a`, `b`, `c` are true. |

**Precedence: `OR` binds tighter than `AND`** — the opposite of most languages. `a AND b OR c` evaluates as `a AND (b OR c)`. Docs **should** encourage explicit parens; **must not** require them.

## Negation

`NOT a` and `-a` are equivalent. A service that supports negation **must** support both forms.

| Operator | Example | Meaning                  |
| -------- | ------- | ------------------------ |
| `NOT`    | `NOT a` | True if `a` is not true. |
| `-`      | `-a`    | True if `a` is not true. |

## Comparison operators

Supported for **string, numeric, timestamp, and duration** fields. **Not** for booleans or enums (use `=` only).

| Operator | Example      | Meaning                                         |
| -------- | ------------ | ----------------------------------------------- |
| `=`      | `a = true`   | True if `a` is true.                            |
| `!=`     | `a != 42`    | True unless `a` equals 42.                      |
| `<`      | `a < 42`     | True if `a` is a numeric value below 42.        |
| `>`      | `a > "foo"`  | True if `a` is lexically ordered after "foo".   |
| `<=`     | `a <= "foo"` | True if `a` is "foo" or lexically before it.    |
| `>=`     | `a >= 42`    | True if `a` is a numeric value of 42 or higher. |

**Asymmetry rule:** field name on LHS, literal on RHS. `a = b` (field-to-field) is not supported.

### Type coercion from query string

| Type      | Format                                                     |
| --------- | ---------------------------------------------------------- |
| Enum      | string form, case-sensitive                                |
| Boolean   | `true` / `false`                                           |
| Number    | int or float; exponents OK (`2.997e9`)                     |
| Duration  | numeric + `s` suffix: `20s`, `1.2s`                        |
| Timestamp | RFC-3339: `2012-04-21T11:30:00-04:00`, UTC offset OK       |

`true`, `false`, `null` carry intrinsic meaning only against typed fields. Elsewhere they're literal strings.

### String wildcard

`*` is a wildcard in string equality: `a = "*.foo"` matches when `a` ends with `.foo`.

## Traversal operator (`.`)

Walks through messages, maps, or structs.

| Example         | Meaning                                               |
| --------------- | ----------------------------------------------------- |
| `a.b = true`    | True if `a` has a boolean `b` field that is true.     |
| `a.b > 42`      | True if `a` has a numeric `b` field that is above 42. |
| `a.b.c = "foo"` | True if `a.b` has a string `c` field that is "foo".   |

Rules:

- Real field names only. Aliases or implicit fields go through `call()`.
- **No traversal through repeated fields** — except via `:`.
- Undefined message field → `INVALID_ARGUMENT`.
- Undefined map/struct key → service **may** allow; **must** document the behavior.
- Unset non-primitive link in the chain → entry skipped, even for `!=`. `a.b != 42` does not match when `a` is unset.

## Has operator (`:`)

Reads as "has". Semantics depend on the LHS type.

### Repeated fields / lists

| Example    | Meaning                                                     |
| ---------- | ----------------------------------------------------------- |
| `r:42`     | True if `r` contains 42.                                    |
| `r.foo:42` | True if `r` contains an element `e` such that `e.foo = 42`. |

No index access: `r[0].foo = 42` and `r.0.foo = 42` are invalid.

### Maps, structs, messages

| Example    | Meaning                             |
| ---------- | ----------------------------------- |
| `m:foo`    | True if `m` contains the key "foo". |
| `m.foo:*`  | True if `m` contains the key "foo". |
| `m.foo:42` | True if `m.foo` is 42.              |

### Top-level presence check

| Example    | Meaning                                  |
| ---------- | ---------------------------------------- |
| `r:*`      | True if repeated field `r` is present.   |
| `p:*`      | True if map field `p` is present.        |
| `m:*`      | True if message field `m` is present.    |

### Message-specific notes

- A message field is "present" only with a **non-default** value.
- Proto field names are **snake_case**. camelCase auto-conversion is allowed but must be documented.
- On maps and repeated fields, "unset" and "set-but-empty" both resolve to "not present".

## Functions

API-specific extensions use `call(arg...)` syntax. Each function **must** be documented. Escape hatch for geo proximity, full-text relevance, or computed fields — anything traversal can't express.

## Service-imposed limits

A service **may** add restrictions (e.g., cap `OR` clauses to prevent queries-of-death) but **must** document them and **must not** violate baseline AIP-160 requirements.

## Validation

Invalid filter strings → `INVALID_ARGUMENT`. Any relaxation **must** be documented.

Schematic validation (non-exhaustive):

- Referenced fields exist on the schema
- Values type-check (`age=hello` is invalid for `int32 age`)
- Enum values are in the allowed set
- Timestamps and Durations conform to their format

## Worked examples

### Go (gRPC) request shape

```go
// Compliant: one string filter, no parallel filter fields.
type ListBooksRequest struct {
    Parent    string `protobuf:"bytes,1,opt,name=parent"`
    PageSize  int32  `protobuf:"varint,2,opt,name=page_size"`
    PageToken string `protobuf:"bytes,3,opt,name=page_token"`
    Filter    string `protobuf:"bytes,4,opt,name=filter"`
}
```

Sample filter strings against `Book { string title; string author; Status status; Timestamp published_at; repeated string tags; map<string,string> labels; }`:

| Filter                                                        | Matches                                            |
| ------------------------------------------------------------- | -------------------------------------------------- |
| `Hugo`                                                        | Books with "Hugo" anywhere in matched fields       |
| `author = "Victor Hugo"`                                      | Exact author match                                 |
| `author = "*Hugo"`                                            | Author ending in "Hugo"                            |
| `status = PUBLISHED`                                          | Enum compare (only `=` / `!=`)                     |
| `published_at >= "2020-01-01T00:00:00Z"`                      | Timestamp comparison                               |
| `tags:"fiction"`                                              | Books whose `tags` repeated field contains fiction |
| `labels:"genre"`                                              | Books whose `labels` map has key "genre"           |
| `labels.genre = "fiction"`                                    | Books where `labels["genre"] == "fiction"`         |
| `author = "Hugo" AND (status = PUBLISHED OR status = DRAFT)`  | Explicit parens override OR's higher precedence    |

### TypeScript request shape

```ts
// Compliant
interface ListBooksRequest {
  parent: string;
  pageSize?: number;
  pageToken?: string;
  filter?: string;
}

// Anti-pattern — flag this in review
interface BadListBooksRequest {
  parent: string;
  authorFilter?: string;          // ← belongs in `filter`
  statusFilter?: Status;          // ← belongs in `filter`
  publishedAfter?: string;        // ← belongs in `filter`
}
```

## Cross-reference

- [SKILL.md](SKILL.md) — audit checklist and workflow
- [AIP-132](https://google.aip.dev/132) — standard `List` methods
- [CEL](https://github.com/google/cel-spec) — deterministic filter evaluation
- [EBNF grammar](https://google.aip.dev/assets/misc/ebnf-filtering.txt) — formal syntax
