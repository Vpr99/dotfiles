# Services API and Core NATS Patterns

## Contents

- Services API (first-class service support)
- Sequence number pattern for loss detection
- Acknowledgement pattern for Core NATS reliability

---

## Services API

The Services API is a protocol layer built on top of Core NATS (no JetStream required, no server config changes). It provides first-class discoverability and observability for services. Not all client libraries support it yet — check the specific library's docs and repository.

### Concepts

**Service** — the top-level abstraction grouping related functionality. Services must have a name and a version conforming to semver rules. Services are discoverable within a NATS system.

**Endpoint** — a single operation within a service. All services must have at least one endpoint. This is the subject on which client requests arrive; the application is responsible for subscribing to it and replying.

**Group** — an optional logical collection of endpoints that can share a common subject prefix.

### Discovery operations

The client library handles responding to these automatically. No application code required to respond to them.

| Operation | Subject pattern | Purpose |
|---|---|---|
| PING | `$SRV.PING.>` | Gather responses from all running services. Enables service listing by tooling. |
| STATS | `$SRV.STATS.>` | Query statistics: total requests, total errors, total processing time. |
| INFO | `$SRV.INFO.>` | Obtain service definition and metadata: groups, endpoints, etc. |

You can ping a specific service by name: `$SRV.PING.<service-name>`.

### Application responsibility

The discovery responses are handled by the library. The application is still responsible for:
- Subscribing to the endpoint subjects
- Processing requests
- Sending reply messages

---

## Sequence number pattern

A Core NATS pattern for detecting message loss without JetStream.

The sender embeds a monotonically increasing sequence number with each message, either:
- In the payload
- As a token in the subject: `updates.1`, `updates.2`, `updates.3`, ...

The subscriber listens on `updates.*` and parses the subject to extract the sequence number. Any gap in the sequence indicates a lost message.

In the absence of new data, heartbeat messages (sent at a regular interval) can be used alongside sequence numbers: if no message arrives within an expected window, the subscriber knows something is wrong.

Each sender maintains its own independent sequence. If possible, receivers should be able to request retransmission of a specific sequence ID.

Embedding the sequence number in the subject is useful when:
- The payload format cannot be modified
- The receiver is unknown or may be a language that makes payload parsing complex
- The receiver needs to filter by sequence range using subject wildcards

---

## Acknowledgement pattern for Core NATS reliability

In at-most-once Core NATS, a publisher cannot know if a message was received. One way to gain delivery confidence without JetStream is to turn the publish into a request-reply and treat the reply as an acknowledgement.

The ACK can be an empty message — it takes almost no bandwidth. The pattern:

1. Publisher sends a request to a subject.
2. Subscriber receives it, processes it, and sends a reply (even if empty).
3. Publisher waits for the reply with a timeout. If it times out, it retries.

This pattern converts fire-and-forget into fire-and-know for individual messages. For delivery to multiple receivers (scatter-gather), the publisher sends a request and waits for N replies within a time window.

**When to prefer JetStream instead:** If the consumer may be offline at publish time, if you need replay, or if at-least-once is not enough and you need exactly-once, use JetStream publish + durable consumers rather than this pattern.
