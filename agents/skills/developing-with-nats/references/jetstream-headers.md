# JetStream Headers Reference

## Contents

- Reserved namespace
- Publish headers (client-set, recognized by server)
- RePublish and direct-get headers (server-set)
- Source headers (server-set on sourced messages)
- Tracing headers
- Internal headers (do not set)

---

## Reserved namespace

`Nats-` is a reserved header name prefix. Do not use it for application-defined headers. Use a different prefix for your own headers.

---

## Publish headers

Set by the client on published messages. Recognized and acted on by the JetStream server.

| Header | Description | Example |
|---|---|---|
| `Nats-Msg-Id` | Client-defined unique ID for deduplication within the stream's `DuplicateWindow`. The server checks only the ID, not the payload. | `9f01ccf0-8c34-4789-8688-231a2538a98b` |
| `Nats-Expected-Stream` | Assert the message is received by this stream name. | `my-stream` |
| `Nats-Expected-Last-Msg-Id` | Optimistic concurrency at stream level. The value is the expected current last `Nats-Msg-Id`. Server rejects the publish if the current last ID does not match. | `9f01ccf0-8c34-4789-8688-231a2538a98b` |
| `Nats-Expected-Last-Sequence` | Optimistic concurrency at stream level. The value is the expected current last stream sequence number. | `328` |
| `Nats-Expected-Last-Subject-Sequence` | Optimistic concurrency at subject level. The value is the expected last sequence for the message's subject specifically. | `38` |
| `Nats-Expected-Last-Subject-Sequence-Subject` | Used with `Nats-Expected-Last-Subject-Sequence`. Server enforces last sequence against this subject (may include wildcards) rather than the published subject. | `events.orders.1.>` |
| `Nats-Rollup` | Purges prior messages. Requires `AllowRollup` on the stream. Values: `all` (entire stream) or `sub` (subject of this message). Wildcards in subject not allowed. | `all` or `sub` |
| `Nats-TTL` | Per-message TTL. Requires `AllowMsgTTL` flag on the stream. Go duration string format. | `1h`, `10s` |

### Using Nats-Msg-Id for exactly-once publishing

```
# Publish with dedup ID
nats req -H Nats-Msg-Id:abc123 ORDERS.new "payload"

# Publishing again with the same ID within DuplicateWindow — server discards it
nats req -H Nats-Msg-Id:abc123 ORDERS.new "payload again"
```

The publish ack returned by the server includes a `duplicate: true` flag when the message was deduplicated. `DuplicateWindow` default is 2 minutes; set on the stream config. Only the ID is compared — payload is ignored.

### Optimistic concurrency control (OCC)

Use `Nats-Expected-Last-Subject-Sequence` for compare-and-swap on a per-subject basis — useful for implementing atomic updates on a key without using the KV Store abstraction.

---

## RePublish and direct-get headers

Added by the server to republished messages (requires `RePublish` configured on stream) and to messages returned by direct-get operations. **Do not set these on client-published messages.**

| Header | Description | Example |
|---|---|---|
| `Nats-Stream` | Name of the stream the message was republished from | `my-stream` |
| `Nats-Subject` | The original subject of the message | `events.mouse_clicked` |
| `Nats-Sequence` | The original sequence number in the stream | `193` |
| `Nats-Last-Sequence` | The last sequence for messages with the same subject (0 if first) | `190` |
| `Nats-Time-Stamp` | The original timestamp when the message was stored | `2023-08-23T19:53:05.762416Z` |
| `Nats-Num-Pending` | Number of messages still pending in a multi/batched get response | `5` |
| `Nats-UpTo-Sequence` | On the last message of a multi/batched get response: the `up-to-seq` value of the original request, enabling clients to continue incomplete batch requests | (sequence number) |

**Note:** The `reply-subject` is removed from republished messages even when `NoAck` is set on the stream.

---

## Source headers

Added implicitly by the server to messages replicated from other streams via `Sources` or `Mirror` configuration.

| Header | Description |
|---|---|
| `Nats-Stream-Source` | Space-delimited: origin stream name (with domain hash if cross-domain), original sequence number, list of subject filters, list of destination transforms, original subject. Format may gain additional fields in future server versions — parse conservatively. |

---

## Tracing headers

Introduced in server 2.11. When tracing is activated, each subsystem that touches a message produces trace events, aggregated per server and published to a destination subject.

| Header | Description |
|---|---|
| `traceparent` | Triggers tracing per W3C Trace Context standard. Requires `msg-trace` section configured at account level. |
| `Nats-Trace-Dest` | Subject that will receive trace messages | 
| `Nats-Trace-Only` | If `true`, the message is not delivered or stored — only traces are produced |
| `Accept-Encoding` | Enables compression of trace message payloads (`gzip`, `snappy`) |
| `Nats-Trace-Hop` | **Internal — do not set.** Server-managed hop count. |
| `Nats-Trace-Origin-Account` | **Internal — do not set.** Set by server at account boundaries. |

---

## Internal headers

Used internally by the server and API clients. **Do not set these.** This list is not exhaustive.

| Header | Description |
|---|---|
| `Nats-Required-Api-Level` | Servers ≥ 2.11 return an error if this exceeds the supported API level |
| `Nats-Request-Info` | Origin information (account, user) added when messages cross account boundaries |
| `Nats-Marker-Reason` | Reason for a KV delete marker: `MaxAge`, `Remove`, or `Purge` |
| `Nats-Incr` | KV atomic counter increment (any integer with sign, e.g. `+1`, `-1`, `+0`) |
