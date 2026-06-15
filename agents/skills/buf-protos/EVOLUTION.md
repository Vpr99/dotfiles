# EVOLUTION.md — Schema Evolution & Wire Compatibility

Read this before deleting, renaming, or retyping anything. If `buf breaking` is red, the answer is here.

## Cardinal rule

> Clients and servers are never updated at exactly the same time. Either may roll back.

Every "is this safe?" decision flows from that. Old serialized data lives in logs, queues, mirrors, on-disk caches, and rolled-back replicas. Every change must survive every prior version still in flight.

## Field numbers: immutability

### Never reuse a field number

A field number is forever. Old bytes encoded with that number live in:

- Logs
- In-flight queue messages
- Rolled-back binaries still emitting it

A new field with the same number decodes old bytes as the new type — silent corruption, leaked PII, or parse failures. ([dos-donts](https://protobuf.dev/best-practices/dos-donts/#dont-re-use-a-tag-number))

### Always reserve removed numbers AND names

```protobuf
message Foo {
  reserved 2, 9, 15 to 17;
  reserved "old_field", "deprecated_thing";
}
```

- **Numbers** prevent wire-level reuse.
- **Names** prevent reuse in TextProto/JSON (which key by name).
- **Cannot mix** numbers and names in one `reserved` — use two.
- Same applies to enums: `reserved 4; reserved "OLD_VALUE";`

Workshop pattern (`api.proto:842`):

```protobuf
reserved 46; // was AUDIT_EVENT_SETTINGS_TELEMETRY_CLOUD_BUCKET_UPDATE
```

Leave a comment naming what was there.

### Field number ranges

| Range | Notes |
|---|---|
| 1–15 | 1-byte tag. Use for hot fields. |
| 16–2047 | 2-byte tag. |
| 19000–19999 | **Reserved by protoc.** Compiler rejects. |
| Up to 536,870,911 | Max. |

Past field 30 in a hot message, audit 1–15 for unused slots before climbing higher.

## The wire-compatibility table

### ✅ Wire-safe (always)

- **Add a new field** with a new number.
- **Remove a field** AND reserve its number and name.
- **Add new enum values.** Old code preserves them as unknown.
- **Move a singular field into a NEW oneof** (one that didn't exist before).
- **Single-field oneof ↔ explicit-presence field.**
- **Field ↔ extension** (same number and type).
- **Rename a field** at the wire level. Breaks TextProto, JSON, and reflective code — treat as breaking unless certain nobody uses those.

### ⚠️ Wire-compatible with care

**Numeric type swaps within groups:**

| Group | Members | Notes |
|---|---|---|
| varint ints | `int32`, `int64`, `uint32`, `uint64`, `bool` | Interchangeable. Negative `int32` round-trips as 10-byte varint when read as `uint64`. |
| zigzag | `sint32`, `sint64` | Each other only. **Not** with varint ints. |
| fixed 32 | `fixed32`, `sfixed32` | Each other only. |
| fixed 64 | `fixed64`, `sfixed64` | Each other only. |

Cross-group swaps (e.g., `int32` → `sint32`) **corrupt data**.

**Other careful swaps:**

- `string` ↔ `bytes` — safe if UTF-8.
- Message ↔ `bytes` — safe if bytes hold a valid encoded message.
- `singular` ↔ `repeated` (strings, bytes, messages) — last-wins for primitives, merge for messages. **Not for numerics** (packed encoding).
- `enum` ↔ varint ints — unknown values preserved as int.
- `map<K,V>` ↔ `repeated MapEntry { K key; V value; }` — iteration may reorder; duplicate keys drop.

### ❌ Wire-unsafe (breaking)

- **Change a field number.** Equivalent to delete + add.
- **Move a field INTO or OUT of an existing oneof.** Silent data loss.
- **Split or merge oneofs.**
- **Change a field's type** outside the safe groups.
- **Change a field's default** (proto2 only; proto3 removed it). ([dos-donts](https://protobuf.dev/best-practices/dos-donts/#dont-change-defaults))
- **`repeated` → scalar.** Numerics lose everything; non-numerics keep last; JSON loses the message. (Scalar → repeated is safe.) ([dos-donts](https://protobuf.dev/best-practices/dos-donts/#dont-go-from-repeated-to-scalar))
- **Add a `required` field.** Proto3 has none; editions: don't set `field_presence = LEGACY_REQUIRED`. Validate in code, document `// required`. ([dos-donts](https://protobuf.dev/best-practices/dos-donts/#dont-add-required))

> Published schemas: don't make even "wire-compatible" changes. Internal services with controlled clients can take the risk.

## Oneof hazards

- Setting any member **clears all others.** In C++, this destructs the previous message — dangling pointers if you held a reference.
- Multiple oneof members on the wire: **last one wins by proto-file order.**
- Setting a member to its default (oneof int = 0) **still sets the case.** Oneof tracks "which field was set", not "non-default".

### Safe

- **Add new members.** Old readers may not preserve unknown variants across the oneof — test it.
- **Reserve removed members.**

### Unsafe

- **Move a field into a oneof.** Old data with multiple set fields collapses to last-wins; the rest is discarded.
- **Move a field out of a oneof.** Same problem in reverse.
- **Split or merge oneofs.** Cases stop matching.

Restructuring needs two releases: add the new shape alongside, migrate readers, then remove the old.

## Renaming

Wire format keys on number, but renames still break:

- **JSON / TextProto / reflective code** key on name.
- **Generated accessors** change (`get_foo()` → `get_bar()`) — source-breaking for every consumer.
- **gRPC method names** are part of the URL.

Treat all renames as breaking unless every consumer is audited.

Editions provide `[field_name_legacy = "old_name"]` — see [editions docs](https://protobuf.dev/editions/).

## Default values & presence

- **Implicit-presence scalars** (proto3 default, no `optional`): can't distinguish unset from zero/empty. Zero values never appear on the wire.
- **Explicit-presence scalars** (`optional` in proto3, `features.field_presence = EXPLICIT` in editions): unset is distinguishable. Serialized only when set.
- **Message-typed fields**: always presence-tracked.

Use `optional` on every scalar where "unset" matters — usually most of them. Workshop does this in `SyncSettings`, `RemoteRiskEnginePluginSettings`.

**Don't change presence after the fact.** Implicit → explicit changes wire serialization (zeros now appear). Old readers may misbehave.

## `buf breaking` workflow

```bash
# From the buf module dir (workshop: api/)
buf breaking --against '.git#branch=main,subdir=api'

# Against a BSR module
buf breaking --against 'buf.build/northpolesec/workshop-api'

# Against a tag/commit
buf breaking --against '.git#tag=v1.5.0,subdir=api'
```

Configure in `buf.yaml`:

```yaml
version: v2
breaking:
  use:
    - WIRE_JSON   # Wire + JSON (default for published APIs)
    # WIRE      — wire only (internal)
    # FILE      — strict, source-incompatible too
    # PACKAGE   — strict per-package
```

When flagged, your options:

1. **Revert.** Default answer.
2. **Bump the package version.** `v1` → `v2`. Migrate clients on a deadline.
3. **Add alongside, deprecate, delete after rollout.** Workshop does this with `Rule.rule_id` → `Rule.id` (line 14, `[deprecated = true]`).
4. **`ignore_only` in `buf.yaml`** — only after auditing every consumer. Document why.

```yaml
breaking:
  use: [WIRE_JSON]
  ignore_only:
    FIELD_SAME_TYPE:
      - workshop/v1/types.proto
```

Frequent `ignore_only` use means you're not doing breaking-change detection — fix the discipline, not the config.

## Deprecation

Mark before removing:

```protobuf
string rule_id = 1 [deprecated = true];

rpc GetLatestWorkshopRelease(GetLatestWorkshopReleaseRequest) returns (...) {
  option deprecated = true;
}
```

Emits a generated-code warning without changing the wire. Leave for at least one release cycle, then reserve and remove.

## Deleting a field safely

1. Mark `[deprecated = true]`. Ship.
2. Wait for clients to stop reading/writing.
3. Delete, reserve number + name:
   ```protobuf
   message Foo {
     reserved 7;
     reserved "old_field";
   }
   ```
4. Run `buf breaking`.
5. Ship.

Renames and type changes follow the same shape: add new alongside, migrate readers, then writers, then delete.
