---
name: designing-go-libraries
description: Design Go library and package APIs that stay backward compatible and future-proof - compatibility rules (exported means forever, interfaces are immutable), expansion tools (parameter/result objects, accept interfaces/return structs, upcast-to-upgrade, driver pattern), complexity hiding (parse early, narrow-and-deep packages), and modern idiom (iterators, generics, slog, errors.Is/As/AsType, config structs over functional options, the v2 playbook, deprecation with go:fix). Adapted to the NPS house style (shoenig/test, sentinel-first errors, zerolog services vs slog libraries, make fmt + golangci-lint). Use when designing or reviewing a Go package or API in any northpolesec repo or standalone library, adding a parameter/return/method to a published Go API, choosing config structs vs functional options, defining Go error types or interfaces, returning iterators vs slices, planning a v2/deprecation, or setting go.mod versions and release tags for a library.
---

# Designing Go Libraries

Core doctrine distilled from Abhinav Gupta's "Designing Go Libraries" (2022), "Future-Proof Go
Packages" (GopherCon 2023), and "Go Patterns and Practices" (2022), modernized against Go 1.18–1.27
official and community sources.

- [REFERENCE.md](REFERENCE.md) — the full core guidance: compatibility rules, expansion tools, complexity hiding, errors, goroutines, naming, docs.
- [MODERN.md](MODERN.md) — what changed since 2023: iterators, generics, slog, error nuances, versioning mechanics, module hygiene, new stdlib. Includes a scorecard of how each old rule aged.
- [HOUSE.md](HOUSE.md) — the NPS house style (surveyed from workshop/gal/coalmine + AGENTS.md): where house practice adjusts the guidance above, house tooling, tests, logging, deps. For house code, HOUSE.md wins conflicts.

## The rules everything serves

1. **Exported means forever.** When in doubt, leave it out; `internal/` is the compatibility firewall.
2. **Function signatures are fixed** — even adding variadic args breaks function references.
3. **Interfaces are immutable** — any change to a published interface breaks someone.
4. **Hyrum's law**: every observable behavior gets depended on. Constrain inputs, specify outputs, randomize what you don't promise.

## Quick decisions

**"I need to add a parameter / return value / method later":**

| Growing… | Tool |
| --- | --- |
| Function inputs | Parameter object (>3 params, ctx stays positional); new fields optional, zero value = old behavior |
| Function outputs | Result object (>2 returns, error stays separate) |
| An interface you accept | Upcast: new one-method interface + type-assert + graceful fallback (`io.WriteString`, `fs.StatFS`) |
| A type you return | Return `*Struct`, never an interface — add methods freely |
| Rich API over a small contract | Driver pattern: tiny interface wrapped by an exported struct (`http.Client`/`RoundTripper`) |
| None of the above works | New function / new package (`net/netip`), never in-place change. Type params can never be added to a published function |

**Configuration** — climb only as far as needed:
zero-value-usable struct fields (+ `cmp.Or` defaults) → config struct + constructor (required deps, validation) → functional options (only many optional evolving knobs on a widely-used API; sealed interface impl, no required options, never mixed with a param struct).

**Return type for a sequence:** `iter.Seq[T]` when lazy/large/streaming/composable (name it `All`/`<Noun>s`; `…Seq` suffix only beside a slice sibling); slice when small and materialized; never a channel. Pick and document an error convention: `Seq2[T, error]` (per-item) or `(Seq[T], func() error)` (terminal).

**Errors:** opaque `error` → sentinel `var ErrFoo` (+`errors.Is`) → exported `type FooError` (+`errors.As`/`AsType`, pointer receiver). This ladder is also the house default: sentinels for fixed conditions, a type only when the caller needs data. Wrap with `%w` freely inside the module; default `%v` at the public boundary (`%w` is an API contract). Messages: no "failed to", lowercase, `%q`. Never log-and-return.

**Tests (house):** `shoenig/test/must`, table-driven, `t.Context()`, `-shuffle=on -race`, exact-value and exact-error-code assertions. See [HOUSE.md](HOUSE.md).

**Logging:** libraries accept `*slog.Logger` (default `slog.DiscardHandler`) with `LogValue()` redaction on credential types; house *services* keep their zerolog `internal/log` wrappers — don't invent new logging interfaces either way.

**Interfaces:** consumers define them; keep them to the request path (no `Close`); convenience helpers are functions or driver-struct methods. Producer-side interfaces only for: single-op callbacks, real multiple implementations, middleware contracts, or when the interface *is* the product (`slog.Handler`).

## Design method

1. Work backwards: write the calling code first, then the doc comment, then implement.
2. Parse, don't validate — chaos (strings, maps, env, wire formats) becomes typed order once, at the boundary. Domain types stay separate from wire/DB types.
3. Sort by scope: app-scoped values → struct fields; request-scoped → method params. A `switch` on a field that never changes per call should be an injected implementation.
4. Business packages: narrow and deep. No `util`/`common`. No `FooManager`. Reuse vocabulary.
5. Dependencies are injected (`io.Reader`, not filename; `*slog.Logger`, default `DiscardHandler`; never `http.DefaultClient`, `os.Getenv`, or any process global outside `main`).
6. Goroutines: bounded, stoppable, waitable; none in `init()`. Better: stay synchronous, expose `Run(ctx) error`, leave concurrency to the caller.

## Shipping checklist

- [ ] `go` directive = oldest supported version (`1.(N-1).0` — and for house libraries, ≤ the oldest internal consumer's directive, it's viral), toolchain current; dependency floors minimal
- [ ] House tooling in place: `make fmt` target (`gofmt -s -w -e`, `go vet`), golangci-lint pinned via the `go.mod` `tool` directive with `.golangci.yml`, tests green under `-shuffle=on -race`
- [ ] No `internal/` types in exported signatures; no `replace` directives in a tagged release
- [ ] Exported API reviewed: every symbol earns its permanence (run `apidiff`/`gorelease` against the previous tag)
- [ ] Error contract documented; sentinels/types minimal; no wrapped third-party errors leaking at the boundary
- [ ] Slices/maps cloned or ordering documented at boundaries; inputs validated restrictively
- [ ] gopls `modernize` clean; examples use current idiom (`t.Context()`, `b.Loop()`, `wg.Go`, `omitzero`)
- [ ] `go mod tidy` (clean diff), `go vet`, `go test -race`, `govulncheck`, then tag — tags are immutable; `retract` is the only undo
- [ ] Deprecations say what to use instead; mechanical replacements get `//go:fix inline`
- [ ] Changelog: hand-written top section for breaking/behavioral changes, deprecations, floor bumps
