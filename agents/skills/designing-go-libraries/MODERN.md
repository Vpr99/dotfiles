# Designing Go Libraries — Modernization (Go 1.18–1.27)

What changed since the 2018/2022/2023 source material. Anchored to Go versions, verified against
official Go blog posts, release notes, the Google Go Style Guide (updated through 2026), and
well-regarded community sources. Read [REFERENCE.md](REFERENCE.md) first; this file updates it.

## Scorecard: how the old advice aged

| Old advice | Status |
| --- | --- |
| Accept interfaces, return structs | **Confirmed**, now codified in the Google style guide with a named exception list. New carve-out: producer *may* export the interface when the interface **is the product** (a protocol: `slog.Handler`, `http.Handler`, `io.Reader`). |
| Parameter objects > functional options | **Confirmed, strengthened.** Community consensus moved to config structs by default; jub0bs publicly recanted after his GopherCon EU 2023 funcopts talk; River (`river.NewClient(driver, &river.Config{…})`) is the flagship modern example. |
| Return slices, scrutinize maps at boundaries | **Updated**: `iter.Seq[T]` / `iter.Seq2[K,V]` (Go 1.23) is now the default for lazy/large/streaming sequences. |
| Don't export error types; matcher funcs | **Reversed** (was already retracted in 2022): sentinels + `errors.Is`, exported types + `errors.As`/`errors.AsType`. Stdlib deprecated its own matcher funcs (`os.IsNotExist` docs say use `errors.Is`). |
| Inject a `*zap.Logger` | **Replaced**: accept `*slog.Logger`, default to `slog.New(slog.DiscardHandler)` (1.24). |
| Inject a clock interface for testability | **Weakened**: `testing/synctest` (GA 1.25) tests real `time`/`context` timeout code deterministically. Still prefer pure functions where trivial. |
| Inject process globals from `main` | **Confirmed** — Mat Ryer's widely-cited 2024 "How I write HTTP services" uses exactly `run(ctx, args, getenv, stdin, stdout, stderr) error`. |
| Upcast to upgrade interfaces | **Confirmed** — restated in Jonathan Amsterdam's "Evolving your API" (GopherCon EU 2025). |
| Keep a changelog | **Refined**: auto-generate the GitHub release, hand-write the top section (breaking/behavioral changes, deprecations, floor bumps). |

## Errors (updates to the 2022 talk)

