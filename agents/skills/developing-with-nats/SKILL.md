---
name: developing-with-nats
description: Guides development of NATS client applications — connecting, publishing, subscribing, request-reply, JetStream streams and consumers, Key-Value Store, Object Store, Services API, authentication, reconnect behavior, and slow consumer handling. Use when writing, reviewing, or debugging NATS client code in any language, or when the user asks how NATS works from a developer perspective.
---

# Developing with NATS

NATS is a subject-based messaging system. A publisher sends to a subject; any active subscriber on a matching subject receives it. The NATS server treats all message payloads as opaque byte arrays. All encoding and decoding is the responsibility of the client application.

```
Developer checklist:
- [ ] Connect (with security credentials if required)
- [ ] Register connection event listeners
- [ ] Publish / subscribe / request
- [ ] Unsubscribe or drain before closing
- [ ] Close or drain the connection on exit
```

## Gotchas

- **Subscribe call may return before the server registers the subscription.** Call `Flush()` on the connection immediately after `Subscribe()` if you need to synchronize with the subscription being ready server-side.
- **A client receives a message for every matching subscription on that connection.** If a connection has both a `foo` and a `>` subscription, the same message is delivered twice to the same connection.
- **Async subscriptions dispatch messages serially per subscription.** If your handler is slow, messages queue up. For concurrent processing the application must move messages into its own worker pool — the library will not do it.
- **`close()` is immediate; `drain()` is graceful.** `close()` drops buffered messages. `drain()` processes all inflight and pending messages first, then closes. For queue subscribers, always prefer `drain()` to avoid message loss.
- **Core NATS publish buffer is fire-and-forget.** During a reconnect, outgoing messages are buffered up to `ReconnectBufSize` (default 8 MB in Go). Once the buffer is exhausted, publish calls return an error. Even within the buffer window, delivery is not guaranteed if the connection never re-establishes. Use JetStream publish for guaranteed delivery.
- **The `*` wildcard matches exactly one token; `>` matches one or more and must appear at the end.** `time.*.east` matches `time.us.east` but NOT `time.us.east.atlanta`. `time.us.>` matches both.
- **Pedantic mode and verbose mode are for development/debugging only.** Every client turns both off by default. Do not use in production.
- **JavaScript and Python async clients do not have synchronous subscriptions.** Only Go, Java, and C provide both sync and async subscription APIs.
- **JavaScript and .NET clients do not support username/password or token in the URL.** Pass credentials through connection options instead.
- **`addStream` is idempotent** — if the stream already exists and the config matches exactly, the call succeeds. If the config differs, it fails.
- **`BackOff` entirely overrides `AckWait`.** The first BackOff value becomes the effective AckWait. If you set BackOff, your AckWait setting is silently ignored.
- **`WorkQueuePolicy` only allows one consumer per subject** — consumer subject filters must not overlap. Violating this fails at consumer creation time.
- **`InterestPolicy` messages are not immediately deleted when a consumer is deleted.** Deletion is deferred until those messages reach the front of the stream.
- **`MaxAckPending` suspends delivery to the entire consumer when reached** (default: 1000, across all bound subscriptions). It is the primary flow control knob for both push and pull consumers.
- **KV keys allow `/` but NATS subjects do not.** Valid KV key chars: `a-z A-Z 0-9 _ - . = /`. Do not apply subject naming rules to KV keys.
- **No read-your-writes guarantee for JetStream direct-get requests.** Reads may be served by a follower or mirror. For consistent reads, direct requests to the stream leader.
- **JetStream disk sync is not immediate.** Default `sync_interval` is 2 minutes. An OS failure (not just a process crash) within that window can lose recently-acked messages even when an ack was returned to the publisher. See `references/stream-config.md` for production guidance.
- **`BackOff` does not apply to `nak`.** A `nak` triggers immediate re-delivery unless a delay is explicitly passed when calling nak.
- **`AckAll` acknowledges all previous messages implicitly.** Acking message 100 also acks 1–99. Use for batch processing to reduce ack overhead.
- **Connection event callbacks are invoked asynchronously.** The connection state may have already changed again by the time the callback runs.
- **`DisconnectedCB` (Go) is deprecated.** Use `DisconnectedErrCB` instead.
- **R=2 replication has no significant benefit.** Use R=3 instead.

