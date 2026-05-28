# Consumer Configuration

## Contents

- Consumer types summary
- General config fields
- AckPolicy
- DeliverPolicy
- MaxAckPending (flow control)
- FilterSubject and FilterSubjects
- Backoff vs AckWait
- InactiveThreshold
- ReplayPolicy
- Pull-specific fields
- Push-specific fields

---

## Consumer types summary

| Dimension | Options |
|---|---|
| Dispatch | Push (server delivers to a subject) or Pull (client fetches on demand) |
| Persistence | Durable (named, persistent state) or Ephemeral (unnamed, auto-deleted) |
| Special | Ordered (ephemeral push, no acks, gap detection, single-threaded) |

**Recommendation from docs:** Use pull consumers for new projects, especially when scalability, flow control, or error handling matter. Push consumers (specifically ordered push) are best for applications that want their own sequential replay of a stream.

A consumer is durable if it has a `Durable` name set, or if `InactiveThreshold` is set. Ephemeral consumers are automatically deleted after a period of inactivity when no subscriptions are bound.

---

## General config fields

| Field | Description | Editable |
|---|---|---|
| `Durable` | Name for durable consumers. Cannot contain whitespace, `.`, `*`, `>`, path separators, or non-printable characters. | No |
| `FilterSubject` | Single subject filter overlapping stream subjects. Cannot be used with `FilterSubjects`. | Yes |
| `FilterSubjects` | Multiple subject filters. Cannot be used with `FilterSubject`. | Yes |
| `AckPolicy` | Acknowledgement requirement — see below | No |
| `AckWait` | How long to wait for an ack before re-delivering. Overridden entirely by `BackOff` if set. | Yes |
| `DeliverPolicy` | Starting position in the stream — see below | No |
| `OptStartSeq` | Used with `DeliverByStartSequence` | No |
| `OptStartTime` | Used with `DeliverByStartTime` | No |
| `MaxDeliver` | Maximum delivery attempts. Default -1 (redeliver until acked). Messages that hit the limit remain in stream and must be manually deleted. | Yes |
| `BackOff` | Sequence of re-delivery delays for ack timeouts (not for nak). Entirely overrides `AckWait`. | Yes |
| `ReplayPolicy` | `ReplayInstant` (default) or `ReplayOriginal` | No |
| `MaxAckPending` | Max unacked messages outstanding before delivery is suspended. Default 1000. -1 = no limit. | Yes |
| `InactiveThreshold` | Duration before server deletes an inactive consumer. Prior to server 2.9, only applied to ephemeral consumers. | Yes |
| `Replicas` | Number of replicas for consumer state. 0 = inherit from stream. | Yes |
| `MemoryStorage` | Force consumer state to memory (reduces ack I/O). Useful for ephemeral consumers. | No |
| `SampleFrequency` | Percentage of acks sampled for observability (0–100, as string e.g. `"30"` or `"30%"`) | Yes |
| `HeadersOnly` | Deliver message headers only; adds `Nats-Msg-Size` header | Yes |
| `Description` | Human-readable description | Yes |
| `Metadata` | Application-defined key-value metadata | Yes |

---

## AckPolicy

| Policy | Description |
|---|---|
| `AckExplicit` (default) | Each message must be individually acknowledged. Required for pull consumers. Recommended for most use cases. |
| `AckNone` | No acks required. Server treats delivery as acknowledgement. |
| `AckAll` | Acknowledging message N implicitly acknowledges all messages 1 through N-1. Reduces ack overhead for batch processing. Applied across all subscribers for pull consumers. |
| `AckFlowControl` (2.14+) | Flow-control based acks. Primarily used for stream sourcing/mirroring with a durable consumer. |

**Warning:** If an ack arrives after the `AckWait` window has expired and the message has been redelivered to another subscriber (in a queue scenario), the late ack from the first subscriber is treated as valid by the server. This can cause a message to appear acked even though the second delivery is still in progress.

---

## DeliverPolicy

| Policy | Description |
|---|---|
| `DeliverAll` (default) | Start from the earliest available message in the stream |
| `DeliverLast` | Start with the last message added to the stream (or last matching the filter if set) |
| `DeliverLastPerSubject` | Start with the latest message for each filtered subject currently in the stream |
| `DeliverNew` | Receive only messages created after this consumer was created |
| `DeliverByStartSequence` | Start at the first message with sequence ≥ `OptStartSeq` |
| `DeliverByStartTime` | Start with messages at or after `OptStartTime` |

