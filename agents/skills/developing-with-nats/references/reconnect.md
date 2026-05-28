# Reconnect Behavior

## Contents

- Automatic reconnect overview
- Reconnect options and defaults
- Disabling reconnect
- Reconnect wait (thundering herd prevention)
- Max reconnect attempts
- Reconnect randomization
- Reconnect buffer
- Reconnect event listeners

---

## Automatic reconnect overview

All officially maintained NATS client libraries reconnect automatically by default when the server connection drops. On reconnect the library automatically re-establishes all subscriptions — no application code is required.

The client builds its server list from:
1. URLs provided in the `connect` call.
2. URLs the server sends after connecting (cluster topology discovery).

---

## Disabling reconnect

- Go: `nats.NoReconnect()`
- Java: `.noReconnect()`
- JS: `{ reconnect: false }`
- Python: `allow_reconnect=False`
- C#: `.NET client does not support fully disabling reconnect; set `MaxReconnectRetry = 1` as the closest equivalent`
- C: `natsOptions_SetAllowReconnect(opts, false)`

---

## Reconnect wait (pause between attempts)

The library ensures at least this much time passes between two consecutive reconnect attempts to the **same** server. Prevents wasted attempts and alleviates thundering herd when no other servers are available.

- Go: `nats.ReconnectWait(10*time.Second)` (default: 2 s)
- Java: `.reconnectWait(Duration.ofSeconds(10))`
- JS: `{ reconnectTimeWait: 10000 }` (ms)
- Python: `reconnect_time_wait=10` (seconds)
- C#: `ReconnectWaitMin`, `ReconnectWaitMax` (min/max range)
- C: `natsOptions_SetReconnectWait(opts, 10000)` (ms)

---

## Max reconnect attempts

Counted per server. After the limit is reached for a server it is removed from the connect list. After a successful reconnect the counter resets. If no servers remain, the connection closes with an error.

- Go: `nats.MaxReconnects(10)` (default: 60; -1 = never give up)
- Java: `.maxReconnects(10)`
- JS: `{ maxReconnectAttempts: 10 }`
- Python: `max_reconnect_attempts=10`
- C#: `MaxReconnectRetry = 10`
- C: `natsOptions_SetMaxReconnect(opts, 10)`

---

## Reconnect randomization (thundering herd prevention)

By default, the client shuffles the server list before attempting connections. This spreads load across servers when many clients reconnect simultaneously.

To disable randomization (always try servers in the order provided):
- Go: `nats.DontRandomize()`
- Java: `.noRandomize()`
- JS: `{ noRandomize: true }`
- Python: `dont_randomize=True`
- C#: `NoRandomize = true`
- C: `natsOptions_SetNoRandomize(opts, true)`

---

## Reconnect buffer

During a short reconnect window, the client buffers outgoing publish calls in memory. Messages are flushed once reconnected.

When the buffer is exhausted, publish calls return an error.

Even within the buffer, delivery is not guaranteed if the connection never re-establishes. Use JetStream publish for delivery guarantees.

- Go: `nats.ReconnectBufSize(5*1024*1024)` — 5 MB (default: 8 MB)
- Java: `.reconnectBufferSize(5*1024*1024)`
- JS: not configurable
- Python: not implemented
- C#: not configurable
- Ruby: not implemented
- C: `natsOptions_SetReconnectBufSize(opts, 5*1024*1024)`

---

## Reconnect event listeners

Register callbacks to be notified of disconnect and reconnect events. See `connecting.md` for the full per-language event listener API.

Go example:
```go
nats.DisconnectErrHandler(func(nc *nats.Conn, err error) { ... })
nats.ReconnectHandler(func(nc *nats.Conn) { ... })
```

JavaScript — listen for `Events.Reconnect` and `DebugEvents.Reconnecting` in the `nc.status()` iterator.

Python:
```python
await nc.connect(
    reconnect_time_wait=10,
    reconnected_cb=reconnected_cb,
    disconnected_cb=disconnected_cb,
)
```

## Go-specific reconnect option reference

| Option | Default | Description |
|---|---|---|
| `AllowReconnect` | `true` | Enable/disable reconnect |
| `MaxReconnect` | `60` | Max attempts per server (-1 = unlimited) |
| `ReconnectWait` | `2s` | Wait between attempts to same server |
| `ReconnectJitter` | `100ms` | Max random jitter added to wait (no TLS) |
| `ReconnectJitterTLS` | `1s` | Max random jitter added to wait (TLS) |
| `ReconnectBufSize` | `8 MB` | Outgoing publish buffer during reconnect |
| `RetryOnFailedConnect` | `false` | Enter reconnect loop on initial connect failure |
| `Timeout` | `2s` | Dial timeout per server |
| `PingInterval` | `2min` | Client ping interval |
| `MaxPingsOut` | `2` | Max unanswered pings before ErrStaleConnection |