## Subjects

Subjects are dot-separated strings, e.g. `time.us.east`. Allowed characters: any Unicode except null, space, `.`, `*`, `>`. Recommended: alphanumeric, `-`, `_`. Case-sensitive.

Wildcards (subscriber-only):
- `*` — matches exactly one token: `time.*.east` matches `time.us.east`, not `time.us.east.atlanta`.
- `>` — matches one or more tokens at the end: `time.us.>` matches `time.us.east` and `time.us.east.atlanta`.

Reserved prefix `$` is for system subjects (`$JS`, `$SRV`, `$SYS`, `$KV`, etc.) — avoid in application subjects.

## Connecting

Default server URL: `nats://localhost:4222`. TLS only: `tls://…`. WebSocket: `ws://…`.

For clusters, pass all seed URLs as a comma-separated string or array. The client connects to a random seed URL by default, then receives the full cluster topology from the server. See `references/connecting.md` for all connection options, security methods, and event listeners.

Naming connections is **highly recommended** — it appears in server monitoring data and debugging output.

## Messages

A NATS message has:
- A **subject** (required)
- A **payload** — byte array (the server never interprets it)
- An optional **reply-to** subject
- Optional **header** fields

Max payload defaults to 1 MB server-side. Query `nc.MaxPayload()` after connecting to read the configured limit.

## Publishing

```
nc.Publish(subject, []byte(data))
```

All publish calls are buffered. To guarantee the buffer has been flushed to the server, call `Flush()` (or `FlushTimeout()`). Internally flush uses PING/PONG — pings sent this way do not count toward the max-pings-outstanding limit.

## Subscribing

**Async subscription** — callback/handler invoked when a message arrives. Preferred for most use cases.

**Sync subscription** — application calls `NextMsg(timeout)` in a loop. Available in Go, Java, C only.

**Unsubscribe**: call `sub.Unsubscribe()` to tell the server to stop sending messages. For a clean shutdown use `sub.Drain()` instead.

**Auto-unsubscribe**: configure a message count limit at subscription time; the server stops delivery after that many messages.

**Queue subscription**: pass a queue group name. The server load-balances across all members of the group. Queue groups require no server configuration — defined entirely by the subscribing applications.

## Request-Reply

The `request()` call publishes a message with an auto-generated reply-to inbox, then waits for a single response up to a timeout.

Under the hood: `subscribe(inbox)` → `publish(subject, replyTo=inbox)` → `NextMsg(timeout)` → `unsubscribe`.

For multiple responses (scatter-gather), manually create an inbox, subscribe to it, publish with `replyTo`, and collect responses in a loop bounded by time or count.

Service responders should subscribe with a queue group so requests are load-balanced across instances.

When no subscriber is present for a request subject, the server immediately returns a 503 status to the requesting client (no-responders). Most clients surface this as a `NoResponders` error.

## Reconnect behavior

All officially maintained NATS clients reconnect automatically by default. On reconnect, the library re-establishes all subscriptions — no application code required.

Key defaults (Go client; other libraries vary):
- `MaxReconnect`: 60 attempts
- `ReconnectWait`: 2 seconds
- `ReconnectBufSize`: 8 MB
- Randomization: enabled (prevents thundering herd)

See `references/reconnect.md` for full option reference.

## Slow consumers

If a subscriber cannot keep up, the library buffers incoming messages up to a configurable limit (by count and/or bytes). When the buffer is full, messages are dropped and a slow-consumer error is raised. The server itself may close the connection if the client falls too far behind.

Patterns to avoid slow consumers:
- Use request-reply to throttle the sender.
- Use queue groups to distribute load across multiple subscribers.
- Use JetStream pull consumers to control fetch rate explicitly.

## JetStream

JetStream adds persistence, at-least-once delivery, and higher qualities of service on top of Core NATS.

**When to use JetStream vs Core NATS** — see `references/stream-config.md` for explicit decision criteria.

Obtain a JetStream context from the connection:
```
js = nc.JetStream()           // Go
js = nc.jetStream()           // Java, JavaScript, Python
js = client.CreateJetStreamContext()  // .NET
```

JetStream contexts are lightweight — safe to share or create one per thread.

### Streams

