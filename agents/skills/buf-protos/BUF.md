# BUF.md — CLI, Config, Generation

Every proto change goes through buf. Install, configure, run the five commands, wire into CI.

## Install

```bash
brew install bufbuild/buf/buf            # macOS
go install github.com/bufbuild/buf/cmd/buf@latest
buf --version
```

Latest stable. Workshop's `buf.yaml` is `version: v2`, requires buf ≥ 1.32.

## Five commands

Run from the `buf.yaml` directory (workshop: `api/`).

### `buf lint`

```bash
buf lint                         # All modules
buf lint workshop/v1/api.proto   # One file
buf lint --error-format=json     # CI
```

Enforces lint rules from `buf.yaml`. Workshop uses `STANDARD` (matches the Buf style guide):

```yaml
lint:
  use:
    - STANDARD
  ignore:
    - workshop/v1/santa.proto       # External
    - workshop/v1/risk_engine.proto # Legacy
```

Prefer per-rule `ignore_only` over removing rules globally:

```yaml
lint:
  use: [STANDARD]
  ignore_only:
    ENUM_VALUE_PREFIX:
      - workshop/v1/legacy.proto
```

### `buf format`

```bash
buf format -w           # Write in place
buf format --diff       # Preview
```

Run `buf format -w` before commit. Enforces file-layout order and whitespace.

### `buf breaking`

```bash
buf breaking --against '.git#branch=main,subdir=api'
buf breaking --against 'buf.build/northpolesec/workshop-api'
buf breaking --against '.git#tag=v1.5.0,subdir=api'
buf breaking --against image.binpb
```

Configure:

```yaml
breaking:
  use:
    - WIRE_JSON   # Published APIs
    # WIRE      — internal only
    # FILE      — strictest, source-incompatible too
    # PACKAGE   — strict per-package
```

Red? Read [EVOLUTION.md](EVOLUTION.md) before touching `ignore_only`.

### `buf build`

```bash
buf build                     # Type-check all modules
buf build -o image.binpb      # FileDescriptorSet image
```

CI type-check. Image feeds `buf breaking --against image.binpb` for offline comparisons.

### `buf generate`

```bash
buf generate --template buf.backend.gen.yaml
buf generate --template buf.frontend.gen.yaml
buf generate --template buf.docs.gen.yaml
```

Workshop runs three templates (backend Go, frontend TS, docs TS). Examples below.

### `buf dep`

```bash
buf dep update      # Refresh buf.lock
buf dep prune       # Remove unused
buf dep graph       # Dep tree
```

Run after editing `deps:` in `buf.yaml`.

## `buf.yaml`

Source of truth for lint/breaking/deps.

### Workshop's

```yaml
version: v2
modules:
  - path: .
    name: buf.build/northpolesec/workshop-api
lint:
  ignore:
    - workshop/v1/santa.proto
    - workshop/v1/risk_engine.proto
deps:
  - buf.build/googleapis/googleapis
  - buf.build/northpolesec/protos
```

No `lint.use` — `buf lint` defaults to `STANDARD` when omitted.

### Starting template

```yaml
version: v2
modules:
  - path: .
    name: buf.build/<org>/<module>
lint:
  use:
    - STANDARD
breaking:
  use:
    - WIRE_JSON
deps: []
```

### Fields

