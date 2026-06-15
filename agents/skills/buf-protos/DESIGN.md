# DESIGN.md — Message, Enum, RPC, Service Design

Choices not covered by `buf lint` (style) or `buf breaking` (evolution). Enforced by review.

## Scalar types

| Need | Use | Don't use |
|---|---|---|
| Counts, IDs in 31 bits | `int32` | `int64` (2× wire bytes for large values) |
| Mostly-negative ints | `sint32` / `sint64` | `int32` (10-byte varint for negatives) |
| Always >2^28 / 2^56 | `fixed32` / `fixed64` | varint (5+ bytes anyway) |
| Time | `google.protobuf.Timestamp` | `int64 unix_seconds` |
| Duration | `google.protobuf.Duration` | `int64 timeout_millis` |
| Money | `google.type.Money` | `double amount_usd` |
| Date (no time) | `google.type.Date` | `string date_str` |
| Free-form bag | `google.protobuf.Struct` | `string json_blob` |
| Structured identifier | dedicated message | concatenated `string` |

Workshop uses `Timestamp` and `Duration` consistently. ([dos-donts](https://protobuf.dev/best-practices/dos-donts/#use-well-known-types))

## Field presence

**`optional`** when unset ≠ default:

```protobuf
optional uint32 batch_size = 2;             // 0 means default, not zero items
optional google.protobuf.Duration ttl = 7;  // unset means no cache
optional bool enabled = 1;                  // unset ≠ false
```

**Skip** when default IS the meaning:

```protobuf
string uuid = 1;          // empty = no value
repeated string tags = 4; // empty list fine
Decision decision = 9;    // _UNSPECIFIED is the unset marker
```

Editions 2023 defaults presence to EXPLICIT; every scalar tracks unset. Use `[features.field_presence = IMPLICIT]` per field for legacy proto3 semantics.

Workshop `SyncSettings` marks most scalars `optional` because every default is meaningful and settings merge.

## Booleans

> Two states today, three tomorrow → use an enum.

`bool active = 5;` becomes painful when product adds `pending` and `suspended`. ([dos-donts](https://protobuf.dev/best-practices/dos-donts/#bools-for-two-states))

Workshop has many `bool enabled = 1;` fields where binary really is binary. Use judgment.

## Enums

```protobuf
enum Decision {
  DECISION_UNSPECIFIED = 0;
  DECISION_ALLOW       = 1;
  DECISION_BLOCK       = 2;
}
```

- **Zero value `_UNSPECIFIED`**, always. Means "not set"; never a real state. ([dos-donts](https://protobuf.dev/best-practices/dos-donts/#include-unspecified))
- **Prefix values with the enum name** in `UPPER_SNAKE_CASE`. C++ enum values live in the parent namespace.
- **No `allow_alias`.**
- **Don't reuse values.** Same problem as field numbers; reserve removed values.
- **Reserve names** for TextProto/JSON safety.

### Open vs closed

- **Open** (proto3, editions default): unknown values preserved as int. Almost always what you want.
- **Closed** (proto2, opt-in): unknown values dropped to unknown fields. Avoid across release boundaries.

## Oneof

For **mutually exclusive variants**:

```protobuf
message RemovableMediaPolicy {
  oneof action {
    bool allow = 1;
    bool block = 2;
    RemountPolicy remount = 3;
  }
}

message KillProcessStart {
  string target_tag = 1;
  oneof process_target {
    KillProcessRunningProcess running_process = 2;
    string cdhash = 3;
    string signing_id = 4;
    string team_id = 5;
  }
}
```

Don't use oneof when:

- You actually want all-of (use multiple fields).
- You need `repeated` or `map` inside (not allowed — wrap in a single-field message).
- You think you'll convert a regular field later — moving in is wire-unsafe ([EVOLUTION.md](EVOLUTION.md)).

## Maps

```protobuf
map<string, BinaryBlockable> binaries_by_sha = 7;
```

- Keys: integer or string scalars. **Not** float, bytes, enums, messages.
- Values: any except another map.
- Maps **cannot be `repeated`**.
- Wire-equivalent to `repeated MapEntry { K key = 1; V value = 2; }` — refactorable with [EVOLUTION.md](EVOLUTION.md#wire-compatible-with-care) caveats.
- **Iteration order undefined.**
- **Duplicate keys**: last-wins on wire; may fail in text format.

Want `map<K, repeated V>`? Use `map<K, ListOfV>` wrapping the repeated.

## Repeated

- Plural names: `tags`, `binaries`, `processes`.
- Packed encoding by default for scalar numerics.
- **Can't tell empty from unset.** If that matters, wrap:

```protobuf
// types.proto:417
message RepeatedString {
  repeated string values = 1;
}

message SyncSettings {
  optional RepeatedString allowed_hosts = 3;  // unset ≠ empty
}
```

- **Never `repeated` → scalar.** [EVOLUTION.md](EVOLUTION.md#-wire-unsafe-breaking).

## Message size

Avoid hundreds of fields:

- C++ adds ~65 bits per field to the in-memory object.
- Java hits generated-class method-size limits.
- Readers can't hold it all.

Past ~30 fields, extract sub-structures. Workshop's `Rule` at ~24 is the upper end.

## Nested vs flat

Buf recommends flat. Workshop nests heavily (`Rule.BlockReason`, `Host.MetricsEntry`, `OnDemandMonitorMode.OnDemandMonitorModeState`).

- Be ready to lift later. Wire-safe (copy + update references); source-breaking downstream.
- Max 2 levels deep.
- Nest only types tightly bound to one parent. Cross-cutting types (`MaliciousState`, `Decision`) stay at file scope.

## Services

### Method checklist

- [ ] **Verb-first**: `List`, `Get`, `Create`, `Update`, `Delete`, `Search`, or domain verbs (`Trigger`, `Validate`, `Push`).
- [ ] **Dedicated Request/Response** — never reuse.
- [ ] **Reads**: `option idempotency_level = NO_SIDE_EFFECTS;`.
- [ ] **Mutations**: idempotent on identity (deleting a deleted thing is OK); error on unique constraints.
- [ ] **Lists**: page-size + page (workshop) or page-size + page-token (AIP-160). Include `bool more` or `string next_page_token`. Filter is a single `string filter` per [AIP-160](https://google.aip.dev/160).
- [ ] **Streaming**: only for real-time push. Workshop's only stream is `WatchCommand` with stated reason. ([style guide](https://buf.build/docs/best-practices/style-guide/#streaming))

### Keep cross-cutting concerns out of Request

Auth, request IDs, tracing, pagination cursors → metadata/headers. Exception: when the shape genuinely needs the data (e.g., `host_id` for `Watch`).

### Storage ≠ API

> Use different messages for RPC APIs and storage.

DB and wire schemas will diverge. Separate types + a translation layer pay for themselves the first time storage refactors. ([dos-donts](https://protobuf.dev/best-practices/dos-donts/#use-different-messages-for-rpc-apis-and-storage))

Workshop ignores this — same messages cross API and Postgres JSONB. Fine for a single client; riskier as the surface grows.

## Custom options

Define file/method/field options for things that affect every RPC:

```protobuf
// api.proto
rpc CreateAPIKey(CreateAPIKeyRequest) returns (CreateAPIKeyResponse) {
  option (workshop.v1.permission) = {
    permission: "write:apikeys"
    exclude_from_ai_chat: true
  };
  option (workshop.v1.api_explorer) = { ... };
}
```

Defined as extensions in `workshop/v1/api.proto` (importing `google/protobuf/descriptor.proto`). Single source of truth, machine-readable.

Don't add a custom option for one or two RPCs — put the data in the request.

## Security: `[debug_redact = true]`

```protobuf
optional string api_key = 2 [debug_redact = true];
optional string password = 3 [debug_redact = true];
optional string token = 2 [debug_redact = true];
optional string hmac_signing_secret = 5 [debug_redact = true];
```

Honored by protobuf debug-formatting and gRPC structured logging. Not encryption — keeps secrets out of logs and crash dumps. **Every credential gets one.**

## `Any` vs extensions

- **Prefer extensions.** `Any` loses type safety at the wire and forces readers to know the embedded type URL. ([dos-donts](https://protobuf.dev/best-practices/dos-donts/#prefer-extensions))
- `Any` belongs in generic infra (event bus propagating arbitrary messages).
- Proto3 extensions are limited to `descriptor.proto` types — file/message/method/field/enum/enum-value options. That's how workshop's `(workshop.v1.permission)` works.

## Anti-patterns

- **`string` for structured data.** Two fields wearing a trench coat. Give it a message.
- **`int64` for timestamps.** Use `Timestamp`.
- **Bare `bool` flags gating behavior.** Document or use an enum.
- **Serialized protos as cache keys.** Wire format not stable across builds. ([dos-donts](https://protobuf.dev/best-practices/dos-donts/#dont-rely-on-serialization-stability))
- **TextProto/JSON for interchange between binaries that rename fields.** Wire format is rename-safe; text isn't.
