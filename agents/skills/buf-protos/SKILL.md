---
name: buf-protos
description: Write, review, and evolve Protocol Buffer schemas using the Buf toolchain. Codifies file/package/message/enum/field/service/RPC naming, schema-evolution rules (reserved fields, wire compatibility), design conventions (oneof, maps, optional, well-known types), and the buf CLI workflow (lint, format, breaking, build, generate). Use when authoring or reviewing `.proto` files, designing RPC services, planning a schema change, debugging `buf lint`/`buf breaking` failures, configuring `buf.yaml`/`buf.gen.yaml`, or comparing a draft against workshop's `workshop.v1` conventions.
---

# Writing Protos with Buf

Codifies Buf's [style guide](https://buf.build/docs/best-practices/style-guide/), Google's [proto3 guide](https://protobuf.dev/programming-guides/proto3/) and [dos-and-don'ts](https://protobuf.dev/best-practices/dos-donts/), cross-referenced with `northpolesec/workshop` (`api/workshop/v1/`).

Each rule cites the buf lint rule that enforces it. Run `buf lint` before trusting the file.

## When to invoke

- Authoring a `.proto` file or service
- Adding/removing a field, RPC, or enum value
- Reviewing a PR touching `*.proto` or `buf.*.yaml`
- `buf lint` / `buf breaking` failing
- Configuring `buf.yaml`, `buf.gen.yaml`, or a plugin
- Designing a List/Get/Create/Update/Delete RPC surface

Not for: protobuf runtime, gRPC server logic, or generated code — only the schema.

## Five inviolable rules

1. **Never reuse a field number.** Old wire bytes exist in logs, queues, mirrors. Reuse corrupts deserialization. `reserved` deleted numbers and names.
2. **Never change a field's type or cardinality.** A few numeric coercions are wire-safe (see [EVOLUTION.md](EVOLUTION.md)); everything else corrupts data.
3. **Every enum's zero value is `_UNSPECIFIED`**, meaning "not set". No semantic meaning. ([`ENUM_ZERO_VALUE_SUFFIX`](https://buf.build/docs/lint/rules/#enum_zero_value_suffix))
4. **One package per directory, last component is a version.** `workshop/v1/*.proto` → `package workshop.v1;`. ([`PACKAGE_VERSION_SUFFIX`](https://buf.build/docs/lint/rules/#package_version_suffix), [`PACKAGE_DIRECTORY_MATCH`](https://buf.build/docs/lint/rules/#package_directory_match))
5. **Every RPC owns its request and response.** Never share. Never use `google.protobuf.Empty`. ([`RPC_REQUEST_RESPONSE_UNIQUE`](https://buf.build/docs/lint/rules/#rpc_request_response_unique))

## Quick-start workflow

```bash
# From the buf.yaml directory (workshop: `api/`)
buf lint                  # STANDARD style rules
buf format -w             # Format in place
buf breaking --against '.git#branch=main,subdir=api'   # Wire-compat vs main
buf build                 # Compile to FileDescriptorSet
buf generate --template buf.backend.gen.yaml           # Codegen
buf dep update            # Refresh buf.lock
```

Run `lint` + `format -w` + `breaking` before pushing `.proto` changes. If `buf breaking` fails, read [EVOLUTION.md](EVOLUTION.md) — don't paper over with `--ignore`.

## Authoring checklist

**File header (in order)**
- [ ] `edition = "2023";` (new files) or `syntax = "proto3";` (matching existing package)
- [ ] `package <name>.v<N>;` matching directory
- [ ] `import` statements, sorted, full paths from `proto_path` root
- [ ] `option go_package = "...";` — **identical across every file in the package** ([`PACKAGE_SAME_*`](https://buf.build/docs/lint/rules/#package_same_csharp_namespace))

**Naming**
- [ ] Filename `lower_snake_case.proto`
- [ ] Messages `PascalCase`, fields `lower_snake_case`, enums `PascalCase`, enum values `UPPER_SNAKE_CASE` prefixed with enum name (`RuleType` → `RULE_TYPE_*`)
- [ ] Services suffixed `Service`
- [ ] RPC request/response named `<RpcName>Request`/`<RpcName>Response`
- [ ] Repeated fields pluralized

**Field hygiene**
- [ ] First 15 numbers for hot fields (1-byte tag encoding)
- [ ] Secrets carry `[debug_redact = true]` (e.g., `VirusTotalPluginSettings.api_key`)
- [ ] Outgoing fields/RPCs carry `[deprecated = true]`
- [ ] Deleted fields `reserved` by **both number and name**
- [ ] `// next ID: N` trailing comment on churning messages

**Enums**
- [ ] First value `<ENUM_NAME>_UNSPECIFIED = 0;`, no semantics
- [ ] No `allow_alias` ([`ENUM_NO_ALLOW_ALIAS`](https://buf.build/docs/lint/rules/#enum_no_allow_alias))
- [ ] Two-state field that might gain a third → enum, not bool ([dos-and-don'ts](https://protobuf.dev/best-practices/dos-donts/#bools-for-two-states))

**Messages**
- [ ] Well-known types (`Timestamp`, `Duration`, `FieldMask`) — never `int64 unix_ts_seconds`
- [ ] `optional` on scalars where unset ≠ default
- [ ] Wrap `repeated` in a message when the list itself needs presence (`RepeatedString`)
- [ ] `oneof` for variants — never reorder members
- [ ] **No streaming RPCs** without strong reason ([Buf style guide](https://buf.build/docs/best-practices/style-guide/#streaming))
- [ ] Read-only RPCs: `option idempotency_level = NO_SIDE_EFFECTS;`

## Reference routing

| Task | File |
|---|---|
| Authoring a new file | [STYLE.md](STYLE.md) |
| Removing a field, renaming, or `buf breaking` red | [EVOLUTION.md](EVOLUTION.md) |
| Designing messages, enums, oneof, services | [DESIGN.md](DESIGN.md) |
| Setting up `buf.yaml`, generation, CI | [BUF.md](BUF.md) |

## Workshop as canonical example

`/Users/ericskram/code/work/workshop/repo/api/workshop/v1/` is the in-house reference. Check `api.proto` / `types.proto` / `santa_command.proto` first; diverge only with a stated reason.

Workshop conventions to replicate:
- `edition = "2023"` for new files
- Custom file-level options (`(workshop.v1.permission)`, `(workshop.v1.api_explorer)`)
- `[debug_redact = true]` on secrets
- `reserved N; // was OLD_NAME` on enum deletions
- `// next ID: N` trailing comment on churning messages

## Don'ts

Full list in [EVOLUTION.md](EVOLUTION.md) and [DESIGN.md](DESIGN.md).

- ❌ Reuse a field number
- ❌ Change a field's type (outside a few numeric coercions)
- ❌ Use `required` / `field_presence = LEGACY_REQUIRED`
- ❌ Use `google.protobuf.Empty` for request/response
- ❌ Share request/response messages across RPCs
- ❌ Hand-edit `gen/` — regenerate
- ❌ Skip `buf breaking` — clients you don't know about exist
- ❌ Language keywords as field names (`class`, `type`, `interface`)
- ❌ Reuse `java_package` / `go_package` across different proto packages