| Field | Purpose |
|---|---|
| `modules` | One per buf module (tree of `.proto` sharing deps). |
| `modules[].path` | Directory containing protos. |
| `modules[].name` | BSR module name (`buf.build/<org>/<module>`). Required to publish. |
| `lint.use` | Categories or rules. `STANDARD` matches the style guide. |
| `lint.ignore` | Skip entire files. |
| `lint.ignore_only` | Per-rule, per-file. Preferred over `ignore`. |
| `lint.rpc_allow_google_protobuf_empty_*` | Set `true` only if you must use `Empty` (don't). |
| `breaking.use` | `WIRE_JSON` (public) or `WIRE` (internal). |
| `breaking.ignore` / `ignore_only` | Same shape as lint. |
| `deps` | BSR modules. Resolved into `buf.lock`. |

## `buf.gen.yaml`

Tells buf which plugins to run and where output goes. Multiple templates per project are fine.

### Workshop's backend Go template

```yaml
# api/buf.backend.gen.yaml
version: v2
clean: true
managed:
  enabled: true
plugins:
  - remote: buf.build/protocolbuffers/go:v1.36.5
    out: gen
    opt:
      - default_api_level=API_OPAQUE

  - remote: buf.build/connectrpc/go:v1.19.0
    out: gen
    opt:
      - package_suffix
      - simple

  - local:
      - go
      - run
      - github.com/northpolesec/protoc-gen-go-mcp/cmd/protoc-gen-go-mcp@eb21a5d903135bd55bdd3f633646f3c37deab1d4
    out: gen
    opt:
      - paths=source_relative
      - package_prefix=github.com/northpolesec/workshop/api/gen
      - package_suffix=
      - trim_tool_prefixes=true
```

Notes:

- **`version: v2`** required.
- **`clean: true`** wipes output dir per run. Prevents stale files.
- **`managed.enabled: true`** lets buf rewrite file options at generation time. Use when one schema targets multiple languages.
- **`remote: buf.build/...`** — hosted, version-pinned, reproducible.
- **`local: [...]`** — plugins you maintain or off-BSR. Pin commits.
- **`out`** — plugin output directory.
- **`opt`** — plugin options.

### Workshop's frontend TS template

```yaml
# api/buf.frontend.gen.yaml
version: v2
clean: true
managed:
  enabled: true
plugins:
  - remote: buf.build/bufbuild/es:v2.2.3
    out: ../ui/gen
    include_imports: true
    opt:
      - target=ts
```

- **`include_imports: true`** — generate transitive imports too. Needed when consumers lack their own buf setup.
- **`target=ts`** — `protobuf-es` outputs `.ts` instead of `.d.ts` + `.js`.

### Patterns

- **One template per language/platform.** Don't cram backend Go and frontend TS into one file.
- **`clean: true` everywhere.**
- **Pin plugin versions.** `:v1.36.5`, not `:latest`.
- **Use `managed`** so language options derive from the schema.
- **Output to `gen/`.** `.gitignore` if CI regenerates; check in if you want diffs in PRs.

## `buf.lock`

Auto-generated, don't edit:

```yaml
# Generated by buf. DO NOT EDIT.
version: v2
deps:
  - name: buf.build/googleapis/googleapis
    commit: c17df5b2beca46928cc87d5656bd5343
    digest: b5:648a01e0170d4512dea7d564016165decd1ed6e34bef79fe54753e51ad7e27545709ad9157d7551270147d551155c595a2fb0bf5bb33b1c83040ddbce915c604
```

- Check into git alongside `buf.yaml`.
- Regenerate with `buf dep update` after editing deps.
- Merge conflict? Regenerate, don't hand-merge.

## CI

Per-PR checks for `.proto`:

```bash
buf format --diff
buf lint
buf breaking --against '.git#branch=main,subdir=api'
buf build
```

Workshop's Makefile:

```makefile
proto-gen:
	(cd api; buf generate --template buf.backend.gen.yaml; \
	         buf generate --template buf.frontend.gen.yaml; \
	         buf generate --template buf.docs.gen.yaml)
```

Add `make proto-gen && git diff --exit-code` to catch un-regenerated changes.

## Gotchas

- **`buf` runs in the `buf.yaml` dir**, not the repo root. Workshop: `cd api/` or `--config`.
- **Plugin versions must exist on BSR.** Typos fail with confusing 404s.
- **`subdir=api` in `--against`** needed when `buf.yaml` isn't at repo root.
- **`managed.enabled`** rewrites options in memory; your `.proto` still needs consistent file options ([STYLE.md](STYLE.md#file-options)). `managed` is for *different* options per target.
- **Editions** require buf ≥ 1.36 to lint/generate reliably. Pin CI's buf version.
- **`google.protobuf.Empty`** is rejected by `buf lint` default. Set `rpc_allow_google_protobuf_empty_*: true` only if forced. Workshop never does.

## BSR basics

```bash
buf login           # Once per machine
buf push            # From module dir
buf push --tag v1.5.0
```

Consumers depend by adding:

```yaml
deps:
  - buf.build/northpolesec/workshop-api
```

BSR also generates SDK packages (`buf.build/gen/go/...` — workshop's import paths) so consumers skip `buf generate`.