- **The escalation ladder**: opaque `error` by default → sentinel `var ErrFoo` when callers branch on identity → exported error type when callers need data. Keep the exported set tiny (~3–5); every one is a forever-promise. Never expose the same failure as both a sentinel and a type at one boundary (or wire them with an `Is(error) bool` method).
- **`%w` is an API contract, not formatting** (official Go blog wording: wrapping "makes that error part of your API"). Inside your module, wrap freely. At the *public* boundary, default to `%v` — or translate infra errors into your own sentinels — and use `%w` across the boundary only deliberately and documented. Hyrum's law: once `errors.Is(err, sql.ErrNoRows)` works through you, your storage backend is frozen. Exception: pass through (or `%w`) `context.Canceled`/`DeadlineExceeded` — callers check those.
- **`errors.Join` (1.20)** replaces hand-rolled multierrors: nil-safe, `Unwrap() []error`, `Is`/`As` walk the tree. `fmt.Errorf` takes multiple `%w` — the idiom for "matches my sentinel *and* the cause": `fmt.Errorf("%w: %w", ErrNotFound, err)`. Gotcha: `errors.Unwrap` returns nil on joined errors.
- **`errors.AsType[E]` (1.26)**: generic `errors.As` — faster, no reflection, panic-free. Prefer in new code: `if e, ok := errors.AsType[*SyntaxError](err); ok { … }`. It also flipped the old perf argument for sentinels; jub0bs (2025) argues concrete error types now beat sentinels outright (extensible with fields later; can't be clobbered like a `var`; pointer receiver on `Error()` forces `errors.As`, which stays compatible when you add fields). If you anticipate needing data, start with a type.
- **No stack traces in library errors.** `pkg/errors` is archived. Stacks are an application/OTEL concern (`cockroachdb/errors` if an app wants them; `slog` `AddSource`).
- Document error contracts in doc comments: which sentinels/types a function returns, and that error *strings* are not API (`errors.Is`/`As` identity is; json/v2 explicitly carved out message text).

## Logging: slog

- First choice unchanged: **don't log, return errors**. Never log-and-return.
- If the library has real diagnostic events: accept **`*slog.Logger`** in the config struct. The frontend/backend split (`Logger` concrete, `Handler` interface) means this no longer couples to a backend — zap/zerolog/logr all ship `slog.Handler` adapters. Don't invent a project logging interface anymore. Accept a `slog.Handler` only if the library constructs loggers itself.
- Default when unset: `slog.New(slog.DiscardHandler)` (1.24) — silent is the polite library default. Never call `slog.SetDefault` from a library. Use `InfoContext`/`DebugContext` so handlers can lift trace IDs. Libraries log at Debug (maybe Info), never Error-and-return, never Fatal.
- Ship **`LogValue()`** (`slog.LogValuer`) on credential/config types so callers' logs can't leak them: `func (Token) LogValue() slog.Value { return slog.StringValue("REDACTED") }`. Caveat: not invoked on fields nested inside `slog.Any`-reflected structs — implement on the parent with an allow-listed `slog.GroupValue`.

## Context

- Unchanged: `ctx` first param; never in structs — with the two sanctioned exceptions (the `http.Request` retrofit pattern; interface-satisfaction shims bound at point of use). Prefer `DoContext(ctx, …)` twin methods for retrofits. A constructor that takes ctx just for `Done` is an anti-pattern — give the type `Close`/`Stop`.
- **Cancel with a cause** (1.20/1.21): when your library cancels a context it created (pool shutdown, watchdog), use `WithCancelCause`/`WithTimeoutCause` and `cancel(ErrPoolClosed)` so callers get `context.Cause(ctx)`, not a bare `context.Canceled`. Gotcha: `WithTimeoutCause`'s returned cancel func doesn't set the cause; only the deadline path does.
- **`context.WithoutCancel` (1.21)** for must-finish work detached from a request (audit write, flush): keeps values (trace IDs), strips cancellation — always re-bound with a fresh timeout. `context.AfterFunc` bridges cancellation into non-context-aware APIs.

## Iterators (Go 1.23) — the biggest API-shape change

- Sequence-producing APIs now default to **`iter.Seq[V]` / `iter.Seq2[K,V]`** — never bespoke func types, never channels. Caller `break` = cancellation; cleanup runs via `defer` inside the iterator when yield returns false. Channel-returning stream APIs are deprecated practice (leaks, no early stop); where a channel is genuinely right (event fan-in), *accept a caller-owned channel* (`signal.Notify` model) and document ownership/drop behavior.
- **Naming (normative, from the `iter` docs + stdlib)**: whole collection → `All()`; specific sequences → named (`Cities()`, `Backward()`); elements vs pairs → `slices.Values` vs `slices.All` (pairs!); configured → constructor args (`Scan(min, max)`); `…Seq` suffix *only* to disambiguate from an existing slice-returning sibling (`Split`/`SplitSeq`); brand-new sequences get plain names (`Lines`). Document single-use iterators explicitly.
- **Iterator vs slice**: iterator when lazy/large/unbounded/streaming/composable, or when you'd otherwise defensively copy an internal slice. Slice when small, materialized, and callers want `len`/indexing. If exposing only one, expose the iterator — `slices.Collect` bridges. Don't mass-migrate existing slice APIs; add iterator variants alongside.
- `iter.Pull` is a consumer-side tool (lockstep merging); don't return pull iterators from public APIs. Always `defer stop()`.
- **Errors in iterators are deliberately unsettled upstream.** Take a documented position: `iter.Seq2[T, error]` when items fail independently and iteration continues; `(iter.Seq[T], func() error)` terminal-error pair or a `bufio.Scanner`-style cursor (`Next/Value/Err`) when failure ends the stream. Say which one you chose in the doc comment.

## Generics

- Interfaces still win for behavior: "if all you need is to call a method, use an interface, not a type parameter" (Ian Lance Taylor). Generics are for identical algorithms across types and typed containers (`Set[E]`, `Cache[K,V]` beat `interface{}` storage). Prefer `cmp func(T, T) int` function parameters over method constraints so built-in types work.
- **Signature craft**: deconstruct composite types — `func Index[S ~[]E, E comparable](s S, v E) int` — so named types are accepted *and returned* (`slices.Clone(myIDs)` returns `IDs`). Use `~` underlying-type constraints by default. Use `cmp.Ordered`; define or copy small local constraints (duplicate constraints cause zero compatibility issues — the opposite of interfaces); no kitchen-sink constraints package.
- **New compatibility traps**: you can never add type parameters to a published function (new name or new package — the stdlib added `slices.Index` beside `strings.Index`). Tightening a constraint is a breaking change. Consumers can't add methods to instantiations of your generic types — design for composition. Generic type aliases (1.24) finally let you move/rename exported generic types compatibly.

## Functional options vs config structs (consensus shift)

The 2024–2026 default ordering, climbing only when required:

1. **Exported struct fields + useful zero value, no constructor** ("least mechanism"): apply defaults at point of use with `cmp.Or(cfg.Timeout, 30*time.Second)`; lazy-init internals with an unexported `sync.OnceValue`. `testing/synctest` and `cmp.Or` removed the main mechanical excuses for constructors.
2. **Config/parameter struct + constructor** when there are required deps, validation, or invariants. This is Abhinav's parameter object; it won.
3. **Functional options** only for widely-consumed libraries with many optional, evolving, defaulted knobs (gRPC `DialOption`, AWS SDK v2). When used: interface-based sealed `Option` (Uber style), options take parameters not presence (`FailFast(enable bool)` not `EnableFailFast()`), document last-wins, never required options, never mixed with a param struct.

The zero value of a new config field must reproduce the old behavior (unchanged rule). When a constructor is still required: external deps, must-fail validation, invariants zero can't hold, nil maps that would panic.

## Interfaces: 2026 refinements

- Consumer-defined interfaces still the default, with two written-down counterweights (Google guide, 2026): the **interface-is-the-product** exception (protocols meant for ecosystem convergence — `slog.Handler` is the reference design), and **mirrored-interface bloat** at scale (ten packages each defining the same `Authorizer` is a maintenance burden; a shared definition can be right).
- Don't pre-split interfaces for a single implementation; create the interface at 2+ implementations, a real testing seam, or a package boundary.
- **Test doubles**: don't export a fake from the API that consumes the interface ("no back doors for tests"); prefer testing through the real implementation's public API; a `footest` package now needs demonstrated demand, not anticipation. Fakes over mocks is settled; contract-test fakes against the real thing.

## Versioning & compatibility mechanics

- **`go.mod` is part of your API.** The `go` directive is a hard, viral minimum (1.21+). Libraries: set it to the **oldest version you support** — convention is `1.(N-1).0`, matching the two-release support window (`go mod init` itself defaults to N-1 since 1.26). Develop on the latest toolchain (the `toolchain` directive doesn't raise dependents' floors). Bump the directive deliberately; treat it as a minor-version event. Gate newer stdlib usage with `//go:build go1.N` files. Require the *oldest* dependency versions that have what you need.
- **Avoid v2, with the stdlib's demonstrated playbook when unavoidable** (math/rand/v2, encoding/json/v2): batch all breakage into one major; every change justified against real v1 usage; reimplement v1 as a wrapper over v2 so v1 users keep getting fixes. Costs are proven now: ecosystem split, `v1.T`/`v2.T` type-identity failures (the golang-jwt v4/v5 middleware mess). Prefer, in order: add symbols → options → new package in the same module (`net/netip` beside `net`) → deprecate + `go:fix` → v2. Incubate unstable APIs in v0, `internal/`, or an `/exp` submodule.
- **Deprecation**: `// Deprecated: use X.` paragraphs drive pkgsite hiding, staticcheck SA1019, and gopls strikethrough. Don't formally deprecate if the old API still works fine — just point docs at the new one. Deletion within a major version: never. **New since 1.26**: when the replacement is mechanical, ship a forwarding func annotated `//go:fix inline` — `go fix ./...` migrates callers automatically, even across packages/major versions. Wait one release after the replacement ships before deprecating.
- **CI gates**: `apidiff` on PRs (e.g. `imjasonh/apidiff-action`), `gorelease -base=<prev tag>` before tagging (it also flags `go`-directive and requirement bumps as minor events). Zero-dependency variant: golden-file test of your exported API surface (the Go team's `api/go1.N.txt` pattern). No tool detects behavioral breaks.
- **Behavioral compatibility (Hyrum's law, weaponized)**: Cox's taxonomy — output, input, protocol changes all break someone. Active defense: make unspecified behavior *visibly unstable* (Go randomized map iteration in 2012 for exactly this; proposal #70182 shuffles equal sort elements in tests). Document what's NOT covered: error text, output byte-stability, ordering of equal elements, timing. Give behavior changes an opt-out knob for one cycle and a release-note entry even when "compatible."
- **Releases are immutable** (module proxy + sumdb transparency log): never delete, re-tag, or force-push a tag — nothing recovers; tag a higher version, or `retract` it (publish a new version containing `retract vX.Y.Z // reason`; the bad version stays downloadable but stops being selected). Never tag with `replace` directives (ignored in dependents — you tested a different module than they get). `go mod tidy` with clean diff, `go vet`, `go test -race`, `govulncheck`, `gorelease` before every tag. Tag regularly — `go get` resolves to the newest *tag*, so an untagged year of work is invisible.

## Module hygiene

- Zero-dependency ethos, now a supply-chain argument: every dep you add is a trust decision forced on all dependents. Stdlib → `golang.org/x/*` → third-party only with strong justification.
- Module graph pruning (1.17+) means dependents don't inherit your test-only/tool-only requirement subgraphs. The `tool` directive (1.24) replaces `tools.go` — kill any remaining ones.
- One module per repo unless components have genuinely independent lifecycles (heavy optional integrations, `/exp`). Multi-module = per-directory tag prefixes and cross-module bump dances.
- `internal/` is the compatibility firewall (now official layout guidance: start flat, move support code to `internal/` first, everything outside it is forever). CometBFT's ADR-060 formalizes the extreme: all code except the deliberate public API under `internal/`.

## New checklist items with no 2018–2023 equivalent

- **`os.Root` (1.24)** for path trust boundaries: if the library combines a fixed directory with externally-supplied names (`filepath.Join(dir, userInput)`), operate through `os.OpenRoot`/`os.OpenInRoot` — or accept an `*os.Root` / `fs.FS` so the caller states the boundary.
- **`runtime.AddCleanup` (1.24)**, never `SetFinalizer`, and only as a safety net behind an explicit `Close()`.
- **`unique.Make` (1.23)** for interning massively repeated comparable values; `weak` pointers only after `unique` and plain LRU don't fit.
- **Stdlib is the helper library now**: don't export (or keep private copies of) `Contains`/`Keys`/min/max/multierror — `slices`, `maps`, `cmp`, `errors.Join`, `sync.OnceValue` cover them. Three-way `func(a, b T) int` comparators replaced `less` functions.
- **Doc comments are API surface**: `[Name]`/`[pkg.Name]` doc links, gofmt-canonicalized comments, runnable `Example` tests — pkgsite rendering is part of the design.
- **JSON-facing types**: implement `IsZero() bool` and prefer `omitzero` (1.24) over `omitempty` for "omit zero values" (handles `time.Time{}`); implement both v1 (`MarshalJSON`) and v2 (`MarshalJSONTo(*jsontext.Encoder)`) interfaces during the ecosystem transition.
- **Run the gopls `modernize` analyzer** over your code and examples — it's the mechanical definition of dated Go (`interface{}`→`any`, loops→`slices.Contains`/`maps.Copy`, `sort.Slice`→`slices.SortFunc`, `for b.N`→`b.Loop()`, `wg.Add/Done`→`wg.Go` (1.25), `context.Background()` in tests→`t.Context()` (1.24), `omitempty`→`omitzero`). A library whose examples fail it reads as pre-2021.
- **Long-running services expose `Run(ctx context.Context) error`** (blocking, returns on cancel) instead of Open/Close pairs — the caller owns concurrency via errgroup. "Leave concurrency to the caller" (Cheney's Zen of Go) is unchanged and restated everywhere.

## Key sources

Go blog: [go1.13-errors](https://go.dev/blog/go1.13-errors) · [compat](https://go.dev/blog/compat) (Cox 2023) · [randv2](https://go.dev/blog/randv2) (Cox 2024) · [jsonv2-exp](https://go.dev/blog/jsonv2-exp) (2025) · [when-generics](https://go.dev/blog/when-generics) (Taylor 2022) · [deconstructing-type-parameters](https://go.dev/blog/deconstructing-type-parameters) (Taylor 2023) · [range-functions](https://go.dev/blog/range-functions) (Taylor 2024) · [slog](https://go.dev/blog/slog) (2023) · [osroot](https://go.dev/blog/osroot) (Neil 2025) · [testing-time](https://go.dev/blog/testing-time) (Neil 2025) · [context-and-structs](https://go.dev/blog/context-and-structs) (2021) · [module-compatibility](https://go.dev/blog/module-compatibility) (2020) · [gofix](https://go.dev/blog/gofix) (2026).
Guides: [Google Go Style](https://google.github.io/styleguide/go/) (2022, updated 2026) · [Uber Go Style Guide](https://github.com/uber-go/guide/blob/master/style.md) · [Go Doc Comments](https://go.dev/doc/comment) · [Organizing a Go module](https://go.dev/doc/modules/layout) · [Go Wiki: Deprecated](https://go.dev/wiki/Deprecated).
Community: Jonathan Amsterdam "Evolving your API" (GopherCon EU 2025) · Mat Ryer ["How I write HTTP services after 13 years"](https://grafana.com/blog/how-i-write-http-services-in-go-after-13-years/) (2024) · jub0bs on [concrete error types](https://jub0bs.com/posts/2025-03-31-why-concrete-error-types-are-superior-to-sentinel-errors/) (2025) and his [funcopts reversal](https://jub0bs.com/posts/2024-04-27-jub0bs-cors-a-better-cors-middleware-library-for-go/) (2024) · Sinclair Target on [iterator errors](https://sinclairtarget.com/blog/2025/07/error-handling-with-iterators-in-go/) (2025) · Cheney ["The Zen of Go"](https://dave.cheney.net/2020/02/23/the-zen-of-go) · [CometBFT ADR-060](https://github.com/cometbft/cometbft/blob/main/docs/references/architecture/adr-060-go-api-stability.md).
