# Designing Go Libraries — Core Reference

Distilled from Abhinav Gupta's [Designing Go Libraries](https://abhinavg.net/2022/12/06/designing-go-libraries/) (2022),
[Future-Proof Go Packages](https://abhinav.github.io/future-proof-packages-2023/) (GopherCon 2023), and
[Go Patterns and Practices](https://abhinav.github.io/presentation-go-patterns-2022/) (2022).
For post-2023 updates (generics, iterators, slog, errors nuances, module practice), see [MODERN.md](MODERN.md).

## The three rules

Everything in this document exists to serve these compatibility rules:

1. **Exported means forever.** You cannot remove or rename any exported function, type, variable, or constant once published in a stable release.
2. **Function signatures are fixed.** You cannot add a parameter or return value. Adding *variadic* args also breaks: function *references* (`Process(ctx, ListPosts)`) no longer type-check.
3. **Interfaces are immutable.** Adding a method breaks every third-party implementation (mocks, middleware, fakes). Removing or changing one breaks every caller. Any change to a published interface breaks someone.

A breaking change is: renaming/removing an exported entity, changing its type, changing a signature, adding a method to an exported interface, or violating a documented behavioral contract. Breaking changes are expensive even for internal libraries — avoid them for as long as possible. Semver communicates them; it does not make migrations free.

**Hyrum's Law:** with enough users, every observable behavior gets depended on, documented or not. Reduce unknown outputs:

- Validate inputs restrictively at entry; you can loosen later, never tighten.
- Return the zero value with an error (`return nil, err`), not partial results, unless partial results are the contract (`Writer.Write`).
- Decide whether returned-slice order is contract; if internal order could leak, sort at the boundary.
- If you accept or return a slice/map that aliases internal state, clone at the boundary.

## Four axes to maximize

- **Usability**: easy to use correctly, hard to misuse. Make common tasks easy (`http.Get`), uncommon tasks possible (`Client.Do`), and establish conventions so users can guess their way to APIs.
- **Readability**: the *calling* code should read clearly. Field and function names are your lever.
- **Flexibility**: users can extend/customize without you (e.g. `http.Client.Transport` / `RoundTripper`).
- **Testability**: users can swap your components for fakes. Consider a `footest` package. Design this in from the start.

**Work backwards:** write pseudo-code that *uses* the API before implementing it. Design → document → implement. Ask: can you tell what it does from the call site? What's the contract? How will users test code that calls this?

## Surface area

Surface area = everything exported. Smaller surface = more freedom to refactor.

- When in doubt, leave it out. You can always export later; you can never unexport.
- Don't export for "maybe" use cases. (Case study: nine `As*`/`TryAs*` methods deleted pre-1.0 in favor of one `Populate`; nobody ever asked for them back.)
- Use `internal/` liberally: helpers, code-organization packages, anything not core contract. Never reference an internal type in an exported signature.
- Business packages should be **narrow and deep**: few entry points hiding a lot of work (`archive/tar`), not many shallow helpers (`userutil.GetUserList`, `FilterUsers`, `UserIsAdmin`). Wide-and-shallow packages force callers to zigzag in and out and leak intermediate state. Find the noun the helpers are all *for*, give it a single entry point.

## Planning for expansion

|                    | Input (📥)          | Output (📤)     |
| ------------------ | ------------------- | -------------- |
| **Functions**      | Parameter objects   | Result objects |
|                    | Functional options (both) |         |
| **Abstractions**   | Accept interfaces   | Return structs |

### Parameter objects

A struct **exclusively** for one function's parameters (not a shared domain type). `context.Context` stays a separate first positional arg.

```go
type DeleteUserRequest struct {
    Name       string
    SoftDelete bool // added later: optional, zero value = old behavior
}
func DeleteUser(ctx context.Context, req DeleteUserRequest) (DeleteUserResponse, error)
```

- Rule of thumb: more than 3 parameters (excluding ctx) → it will grow → use a parameter object.
- New fields must be optional, and the **zero value must reproduce the old behavior** (that decides `OmitSlash` vs `AddSlash`).
- Bonus: named fields kill argument-order bugs (`NewUser(firstName, lastName, email)`).

### Result objects

Same idea for returns; `error` stays a separate last return value.

- Rule of thumb: more than 2 results (excluding error) → use a result object.
- Field names are the readability lever: callers must write `res.ContinueAt`, so name it well.

### Functional options

**Not the default — prefer parameter objects.** Reach for options only when there are *many* optional knobs, *few* required params, and a good zero-argument default. Costs: heavy boilerplate, opaque values (hard to test/inspect), corner cases (same option twice: replace or merge?), each option name occupies the package namespace forever.

Rules when you do use them:

- Required parameters stay positional. Never a required option.
- Never mix options and a parameter object on one function.
- Implement as a **sealed interface**, not bare `func(*options)`: options become printable and comparable, and you keep an upgrade path.

```go
type Option interface{ apply(*options) } // unexported method seals it

func WithTimeout(d time.Duration) Option { return timeoutOption{d} }

type timeoutOption struct{ d time.Duration }
func (o timeoutOption) apply(opts *options) { opts.timeout = o.d }
```

- Options can *return* results: `QueryStats(&stats)` takes a pointer the function fills — compute only when requested.
- Can't add `...Option` to a published function (breaks function references). If you foresee options, ship the sealed `Option` type with zero constructors from day one.

### Accept interfaces

Dependencies you *consume* should be interfaces, as narrow as the need: `io.Reader`, not `*os.File`. Declare your own interface for types you don't own; add a compile-time check:

```go
type Source interface {
    io.Reader
    Name() string
}
var _ Source = (*os.File)(nil)
```

Accept, don't instantiate: take the established `*sql.DB`/connection/file handle as an argument; opening it is the caller's job. Offer a `NewFromFile(name string)` convenience wrapper only if the common case earns it.

### Return structs

Producers export concrete types; **consumers define interfaces**. `func New() *Client`, never `func New() Client` backed by a private impl. Returning an interface is unnecessary (Go matches interfaces structurally), inflexible (you can never add a method), and forces a constructor.

Producers legitimately define interfaces for: single-operation "callback-grade" interfaces, genuinely multiple implementations consumers switch between, and middleware/wrapper contracts.

### Upcast to upgrade

The only compatible way to *require more* from an accepted interface: define a new interface embedding (or accompanying) the old one, type-assert, degrade gracefully.

```go
func WriteString(w Writer, s string) error {
    if sw, ok := w.(StringWriter); ok {
        return sw.WriteString(s)
    }
    return w.WriteBytes([]byte(s))
}
```

Stdlib precedent: `io.WriteString`, `io/fs` (`StatFS`, `ReadFileFS`). Caveats: **wrapping silently severs the upgrade path** (a `struct{ io.Reader }` wrapper loses `Name()`), so document upgrade interfaces prominently and keep them to one method. Convenience helpers built this way can't hold state — for that, use the driver pattern.

### Driver pattern (strong core)

Small, powerful interface at the bottom; rich exported struct wrapping it on top. Implementers write one method; consumers get many; the struct can hold state and can still upcast the driver for fast paths.

```go
type Driver interface{ WriteBytes([]byte) error }

type Writer struct{ drv Driver }
func (w *Writer) WriteBytes(bs []byte) error { return w.drv.WriteBytes(bs) }
func (w *Writer) WriteString(s string) error { // added later: compatible
    if sw, ok := w.drv.(StringWriter); ok { return sw.WriteString(s) }
    return w.WriteBytes([]byte(s))
}
```

Precedents: `zap.Logger`/`zapcore.Core`, `http.Client`/`http.RoundTripper`, `database/sql`/`database/sql/driver`.

## Hiding complexity (the future-proofing lens)

A package is future-proof when it can grow without disrupting unrelated code. Disruption comes from designs that leak complexity.

**Flow of information.** Information should flow one direction without backtracking. Parse chaos (strings, raw bytes, env vars) into structured order once, early, at the boundary — "Parse, don't validate." If multiple functions re-inspect the same string (`isHTTP(addr)`, `isSSH(addr)`, `strings.TrimPrefix` downstream), that's a leak: parse to `*url.URL` once. Zigzagging flow between packages signals a leak or tight coupling.

**Scope.** Not lexical scope — how long a value stays constant, a gradient from application scope (`os.Args`) to request scope (`*http.Request`). Use it to design:

- Struct fields = larger-scoped values; method parameters = request-scoped values.
- Interfaces get **request-path methods only**. `Get`/`Set` yes; `Close` no — it runs once, in main, on the concrete type.
- Convenience methods implementable via the interface (`SetMany` looping `Set`) stay off it: top-level function or driver-pattern struct method.
- Order parameters by scope, big to small: `GetUser(client, org, login)`.
- Partial application: parameters that never change per call site (the `*http.Client`, maybe the org) get promoted into a struct; the function becomes a method.

**Large-scoped conditions.** A `switch g.LinkStyle` inside a per-page method re-decides something fixed for the whole run. Decide once in the outer scope and inject the behavior (a `LinkStyler` implementation). Same for `if production {…}` sprinkled around: inject the production or dev object once.

**Built-in obsession.** Reluctance to declare types leaks complexity:

- *Strings*: don't pass structure-in-a-string around; parse to a struct early (see flow).
- *Maps at boundaries*: `map[string]string` is uninformative (key? value?) and hard-codes a uniqueness constraint that may not be business-true. Accept `[]RegisterRequest` and enforce uniqueness internally, if it's even required. Maps crossing package boundaries deserve extreme scrutiny.
- *Booleans*: a bool per feature request (`OmitSlash`) is rigid; two bools have four states. Integrate the feature into the abstraction instead: an enum (`LinkStyle`, zero value = old behavior) or an injected strategy. "Don't add features — integrate them."
- *Callbacks*: `func(string) string` struct fields are opaque (can't inspect, compare, or extend). Prefer a single-method interface; it can be upcast-upgraded later (`PageLinkStyler`).

**Exposed wire form.** If the type in your public API is also the type you serialize to the database or wire, that's a leak. Keep a separate wire/DB type and an explicit conversion step.

**Global state.** No package-level mutable state; put state in a struct with a constructor. Beyond your own globals, don't touch **implicit process globals** (`os.Stdout`, `os.Stderr`, `os.Getenv`, `os.Args`) outside `main`. Extract early and inject:

```go
type App struct {
    Stdout io.Writer
    Stderr io.Writer
    Getenv func(string) string
}
func (*App) Run(args []string) (exitCode int)
```

Never consume `http.DefaultClient`/`http.Get` inside a library — accept the client.

## Errors

(From the 2022 talk — the 2018 "don't export error types" advice is obsolete. See MODERN.md for post-1.20 additions.)

For each *leaf* error ask: **should the caller be able to handle it programmatically?**

- **No** → plain `errors.New` / `fmt.Errorf`. Don't make it complicated.
- **Yes, fixed condition** → sentinel: `var ErrNotExist = errors.New("file does not exist")`. Prefix `Err`, terse name (`ErrExist`, not `ErrFileAlreadyExists`). Matched with `errors.Is`.
- **Yes, with data** → structured error type: `type SyntaxError struct{ Line, Column int }`, suffix `Error`, pointer receiver on `Error()`. Matched with `errors.As`.

Propagating: wrap with `fmt.Errorf("load config: %w", err)`; a structured wrapper gets an `Unwrap() error` method so `errors.Is/As` still reach the cause.

Messages: no `failed to` / `error doing` prefixes (chains make them noise); lowercase first letter; `%q` for strings (empty/weird values stay visible).

**Never log and return the same error** — the caller will log it again. One or the other.

## Goroutines

- Every goroutine must finish or be stoppable, and you must be able to *wait* for it. No fire-and-forget; never start goroutines in `init()`.
- Goroutine count must be bounded and independent of request contents — a worker pool, not one goroutine per item.
- Prefer `context.Context` for stop signals (`select` on `ctx.Done()` + `time.Ticker`, not `time.Sleep` loops); a `sync.WaitGroup` (or errgroup) so `Stop()` actually waits.
- Test with `go.uber.org/goleak`.

## Reflection

Use `reflect` sparingly: only with confident understanding, never on hot paths. Reflection panics on wrong inputs — coverage doesn't prove correctness.

## Naming, docs, changelog

- No `FooManager` — name the thing for what it does (`http.ServeMux`, not `HandlerManager`). No `util`/`common`/`helpers` kitchen sinks.
- Short generic package names force named imports; qualify with the parent (`zapcore`, `httptest`) when the package is widely imported.
- Reuse vocabulary: if you have `UserDetails`, the next one is `PostDetails`, not `PostData`. Every new term is another concept in the user's mental model.
- Docs are for users, not maintainers: purpose, usage, contract — not implementation. Don't bury the lede; skimmers search. Runnable `Example` tests beat prose. No non-documenting docs ("RequestHandler handles requests").
- Keep a changelog for users, separate from the commit log (keepachangelog.com format). Edit it before each release.

## Before you write it at all

- A library is a maintenance commitment with no end date. Check for an existing library first; vet code quality, tests, docs, and above all **active maintenance** — or be ready to fork.
- Set a documented Go version support policy (commonly: current and previous minor release).
