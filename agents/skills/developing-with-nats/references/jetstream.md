# JetStream — Streams, Consumers, KV Store

## Contents

- JetStream context
- Streams
- Publishing to streams
- Consumers: durable vs ephemeral, push vs pull, ordered
- Acknowledgements
- Key-Value Store
- Object Store

---

## JetStream context

Obtain from the connection. Lightweight — safe to share between threads, or create one per thread.

```
// Go
js, _ := nc.JetStream()

// Java
JetStream js = nc.jetStream();
JetStreamManagement jsm = nc.jetStreamManagement();

// JavaScript
const js = nc.jetstream();
const jsm = await nc.jetstreamManager();

// Python
js = nc.jetstream()

// C#
INatsJSContext js = client.CreateJetStreamContext();

// C
natsConnection_JetStream(&js, conn, &jsOpts)
```

In Go and C, the same context is used for both operations and management. In Java and JavaScript, there are separate management contexts.

---

## Streams

A stream stores messages published to the subjects it monitors. A stream must be defined before messages can be consumed from it (though Core NATS publishers are unaware of and unaffected by streams).

Common stream management operations:
- **Add** — idempotent; fails if a stream with the same name exists with a different config
- **Update** — change stream config
- **Delete** — remove stream and all its messages
- **Purge** — delete all messages, keep the stream definition
- **Get / delete a message by sequence number**

Stream configuration selects: subjects monitored, storage type (file or memory), number of replicas, and the retention policy (limits, interest, or work queue).

Go example:
```go
js.AddStream(&nats.StreamConfig{
    Name:     "example-stream",
    Subjects: []string{"example-subject"},
    MaxBytes: 1024,
})
js.UpdateStream(&nats.StreamConfig{Name: "example-stream", MaxBytes: 2048})
js.DeleteStream("example-stream")
```

C# example:
```csharp
await js.CreateStreamAsync(new StreamConfig(name: "example-stream", subjects: ["example-subject"]));
await js.UpdateStreamAsync(streamConfig with { MaxBytes = 2048 });
await js.DeleteStreamAsync("example-stream");
```

---

## Publishing to streams

Any message published (even via Core NATS `Publish`) on a subject monitored by a stream is stored. However, use the JetStream publish call to receive an acknowledgement from the server that the message was received and stored.

JetStream publish returns a `PubAck` (or equivalent) containing the stream name, sequence number, and a `duplicate` flag.

**Synchronous publish:**
- Go: `js.Publish(subject, data)`
- Java: `js.publish(subject, data)` → `PublishAck`
- Python: `await js.publish(subject, data)` → ack

**Asynchronous publish:**
- Go: `js.PublishAsync(subject, data)` — collect results via `js.PublishAsyncComplete()`
- Java: `js.publishAsync(subject, data)` → `CompletableFuture<PublishAck>`
- C#: `js.PublishConcurrentAsync(subject, data)` → `NatsJSPublishConcurrentFuture`

---

## Consumers

Consumers are how application instances get messages stored in a stream. A stream can have many consumers.

### Durable vs ephemeral

**Durable** — named, persist delivery state server-side. Survives client disconnects. Used for multiple application instances (load balancing) or applications that stop and restart. Typically created administratively with the NATS CLI; the application references by name.

**Ephemeral** — no durable name. Created on demand by the client instance. Automatically deleted by the server when no client is connected to it. Used when an application instance needs its own independent replay of the stream.

### Pull vs push consumers

**Pull consumers** (recommended for new projects) — the application explicitly fetches messages in batches. Client controls dispatch, flow, and load balancing.

**Push consumers** — the server delivers messages to a configured delivery subject. Load balancing via NATS queue groups on the delivery subject.

Pull consumers create less CPU load on the server and scale better at high message rates.

### Pull consumer example

Go:
```go
sub, _ := js.PullSubscribe("foo", "wq", nats.PullMaxWaiting(128))
msgs, _ := sub.Fetch(10, nats.Context(ctx))
for _, msg := range msgs {
    msg.Ack()
}
```