---

## MaxAckPending (flow control)

`MaxAckPending` is the only flow control mechanism for push consumers. For pull consumers it works alongside the client's fetch batching.

- Applies across **all subscriptions bound to this consumer** — not per subscriber.
- When the number of outstanding unacked messages reaches this limit, the server **suspends delivery** until messages are acked.
- Default: 1000. Set -1 to disable (no flow control).
- For high-throughput consumers: set high. For consumers with high ack latency due to external services: set low and adjust `AckWait` to avoid re-deliveries.

---

## FilterSubject and FilterSubjects

A filter restricts which stream messages are delivered to this consumer. The filter subject must overlap with (be a subset of) the stream's subjects.

`FilterSubjects` (plural, available since server 2.10) allows multiple filters on a single consumer:

```
FilterSubjects: ["factory-events.A.*", "factory-events.B.*"]
```

**Cannot use both `FilterSubject` and `FilterSubjects` on the same consumer.**

**Permission note:** A single `FilterSubject` uses `$JS.API.CONSUMER.CREATE.{stream}.{consumer}.{filter}` for fine-grained authorization. Multiple `FilterSubjects` uses `$JS.API.CONSUMER.DURABLE.CREATE.{stream}.{consumer}` which does not include the filter token — use a different authorization strategy for granular permissions with multiple filters.

---

## Backoff vs AckWait

**`BackOff` entirely overrides `AckWait`.** The first value in the BackOff array becomes the effective `AckWait`.

Example: `MaxDeliver=5`, `BackOff=[5s, 30s, 300s, 3600s, 84600s]` re-delivers up to 5 times over approximately one day.

When `MaxDeliver` exceeds the length of the BackOff array, the last value in the array applies to all remaining deliveries.

**BackOff applies only to ack timeout re-deliveries — not to `nak`.** A `nak` triggers immediate re-delivery unless `nakWithDelay` is used. To delay re-delivery after a nak, pass a delay option when calling nak.

---

## InactiveThreshold

Controls how long the server waits before cleaning up an inactive consumer (no bound subscriptions). Defaults to a server-determined value.

Prior to server 2.9, `InactiveThreshold` only applied to ephemeral consumers. Since 2.9, it applies to durable consumers as well.

---

## ReplayPolicy

| Policy | Description |
|---|---|
| `ReplayInstant` (default) | Messages are delivered as fast as possible, subject to flow control |
| `ReplayOriginal` | Messages are delivered at the same rate they were originally published — useful for replaying production traffic in staging |

---

## Pull-specific fields

| Field | Description |
|---|---|
| `MaxWaiting` | Maximum number of simultaneous waiting pull requests | 
| `MaxRequestExpires` | Maximum duration a single pull request waits for messages |
| `MaxRequestBatch` | Maximum batch size per pull request |
| `MaxRequestMaxBytes` | Maximum total bytes per pull request. When set with `MaxRequestBatch`, whichever limit is hit first applies. |

---

## Push-specific fields

| Field | Description |
|---|---|
| `DeliverSubject` | The subject the server pushes messages to. Setting this makes the consumer push-based. |
| `DeliverGroup` | Queue group name for load balancing across multiple push subscribers (analogous to Core NATS queue groups) |
| `FlowControl` | Enables per-subscription sliding-window flow control between server and client (in addition to `MaxAckPending`) |
| `IdleHeartbeat` | Server sends status 100 messages during inactivity to signal the JetStream service is alive. Handled transparently by supported clients. |
| `RateLimit` | Throttles delivery rate in bits per second |

---

## Ordered consumers

Ordered consumers are a special preset of ephemeral push consumers:
- Always ephemeral
- No acknowledgements — if a gap is detected, the consumer is recreated automatically
- Automatic flow control and pull processing handled by the client library
- Single-threaded message dispatch (in-order guarantee)
- No load balancing

Use ordered consumers when an application instance needs its own complete, sequential, in-order replay of a stream (e.g. data inspection, analysis). Not suitable for shared consumption or work queues.