Streams store messages on subjects they monitor. Any message published on a stream's subject is stored, regardless of whether it was published via Core NATS or JetStream publish. Use JetStream publish when you need acknowledgement that the message was stored.

Common stream operations: add (idempotent), update, delete, purge (delete all messages), get/delete by sequence number.

See `references/stream-config.md` for full stream configuration including retention policies, discard policies, replication guidance, mirror/source, deduplication, and AllowRollup.

### Publishing to streams

JetStream publish returns a `PubAck` with stream name, sequence number, and `duplicate` flag.

**Synchronous:** `js.Publish(subject, data)` — waits for server ack.

**Asynchronous:** `js.PublishAsync(subject, data)` — returns immediately; collect acks separately.

Use `Nats-Msg-Id` header for exactly-once deduplication. See `references/jetstream-headers.md`.

### Consumers

Consumers are how application instances get messages stored in a stream. See `references/consumer-config.md` for full configuration.

**Pull consumers** (recommended for new projects) — client fetches in batches, full flow control. Scales better at high message rates.

**Push consumers** — server delivers to a configured subject. Use ordered push consumers for sequential per-instance replay. Use push with queue group for load-balanced delivery.

**Durable vs ephemeral** — durable consumers persist state, survive disconnects, usable by multiple instances. Ephemeral consumers auto-delete when no subscriptions are bound.

### Acknowledgements

| Call | Meaning |
|---|---|
| `Ack()` | Successfully processed — do not redeliver |
| `AckSync()` | Ack + wait for server confirmation (double-ack for exactly-once) |
| `Nack()` | Temporarily unable to process — redeliver (immediately unless delay passed) |
| `Term()` | Permanently unprocessable — never redeliver |
| `inProgress()` | Still processing — reset the AckWait timer |

Re-delivery timing controlled by `AckWait` or `BackOff` (BackOff overrides AckWait entirely).

**Dead letter queue pattern**: set `MaxDeliver` on the consumer. When a message exhausts its delivery attempts, an advisory is published on `$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.<STREAM>.<CONSUMER>`. The advisory payload contains `stream_seq`. The message remains in the stream until manually deleted.

### Key-Value Store

Built on JetStream. Keys are dot-separated strings; values are byte arrays. Supports: `Get`, `Put`, `Create` (compare-and-null-set), `Update` (compare-and-swap), `Delete`, `Purge`, `Keys`, `History`, `Watch`.

KV key character rules differ from subject rules — `/` is valid in KV keys. See `references/kv-and-object-store.md` for full API.

### Object Store

Stores arbitrarily large values by chunking into multiple messages. Use when values exceed the NATS max message size (default 1 MB). Operations: `Put`, `Get`, `GetInfo`, `Delete`, `List`, `Watch`, `Seal`, `AddLink`. See `references/kv-and-object-store.md`.

### Services API

First-class service discoverability built on Core NATS. No JetStream or server config required. Provides `PING`, `STATS`, `INFO` discovery on `$SRV.*` subjects. See `references/services-and-patterns.md`.

## References

- `references/connecting.md` — URL formats, all connection options, all 5 security methods, event listeners
- `references/reconnect.md` — reconnect options, defaults, disable, thundering herd, buffer
- `references/stream-config.md` — when to use JetStream, full stream config table, retention/discard policies, replication guidance, disk sync durability, placement, mirror vs source, deduplication, AllowRollup, RePublish, JetStream consistency model (linearizable writes, no read-your-writes for direct-get), exactly-once semantics (dedup + double-ack)
- `references/consumer-config.md` — full consumer config table, AckPolicy, DeliverPolicy, BackOff vs AckWait, MaxAckPending, FilterSubjects, pull-specific and push-specific fields, ordered consumers
- `references/jetstream-headers.md` — all Nats-* headers for publish (Nats-Msg-Id, Nats-Expected-*, Nats-Rollup, Nats-TTL), republish/direct-get response headers, source headers, tracing headers
- `references/kv-and-object-store.md` — KV key rules, full KV API (Get/Put/Create/Update/Delete/Purge/Keys/History/Watch), KV consistency model, Object Store API
- `references/services-and-patterns.md` — Services API (Service/Endpoint/Group, $SRV discovery), sequence number loss-detection pattern, Core NATS ack pattern
