# Stream Configuration

## Contents

- When to use JetStream vs Core NATS
- Stream config fields
- StorageType
- RetentionPolicy — LimitsPolicy, WorkQueuePolicy, InterestPolicy
- DiscardPolicy
- Replication factor guidance
- Disk sync and durability
- Placement
- Mirror vs Source
- AllowRollup
- RePublish
- SubjectTransform
- Message deduplication
- JetStream consistency model
- Exactly-once semantics

---

## When to use JetStream vs Core NATS

**Use JetStream when:**
- Publishers and consumers are temporally decoupled (consumers may be offline when messages are published)
- A historical replay of messages is required
- The last message on a stream is needed for initialization and the producer may be offline
- Consumers need to process at their own pace with decoupled flow control
- Exactly-once quality of service (deduplication + double-ack) is required

**Use Core NATS when:**
- Tight request-reply with application-level timeout and retry handling (relying on a messaging system to resend in request-reply is an anti-pattern)
- Only the last message matters and new messages arrive frequently enough that a lost message is tolerable (e.g. stock ticker, frequent telemetry)
- Message TTL is low — the data degrades or expires quickly
- All expected consumers are live at publish time

---

## Stream config fields

Stream names cannot contain whitespace, `.`, `*`, `>`, path separators (`/` or `\`), or non-printable characters.

| Field | Description | Editable |
|---|---|---|
| `Name` | Unique stream name within the JetStream account | No |
| `Subjects` | List of subjects the stream monitors. Wildcards supported. Cannot be set on mirror streams. Default subject = stream name if unset. | Yes |
| `Storage` | `File` (default) or `Memory` | No |
| `Replicas` | Number of replicas (1–5). See replication guidance below | Yes |
| `MaxAge` | Maximum age of any message (nanoseconds) | Yes |
| `MaxBytes` | Maximum total size of the stream in bytes | Yes |
| `MaxMsgs` | Maximum total number of messages | Yes |
| `MaxMsgSize` | Maximum size of a single message (payload + headers) | Yes |
| `MaxMsgsPerSubject` | Maximum messages retained per subject | Yes |
| `MaxConsumers` | Maximum consumers that can be defined at once (-1 = unlimited) | No |
| `NoAck` | Disable acknowledgements for JetStream publish calls. Required when archiving messages that have a reply subject set (e.g. requests). | Yes |
| `Retention` | Retention policy — see below | No |
| `Discard` | Discard policy when limits are hit — see below | Yes |
| `DuplicateWindow` | Window for tracking duplicate messages via `Nats-Msg-Id` header (nanoseconds) | Yes |
| `Placement` | Placement constraints (cluster name, tags) | Yes |
| `Mirror` | If set, stream mirrors exactly one origin stream | Yes (since 2.12) |
| `Sources` | If set, stream aggregates messages from one or more origin streams | Yes |
| `Sealed` | Prevents message deletion via limits or API. Once sealed, cannot be unsealed via config update. | Yes (once) |
| `DenyDelete` | Prevents deletion of individual messages via API | No |
| `DenyPurge` | Prevents purge operations via API | No |
| `AllowRollup` | Enables `Nats-Rollup` header to purge prior messages | Yes |
| `RePublish` | Re-publishes stored messages to a destination subject | Yes |
| `SubjectTransform` | Transforms subjects of incoming messages before storing | Yes |
| `Compression` | `s2` for Snappy compression (file storage only) | Yes |
| `ConsumerLimits` | Default limits applied to consumers of this stream | Yes |
| `AllowMsgTTL` | Enables per-message TTL via `Nats-TTL` header | No (enable only) |
| `FirstSeq` | Initial sequence number for new streams | No |
| `Metadata` | Application-defined key-value metadata | Yes |
| `AllowDirect` | Allows replicas to serve direct-get requests (not only leader) | Yes |

---

## StorageType

- `File` (default) — persists to disk. Subject to `sync_interval` durability semantics (see below).
- `Memory` — stores in RAM only. Lost on server restart.

---

## RetentionPolicy

### LimitsPolicy (default)
Messages are retained until a limit is exceeded (`MaxMsgs`, `MaxBytes`, `MaxAge`, `MaxMsgsPerSubject`). Whichever limit is hit first triggers eviction per the `DiscardPolicy`.

### WorkQueuePolicy
Each message is retained until it is consumed and explicitly acknowledged by a consumer. **Critical constraint: consumer subject filters must not overlap — only one consumer per subject is allowed.** Once acked, the message is deleted. Limits still apply as upper bounds and will evict unacked messages if hit.

Messages that reach `MaxDeliver` attempts without being acked remain in the stream and must be manually deleted.

### InterestPolicy
Messages are retained as long as at least one consumer has not yet acked them for the message's subject. Once all currently defined consumers have acked a message, it is deleted. If a consumer is deleted and it was the last one with interest in a set of subjects, messages are not immediately deleted — deletion is deferred until they reach the front of the stream.

Limits still apply as upper bounds.

**Warning:** If no consumers are defined when messages are published, messages are deleted immediately (no interest).

---

## DiscardPolicy

Applies only when at least one limit is set:

- `DiscardOld` (default) — deletes the oldest messages to make room for new ones.
- `DiscardNew` — rejects new messages with an error when a limit is exceeded. Extension: `DiscardNewPerSubject` applies this per subject (requires `MaxMsgsPerSubject`).

---

## Replication factor guidance

From the docs:

- **R=1** — cannot survive server outage. Highest performance.
- **R=2** — no significant benefit over R=1. Use R=3 instead.
- **R=3** — tolerates loss of one server. Recommended balance of risk and performance.
- **R=4** — no significant benefit over R=3 except marginally in a 5-node cluster.
- **R=5** — tolerates simultaneous loss of two servers. Maximum durability at the cost of performance.

---

## Disk sync and durability

JetStream flushes file writes to the OS synchronously but does **not** immediately `fsync` to disk by default. The server uses a configurable `sync_interval` (default: 2 minutes) to control how often data is fsynced.

**Consequence:** A published message that received an acknowledgment may not yet be safely on disk. An OS failure (ungraceful OS exit, power outage) — not just a process crash — within the sync window can lose recently-acked messages even in a replicated setup.

- In a non-replicated setup, any OS failure during the sync window risks data loss.
- In a replicated setup, data loss requires multiple servers to fail simultaneously before their data is fsynced — rare but possible.

Setting `sync_interval: always` fsyncs after every message before acknowledging. This provides the strongest durability guarantee but reduces throughput. Can be scoped to specific clusters using placement tags.

---

## Placement

Controls which cluster and servers host the stream's data. Without explicit placement, the stream is created in the cluster the client is connected to.

Options:
- `cluster` — explicit cluster name (requires cluster `name` to be set in server config)
- `tags` — place based on server tags; `unique_tag` in server config ensures replicas land on servers with different values for that tag

---

## Mirror vs Source

| | Mirror | Source |
|---|---|---|
| Origins | Exactly one | One or more |
| Client publish | Not allowed | Allowed (aggregated into stream) |
| Sequence numbers | **Retained** from origin | **Not retained** |
| Deletes | Not replicated from origin | Not replicated from origin |
| Use case | Read-only replica / disaster recovery | Fan-in aggregation |

Sources and Mirrors replicate asynchronously. Recovery interval after a disconnect is 10–20 s. Neither creates a visible consumer on the origin stream.

**For new configurations, prefer `Sources`** over `Mirror`. Mirror is retained for read-only replica semantics where sequence number preservation matters.

---

## AllowRollup

When enabled, a published message with a `Nats-Rollup` header will purge all prior messages. Scope:
- `Nats-Rollup: all` — purge all prior messages in the stream
- `Nats-Rollup: sub` — purge all prior messages for the message's subject

Common use case: state snapshots where a single message represents all accumulated state.

---

## RePublish

When configured, messages stored in the stream are immediately re-published to a destination subject after successful write.

Fields:
- `Source` — optional subject filter (subset of stream subjects, default `>`)
- `Destination` — target subject (must be a valid subject mapping from Source)
- `HeadersOnly` — if true, omits payload; adds `Nats-Msg-Size` header instead

The `reply-subject` is removed from republished messages even if `NoAck` is set on the stream.

---

## SubjectTransform

Applies a subject transform to matching incoming messages before storing. Fields: `Source` (filter) and `Destination` (transform pattern). Follows subject mapping rules.

---

## Message deduplication

JetStream detects duplicate publications using the `Nats-Msg-Id` header. Set this header to a unique string per publication. Within the `DuplicateWindow` (default 2 minutes), the server rejects a second message with the same `Nats-Msg-Id`.

**Only the message ID is compared, not the payload.**

```
# CLI example
nats req -H Nats-Msg-Id:abc123 ORDERS.new "order payload"
```

Client libraries that support JetStream publish accept a message ID option. The publish ack includes a `duplicate: true` flag when the ID was already seen.

This is the publish side of exactly-once. The consumer side uses double-acking (`AckSync`).
---

## JetStream consistency model

JetStream uses a NATS-optimized RAFT distributed quorum algorithm for persistence across clustered servers. This provides **immediate consistency** (not eventual consistency) even in the face of failures.

**Writes (JetStream publish):** Linearizable. A published message that receives an acknowledgment from the server has been received, replicated to a quorum, and persisted. Once you have the ack, you can safely discard local state for that publication.

**Reads (consuming from streams):** Serializable. Messages are added to a stream in one global order. However:

- **Direct-get requests** (fetching a message by sequence number) may be served by followers or mirrors — **no read-your-writes guarantee**. For consistent reads, send direct-get requests to the stream leader.
- Consuming messages through consumers always delivers them in stream order.

**Monotonic reads and writes are guaranteed.** Read-your-writes is not.

---

## Exactly-once semantics

JetStream exactly-once requires two components working together:

**1. Publish side — deduplication:** Set a unique `Nats-Msg-Id` header on each published message. Within the stream's `DuplicateWindow`, the server discards any re-publication with the same ID. See `references/jetstream-headers.md` for the header spec.

**2. Consumer side — double-ack:** Call `AckSync()` instead of `Ack()`. `AckSync()` sets a reply subject on the ack message and waits for the server to confirm it received the acknowledgement. If the server confirms, the message will never be redelivered — even if the acknowledgement was lost in transit between client and server.

Using only one of the two is not enough:
- Dedup without double-ack: message stored exactly once, but may be processed more than once if the ack is lost
- Double-ack without dedup: consumer side is safe, but a retry on the publish side can store a duplicate message