Python:
```python
psub = await js.pull_subscribe("foo", "psub")
msgs = await psub.fetch(1)
for msg in msgs:
    await msg.ack()
```

C#:
```csharp
var consumer = await js.CreateConsumerAsync("FOO", new ConsumerConfig(name: "foo") { MaxWaiting = 128 });
await foreach (var msg in consumer.FetchAsync<string>(new NatsJSFetchOpts { MaxMsgs = 10 }))
{
    await msg.AckAsync();
}
```

### Push consumer example

Go (async):
```go
js.Subscribe("foo", func(msg *nats.Msg) {
    msg.Ack()
}, nats.ManualAck())
```

Go (queue group, load balanced):
```go
js.QueueSubscribe("foo", "group", func(msg *nats.Msg) {
    msg.Ack()
}, nats.ManualAck())
```

C# note: `.NET client abstracts push/pull — all consumers are accessed through the same API. The library handles mechanics internally.`

### Ordered consumers

An ordered consumer is a convenient ephemeral push consumer that guarantees in-order, gap-free delivery. Always ephemeral. Recovers from server node failure and reconnect. Does not persist delivery state.

Go:
```go
js.Subscribe("foo", func(msg *nats.Msg) { ... }, nats.OrderedConsumer())
```

Python:
```python
osub = await js.subscribe("foo", ordered_consumer=True)
```

C#:
```csharp
var consumer = await js.CreateOrderedConsumerAsync("FOO");
```

---

## Acknowledgements

Required for consumers with ack policy `Explicit` or `All`. Pull consumers always require explicit acks.

| Ack call | Meaning |
|---|---|
| `Ack()` | Positively acknowledge: message received and processed successfully |
| `AckSync()` | Ack and wait for server confirmation of the ack |
| `Nack()` | Negative ack: re-deliver the message. Use when processing is temporarily impossible |
| `Term()` | Terminate: message is permanently unprocessable, do not re-deliver |
| `inProgress()` | Processing still ongoing, reset the AckWait timer |

Re-delivery timing is controlled by `AckWait` (single duration) or `BackOff` (sequence of durations; overrides `AckWait`). When using `Nack()`, pass a delay option to control when re-delivery happens; otherwise re-delivery is immediate.

**Dead letter queue equivalent** — set `MaxDeliver` on the consumer. When the limit is reached, an advisory is published on:
```
$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.<STREAM>.<CONSUMER>
```
The advisory payload includes `stream_seq` — the sequence number of the undeliverable message in the stream. The message remains in the stream until manually deleted or acknowledged.

When `Term()` is called, an advisory is published on:
```
$JS.EVENT.ADVISORY.CONSUMER.MSG_TERMINATED.<STREAM>.<CONSUMER>
```

---

## Key-Value Store

Built on top of JetStream. Accessed via the JetStream context.

Keys are dot-separated strings. Values are byte arrays. Buckets are independent KV namespaces. **Note: KV key character rules differ from NATS subject rules — see `references/kv-and-object-store.md` for the correct character set.**

Operations: `Put` (set), `Get`, `Delete`, `Update` (compare-and-set), `Watch` (receive changes in real-time), `History` (past values for a key).

Buckets are typically created administratively. Management API:
- Go: `js.CreateKeyValue(cfg)`, `js.KeyValue(bucket)`, `js.DeleteKeyValue(bucket)`
- Java: `jsm.keyValue().create(config)`, `.getBucketInfo(name)`, `.delete(name)`

**Gotcha**: KV keys allow `/` but NATS subjects do not. For full key character rules and complete KV API, see `references/kv-and-object-store.md`.

---

## Object Store

Technology Preview as of the docs in this repo.

Similar to KV Store but for arbitrarily large values (not limited to the NATS message max payload). Built on JetStream. Keys are strings; values are byte streams stored as chunked messages in a stream.
