# Connecting — Options, Security, and Events

## Contents

- NATS URL formats
- Connection options
- Security: userpass, token, TLS, NKey, credentials file
- Connection event listeners
- Discovered servers

---

## NATS URL formats

| Prefix | Connection type |
|---|---|
| `nats://` | Plain TCP, or TLS if the server is configured for it |
| `tls://` | TLS-only TCP |
| `ws://` | WebSocket |

Default port: 4222. If the port is omitted, 4222 is used.

For clusters, pass multiple URLs as a comma-separated string or an array:
```
"nats://server1:4222,nats://server2:4222"
```
The client randomizes the list and tries them in order. After connecting, the server sends the full cluster topology — clients can reconnect to any known member.

---

## Connection options

**Connection name** (highly recommended — appears in monitoring and debug output):
- Go: `nats.Name("my-app")`
- Java: `.connectionName("my-app")`
- JS: `{ name: "my-app" }`
- Python: `name="my-app"`
- C#: `new NatsClient(name: "my-app")`
- Ruby: `NATS.start(name: "my-app")`

**Connect timeout** (per server in the list):
- Go: `nats.Timeout(10*time.Second)`
- Java: `.connectionTimeout(Duration.ofSeconds(10))`
- Python: `connect_timeout=10`
- C#: `ConnectTimeout = TimeSpan.FromSeconds(10)`

**NoEcho** — prevents the connection from receiving its own published messages:
- Go: `nats.NoEcho()`
- Java: `.noEcho()`
- JS: `{ noEcho: true }`
- Python: `no_echo=True`
- C#: `Echo = false`
- Ruby: `no_echo: true`
- C: `natsOptions_SetNoEcho(opts, true)`

NoEcho is per-connection, not per-application. Turning it on/off has a major effect on message routing — subscribers on the same connection will silently stop receiving self-published messages.

**Ping/Pong** — used by the client to detect stale connections. Ping interval and max pings outstanding work together. To close an unresponsive connection after 100 s, use interval=20 s and max=5:
- Go: `nats.PingInterval(20*time.Second)`, `nats.MaxPingsOutstanding(5)`
- Java: `.pingInterval(Duration.ofSeconds(20))`, `.maxPingsOut(5)`
- JS: `{ pingInterval: 20000, maxPingOut: 5 }`
- Python: `ping_interval=20, max_outstanding_pings=5`
- C#: `PingInterval = TimeSpan.FromSeconds(20)`, `MaxPingOut = 5`
- C: `natsOptions_SetPingInterval(opts, 20000)`, `natsOptions_SetMaxPingsOut(opts, 5)`

In the presence of traffic the server does not initiate PING/PONG. On connections with significant traffic the default interval (minutes) is usually fine.

**Max payload** — read after connecting, cannot be set by the client:
- Go: `nc.MaxPayload()`
- Java: `nc.getMaxPayload()`
- JS: `nc.info.max_payload`
- Python: `nc.max_payload`
- C#: `client.Connection.ServerInfo.MaxPayload` (call `ConnectAsync()` first)
- C: `natsConnection_GetMaxPayload(conn)`

**Pedantic mode** — server validates subject names. Off by default. Development use only:
- Go: `opts.Pedantic = true`
- Java: `.pedantic()`
- JS: `{ pedantic: true }`
- Python: `pedantic=True`
- C: `natsOptions_SetPedantic(opts, true)`

**Verbose mode** — server replies `+OK` or `-ERR` to every message. Off by default. Debug use only:
- Go: `opts.Verbose = true`
- Java: `.verbose()`

---

## Security: username and password

Server start: `nats-server --user myname --pass password`

The server accepts plain text or hashed passwords. The client always uses plain text.

Credentials in options:
- Go: `nats.UserInfo("myname", "password")`
- Java: `.userInfo("myname", "password")`
- JS: `{ user: "byname", pass: "password" }` (JS does not support user:pass in the URL)
- Python: `servers=["nats://myname:password@server:4222"]`
- C#: `AuthOpts = new NatsAuthOpts { Username="myname", Password="password" }` (.NET does not support user:pass in the URL)
- Ruby: `servers: ["nats://myname:password@server:4222"]`

Credentials in URL (most clients, except JS and .NET):
```
nats://user:password@server:4222
```

---

## Security: token

Server start: `nats-server --auth mytoken`

Token in options:
- Go: `nats.Token("mytoken")`
- Java: `.token("mytoken")`
- JS: `{ token: "aToK3n" }` (JS does not support token in URL)
- Python: `token="mytoken"`
- C#: `AuthOpts = new NatsAuthOpts { Token="mytoken" }` (.NET does not support token in URL)
- Ruby: `NATS.start(token: "mytoken")`

