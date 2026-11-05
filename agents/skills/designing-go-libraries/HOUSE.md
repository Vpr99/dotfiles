# Designing Go Libraries — NPS House Style

How North Pole Security writes Go, surveyed from `workshop`, `gal`, and `coalmine` (2026-09)
plus the harness AGENTS.md. This layers on [REFERENCE.md](REFERENCE.md) and [MODERN.md](MODERN.md):
where they conflict, house style wins for house code. Services and libraries diverge on some
points; each section says which it applies to.

## Scorecard: where house practice adjusts the core guidance

| Core guidance | House position |
| --- | --- |
| Concrete error types over sentinels (MODERN, post-1.26) | **Sentinel-first blend.** All three repos default to `var ErrFoo = errors.New(...)` for fixed conditions; exported error *types* only when the caller needs data (`InvalidArgumentError`, API errors carrying a code). |
| Accept `*slog.Logger`, default `DiscardHandler` | **Libraries: yes. Services: no.** Workshop and GAL wrap zerolog in `internal/log` with GCP Cloud Logging field names; a shared library must not import zerolog — accept `*slog.Logger` and let services bridge via an `slog.Handler`. |
| `iter.Seq` default for sequences | **Allowed in new libraries, but novel here** — zero org-wide adoption at survey time. Document the chosen iterator error convention prominently; reviewers won't have seen it before. |
| Functional options rarely | **Both styles live here.** Config struct + constructor is the default; GAL's clients use options (`WithHTTPClient`, `WithCacheTTL`). Don't mix on one function. |
| `go` directive = `1.(N-1).0` | **Floor ≤ oldest internal consumer.** The directive is viral: check the `go` line of every house repo that might import you (GAL had the lowest at survey time). Services keep Go current and bump promptly. |
| Zero-dependency ethos | **Same instinct (ponytail: no new dependency if avoidable)**, with one written exception: security-relevant escaping (CSV formulas, HTML, shell quoting) uses a vetted library plus a test, never a hand-rolled regex. |

## Tooling (every repo, CI-enforced)

- `make fmt` before every commit: `gofmt -s -w -e .` and `go vet ./...`, plus per-repo formatters (buf, oxfmt). CI rejects unformatted code.
- golangci-lint pinned via the `go.mod` `tool` directive with a repo `.golangci.yml` (workshop, coalmine). New repos ship this from day one — retrofitting a lint backlog is expensive (workshop defers `modernize` with ~1.7k violations).
- Tests run `-shuffle=on` (GAL's Makefile) and `-race`, with timeouts.

## Tests

- **`github.com/shoenig/test/must`** is the house assertion library (219/53/35 imports across workshop/gal/coalmine). `must.Eq` diffs with go-cmp internally. Argument-order gotcha: `Less(t, expected, value)` asserts `value < expected`.
- `t.Context()`, never `context.Background()`. No `t.Fatal` or `must` off the test goroutine. Every wait gets a deadline. Release blocking resources in `t.Cleanup`. No `time.Sleep` for ordering.
- Assert the exact thing a regression breaks: exact values (not key presence), exact error codes (not `err != nil`), both sides of a replace. Delete tests that can't fail realistically.
- Prefer a direct test of a pure function over clock injection (and see MODERN: `testing/synctest` for real-time code).
- Tests and seeders call the same functions the production API uses — no test-only insert paths. Seed-only generators are named `...ForSeed` or `fake...`.
- Repo test conventions beat linters (e.g. GAL intentionally ignores `w.Write` errors in test handlers).

## Logging

- **Services**: zerolog behind `internal/log`, field names tuned so GCP Cloud Logging indexes severity and labels. Don't invent a new logging interface.
- **Libraries**: accept `*slog.Logger` in the config struct, default `slog.New(slog.DiscardHandler)`. Implement `LogValue()` redaction on any credential-bearing type (the slog analog of the proto `debug_redact` rule).
- Level discipline (both): ERROR pages someone; expected client/tenant failures are INFO or WARN; per-request detail is DEBUG. Log once when hitting an intentionally unhandled case so its frequency is observable. Clamp out-of-range config and log — never ignore silently.
- Never log-and-return the same error (house and REFERENCE agree).

## Errors and failing closed

- Sentinels for fixed conditions, typed errors for data; lowercase messages, `%q` for strings, no "failed to" prefixes (matches REFERENCE).
- **Fail closed** (house, stricter than the core material): an error never becomes `false` or `enabled`; a nil tenant/callback denies rather than skips; permission `switch` has no permissive `default`. Never attach identity to a ctx returned with an error.
- Name authn/authz functions for exactly what they do (`authenticateCaller`).

## Dependencies and helpers

- Grep for the existing helper before writing a loop, adapter, retry, pool, or encoder. In Workshop: `internal/utils` (`SliceMapFunc`, `SliceFilterFunc`, `SliceUnique`, `SliceSet`, ...), `retry.DoWithData` (avast/retry-go/v4), `pond/v2` worker pools, `pgText` sanitizer.
- Workshop helpers stay in Workshop. GAL is deliberately vanilla Go, GCP-only: no Workshop helpers, no runtime cloud switches. A shared library follows GAL's instinct: stdlib-first, minimal deps.
- Blessed common deps you'll see everywhere: `shoenig/test`, `alitto/pond/v2`, `hashicorp/go-retryablehttp`, `avast/retry-go/v4` (workshop).

## Data, bounds, and trust (library-relevant house rules)

- Constants: URLs, magic numbers, repeated strings are `const` at the top of the file; related constants in one block ordered by value.
- Never marshal a `proto.Message` with `encoding/json` — use `protojson`. Strings bound for Postgres go through `pgText` (NUL bytes).
- Stream, don't slurp: no `os.ReadFile`/`io.ReadAll` on data that can be large; sniff magic bytes from the open file, `io.Copy`, decompress to a temp file when a parser needs seeking.
- Bound every cache keyed by caller input (LRU + TTL). Max wait + backoff on every poll loop. Never hold a mutex across a network call. `cel.CostLimit` on any server-side CEL env.
- Trust boundaries: data from packages, plists, DB rows, and API callers is untrusted. `EvalSymlinks` then `filepath.Rel` for containment (or `os.Root`, per MODERN). Block loopback/private ranges on outbound fetches. Build URLs with `net/url`; redact to scheme+host in logs; never put a token in a URL path.
- No blank lines in import blocks. Remove dead code and unused `go.mod` deps. An exported function only tests use is dead code — move it to `_test.go` or delete it.
