# STYLE.md — Naming, Files, Layout

Mirrors the [Buf style guide](https://buf.build/docs/best-practices/style-guide/). Each rule cites the lint rule that enforces it. Workshop's `api/workshop/v1/` is the reference.

## File structure (top to bottom)

```protobuf
// 1. License header (optional)

// 2. File overview comment (optional)

// 3. Syntax / edition
edition = "2023";   // or: syntax = "proto3";

// 4. Package
package workshop.v1;

// 5. Imports — sorted alphabetically
import "google/protobuf/duration.proto";
import "google/protobuf/timestamp.proto";
import "workshop/v1/santa.proto";

// 6. File options — identical across the package
option go_package = "buf.build/gen/go/northpolesec/workshop-api/protocolbuffers/go/workshop/v1;workshopv1";

// 7. Everything else
service WorkshopService { ... }
message Rule { ... }
enum Decision { ... }
```

`buf format` enforces 3–7. ([style guide §file-layout](https://buf.build/docs/best-practices/style-guide/#file-layout))

## Files

- **Filename**: `lower_snake_case.proto`. ([`FILE_LOWER_SNAKE_CASE`](https://buf.build/docs/lint/rules/#file_lower_snake_case))
- **One file per top-level concern** — message group, service, or cyclic-dependency cluster. Workshop splits: `api.proto` (RPCs), `types.proto` (data), `santa.proto`, `santa_command.proto`. ([dos-donts](https://protobuf.dev/best-practices/dos-donts/#define-messages-in-separate-files))

## Packages

- **Lowercase, dot-separated**: `package workshop.v1;`. ([`PACKAGE_LOWER_SNAKE_CASE`](https://buf.build/docs/lint/rules/#package_lower_snake_case))
- **Last component is a version**: `v1`, `v1beta1`, `v2`. ([`PACKAGE_VERSION_SUFFIX`](https://buf.build/docs/lint/rules/#package_version_suffix))
- **Directory matches package**: `workshop/v1/*.proto` ↔ `package workshop.v1;`. ([`PACKAGE_DIRECTORY_MATCH`](https://buf.build/docs/lint/rules/#package_directory_match))
- **One package per directory.** No splitting across dirs.
- **Always declare a package** — avoids descriptor conflicts even when codegen ignores it. ([proto3 guide](https://protobuf.dev/programming-guides/proto3/#packages))
- **No language keywords in paths.** `foo.internal.bar` breaks Go (`internal` reserved). Skip `class`, `type`, `package`, `module`. ([style guide](https://buf.build/docs/best-practices/style-guide/#avoid-keywords))

## File options

Identical across every file in the same package ([`PACKAGE_SAME_*`](https://buf.build/docs/lint/rules/#package_same_csharp_namespace)):

```protobuf
option csharp_namespace      = "...";
option go_package            = "...";
option java_multiple_files   = true;
option java_package          = "...";
option php_namespace         = "...";
option ruby_package          = "...";
option swift_prefix          = "...";
```

- **`go_package`**: include the import path AND short alias (`...go/workshop/v1;workshopv1`). Without the alias, Go importers collide on bare `v1`.
- **`java_package`**: derive from the proto package. Never reuse across different proto packages. ([dos-donts](https://protobuf.dev/best-practices/dos-donts/#derive-java-package))
- **`java_outer_classname`**: only pre-edition-2024; `student_record_request.proto` → `"StudentRecordRequestProto"`.

## Imports

- **No `public` or `weak`.** ([`IMPORT_NO_WEAK`](https://buf.build/docs/lint/rules/#import_no_weak))
- **Sorted.** `buf format` does it.
- **Full paths from `proto_path` root**: `import "workshop/v1/santa.proto";`, not `import "santa.proto";`. Prevents collisions across packages.
- **Single `-I`** at the project root. Workshop's root is `api/`; files reference `workshop/v1/...`.

## Messages

- **Names**: `PascalCase` ([`MESSAGE_PASCAL_CASE`](https://buf.build/docs/lint/rules/#message_pascal_case))
- **Fields**: `lower_snake_case` ([`FIELD_LOWER_SNAKE_CASE`](https://buf.build/docs/lint/rules/#field_lower_snake_case))
- **Oneofs**: `lower_snake_case` ([`ONEOF_LOWER_SNAKE_CASE`](https://buf.build/docs/lint/rules/#oneof_lower_snake_case))
- **Plural for repeated**: `tags`, `binaries`. Singular for scalars: `name`, `id`.
- **Name field after its type** when reasonable: `BinaryBlockable` → `binary_blockable` (or `binary` if context implies the type).
- **Reserve removed field names AND numbers** — [EVOLUTION.md](EVOLUTION.md).
- **Document above the field**, `//` not `/* */`. Complete sentences. Over-document. ([style guide](https://buf.build/docs/best-practices/style-guide/#comments))
- **Trailing `// next ID: N`** — workshop convention for churning messages. See `Event` (`types.proto:274`).

```protobuf
message Event {
  // A randomly generated UUID for this event.
  string uuid = 1;

  // Details about the host that uploaded this event.
  Host host = 2;

  // ... 24 more fields ...

  // next ID: 27
}
```

## Enums

- **Names**: `PascalCase` ([`ENUM_PASCAL_CASE`](https://buf.build/docs/lint/rules/#enum_pascal_case))
- **Values**: `UPPER_SNAKE_CASE` ([`ENUM_VALUE_UPPER_SNAKE_CASE`](https://buf.build/docs/lint/rules/#enum_value_upper_snake_case))
- **Values prefixed `UPPER_SNAKE_CASE(<EnumName>)_`** ([`ENUM_VALUE_PREFIX`](https://buf.build/docs/lint/rules/#enum_value_prefix)). `RuleType` → `RULE_TYPE_*`. Required for C++ namespacing and editions codegen.
- **Zero value `<ENUM_NAME>_UNSPECIFIED = 0;`**, no semantics. ([`ENUM_ZERO_VALUE_SUFFIX`](https://buf.build/docs/lint/rules/#enum_zero_value_suffix))
- **No `allow_alias = true`.** ([`ENUM_NO_ALLOW_ALIAS`](https://buf.build/docs/lint/rules/#enum_no_allow_alias))
- **No C/C++ macro names**: `NULL`, `NAN`, `DOMAIN`, `INFINITY`. ([dos-donts](https://protobuf.dev/best-practices/dos-donts/#dont-use-cpp-macros))
- **Prefer semantic names over numeric**: `DEVICE_TIER_PRIMARY` beats `DEVICE_TIER_1`.

```protobuf
enum MaliciousState {
  MALICIOUS_STATE_UNSPECIFIED         = 0;
  MALICIOUS_STATE_BENIGN              = 1;
  MALICIOUS_STATE_FLAGGED             = 2;
  MALICIOUS_STATE_CONFIRMED_MALICIOUS = 3;
}
```

Workshop nests freely (`Rule.BlockReason`, `Host.OnDemandMonitorMode.OnDemandMonitorModeState`). Buf recommends against nesting since you may want to reference the type elsewhere later. If you nest, be ready to lift the type out via a wire-compatible move.

## Services

- **`PascalCase` + `Service` suffix.** ([`SERVICE_PASCAL_CASE`](https://buf.build/docs/lint/rules/#service_pascal_case), [`SERVICE_SUFFIX`](https://buf.build/docs/lint/rules/#service_suffix))
  - ✓ `WorkshopService`, `SantaCommandService`
  - ✗ `WorkshopAPI`, `Workshop`
- **RPC names: `PascalCase`, verb-first**: `ListHosts`, `CreateRule`, `GetCommand`, `DeleteAPIKey`. ([`RPC_PASCAL_CASE`](https://buf.build/docs/lint/rules/#rpc_pascal_case))
- **Dedicated Request/Response per RPC.** ([`RPC_REQUEST_RESPONSE_UNIQUE`](https://buf.build/docs/lint/rules/#rpc_request_response_unique))
  - Default: `<RpcName>Request` / `<RpcName>Response`
  - Cross-service collision: `<Service><RpcName>Request` (but avoid)
  - Never reuse. They'll diverge.
- **No `google.protobuf.Empty`** — define `message GetTenantRequest {}` instead. Buys room to add fields without a breaking change. ([style guide](https://buf.build/docs/best-practices/style-guide/#dont-use-empty))
- **Read RPCs**: `option idempotency_level = NO_SIDE_EFFECTS;`. Workshop sets this on every `List*`/`Get*`.
- **Avoid streaming.** Hard to proxy, hard to retry. Workshop's only stream is `WatchCommand`, with stated reason (live UI). ([style guide](https://buf.build/docs/best-practices/style-guide/#streaming))

## Custom options (workshop)

Workshop attaches cross-cutting metadata via custom options:

```protobuf
rpc ListRules(ListRulesRequest) returns (ListRulesResponse) {
  option (workshop.v1.permission) = {permission: "read:rules"};
  option (workshop.v1.api_explorer) = {
    method_group: "Execution Rules"
    docstring: "ListRules retrieves a paginated list of execution rules..."
    example: "{\"pageSize\":25,\"page\":1}"
  };
  option idempotency_level = NO_SIDE_EFFECTS;
}
```

New workshop RPCs must set `(workshop.v1.permission)` and `(workshop.v1.api_explorer)`. Read-only RPCs also set `idempotency_level = NO_SIDE_EFFECTS`.

## Comments

- `//`, never `/* */`.
- Above the type, not inline (except trivial one-liners on enum values).
- Complete sentences. Period at the end.
- Document *why*, not just what. Explain unusual values.
- Constraints in the comment — the schema can't enforce `Maximum 25 entries.` or `Must be 1–23.`, so the docs are the contract.
- Document field interactions (`If start_hour is unset, end_hour must also be unset.`).