Token in URL (most clients, except JS and .NET):
```
nats://mytoken@server:4222
```

---

## Security: TLS

Server start:
```
nats-server --tls --tlscert=server-cert.pem --tlskey=server-key.pem --tlscacert rootCA.pem --tlsverify
```

TLS with client certificate verification:
- Go: `nats.ClientCert("client-cert.pem","client-key.pem")`, `nats.RootCAs("rootCA.pem")`
- Java: build an `SSLContext` from JKS keystores and pass via `.sslContext(ctx)`
- JS (Node): `tls: { caFile, keyFile, certFile }`
- Python: build `ssl.SSLContext`, pass as `tls=ssl_ctx`
- C#: `TlsOpts = new NatsTlsOpts { CaFile, KeyFile, CertFile }`
- C: `natsOptions_LoadCertificatesChain(opts, cert, key)`, `natsOptions_LoadCATrustedCertificates(opts, ca)`

Using the `tls://` URL prefix forces TLS but relies on the language runtime's default certificate store — likely to fail without explicit cert configuration.

---

## Security: NKey

NKey is a challenge-response authentication scheme. The server never sees the private key.

- Go: `nats.NkeyOptionFromSeed("seed.txt")`
- Java: implement `AuthHandler` with `getID()` returning the public key and `sign(nonce)` returning the signature
- JS: `authenticator: nkeyAuthenticator(seed)` (seed as `Uint8Array`)
- Python: `nkeys_seed="./path/to/user.nk"`
- C#: `AuthOpts = new NatsAuthOpts { NKeyFile = "/path/to/user.nk" }`
- C: `natsOptions_SetNKey(opts, pubKey, sigHandler, closure)`

---

## Security: credentials file (.creds)

A credentials file contains both the user JWT and the NKey seed. Generated with the `nsc` tool. Treat as a secret.

- Go: `nats.UserCredentials("path_to_creds_file")`
- Java: `.authHandler(Nats.credentials("path_to_creds_file"))`
- JS: `authenticator: credsAuthenticator(creds)`
- Python: `user_credentials="path_to_creds_file"`
- C#: `new NatsClient("127.0.0.1", credsFile: "/path/to/file.creds")`
- C: `natsOptions_SetUserCredentialsFromFiles(opts, "path_to_creds_file", NULL)`

---

## Connection status

Check current status:
- Go: `nc.Status()` → `nats.CONNECTED | nats.CLOSED | ...`
- Java: `nc.getStatus()`
- JS: `nc.info.version`, `nc.stats()`
- Python: `nc.is_connected`, `nc.is_reconnecting`, `nc.is_closed`
- C#: `client.Connection.ConnectionState`
- Ruby: `nc.connected?`, `nc.reconnecting?`, `nc.closing?`

---

## Connection event listeners

Register callbacks before connecting. Callbacks are invoked asynchronously — the connection state may have already changed again by the time the callback runs.

Events: disconnect, reconnect, close, error (async), discovered-servers.

**Go** — set individual handlers as connect options:
```go
nats.DisconnectErrHandler(func(nc *nats.Conn, err error) { ... })
nats.ReconnectHandler(func(nc *nats.Conn) { ... })
nats.ClosedHandler(func(nc *nats.Conn) { ... })
nats.ErrorHandler(func(nc *nats.Conn, sub *nats.Subscription, err error) { ... })
nats.DiscoveredServersHandler(func(nc *nats.Conn) { ... })
```
`DisconnectedCB` is deprecated — use `DisconnectedErrCB`.

**Java** — implement `ConnectionListener` and pass via `.connectionListener()`. Implement `ErrorListener` and pass via `.errorListener()`.

**JavaScript** — iterate `nc.status()` async iterator. Events: `Events.Disconnect`, `Events.Reconnect`, `Events.Update`, `Events.LDM`, `Events.Error`, `DebugEvents.Reconnecting`, `DebugEvents.StaleConnection`.

**Python** — pass callbacks as connect options: `disconnected_cb`, `reconnected_cb`, `error_cb`, `closed_cb`.

**C#** — subscribe to events on `client.Connection`:
- `ConnectionDisconnected`
- `ConnectionOpened`
- `ReconnectFailed`
C# does not support discovered-servers or async error handlers; server errors are logged at error level with event ID 1005.

**Ruby** — `nc.on_disconnect`, `nc.on_reconnect`, `nc.on_close`, `nc.on_error`.

**Discovered servers** (when a new server joins the cluster):
- Go: `nats.DiscoveredServersHandler(func(nc){ nc.Servers(); nc.DiscoveredServers() })`
- Java: check for `Events.DISCOVERED_SERVERS` in `ConnectionListener`
- JS: `Status.Update` event with `s.data.added` / `s.data.deleted`
- Python, .NET, Ruby: not supported
