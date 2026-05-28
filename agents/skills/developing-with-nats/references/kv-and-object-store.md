# Key-Value Store and Object Store

## Contents

- KV Store overview and key rules
- KV operations: Get, Put, Create, Update, Delete, Purge, Keys, History, Watch
- KV consistency model
- Object Store overview
- Object Store operations

---

## KV Store overview

The Key-Value Store is built on JetStream streams. Each bucket is a stream named `KV_<bucket>`. All stream capabilities apply, but the KV API provides a higher-level interface.

**Bucket management:**
- Go: `js.CreateKeyValue(cfg)`, `js.KeyValue(bucket)`, `js.DeleteKeyValue(bucket)`
- Java: `jsm.keyValue().create(config)`, `.getBucketInfo(name)`, `.delete(name)`
- JavaScript: `KV.create(js, name, opts)`, `KV.bind(js, name)`
- Python: `js.create_key_value(config)`, `js.key_value(bucket)`, `js.delete_key_value(bucket)`
- C#: `js.CreateStoreAsync(bucket)`, `js.DeleteStoreAsync(bucket)`
- C: `js_CreateKeyValue()`, `js_KeyValue()`, `js_DeleteKeyValue()`

---

## KV key naming rules

**KV key characters differ from NATS subject characters.** Valid KV key characters:

```
a-z  A-Z  0-9  _  -  .  =  /
```

The `/` character is valid in KV keys (unlike NATS subjects where it is forbidden). Keys are case-sensitive. Maximum history per key is 64 revisions.

Keys can be dot-separated (hierarchical), enabling wildcard watches: watching `orders.>` matches `orders.new`, `orders.fulfilled`, etc.

---

## KV operations

### Get

Retrieve the current value or a specific revision:

- Go: `kv.Get(key)`, `kv.GetRevision(key, revision)`
- Java: `kv.get(key)`, `kv.get(key, revision)`
- JavaScript: `kv.get(key)`
- Python: `await kv.get(key)`
- C#: `kv.GetEntryAsync<T>(key, revision?)`
- C: `kvStore_Get()`, `kvStore_GetRevision()`

### Put

Store a value unconditionally:

- Go: `kv.Put(key, value)` → revision, `kv.PutString(key, value)` → revision
- Java: `kv.put(key, bytes)`, `kv.put(key, string)`, `kv.put(key, number)`
- JavaScript: `kv.put(key, data)`
- Python: `await kv.put(key, value)` → revision
- C#: `kv.PutAsync<T>(key, value)` → revision
- C: `kvStore_Put()`, `kvStore_PutString()`

### Create (compare-and-null-set)

Store a value only if the key does not currently exist (or was deleted):

- Go: `kv.Create(key, value)` → revision
- Java: `kv.create(key, bytes)`
- JavaScript: `kv.create(key, data)`
- C: `kvStore_Create()`, `kvStore_CreateString()`

Returns an error if the key already exists with a value.

### Update (compare-and-swap)

Store a value only if the current revision matches the expected revision:

- Go: `kv.Update(key, value, lastRevision)` → revision
- Java: `kv.update(key, bytes, expectedRevision)`
- JavaScript: `kv.update(key, data, version)`
- Python: `await kv.update(key, value, last)` → revision
- C: `kvStore_Update()`, `kvStore_UpdateString()`

Returns an error if the revision does not match. Use for optimistic locking.

### Delete

Places a delete marker. The key's history is preserved.

- Go: `kv.Delete(key)`
- Java: `kv.delete(key)`
- JavaScript: `kv.delete(key)`
- Python: `await kv.delete(key)`
- C#: `kv.DeleteAsync(key)`
- C: `kvStore_Delete()`

### Purge

Places a purge marker and removes all previous revisions for the key.

- Go: `kv.Purge(key)`
- Java: `kv.purge(key)`
- JavaScript: `kv.purge(key)`
- Python: `await kv.purge(key)`
- C#: `kv.PurgeAsync(key)`
- C: `kvStore_Purge()`, `kvStore_PurgeDeletes()`

### Keys

Returns all keys currently having a value (excluding deleted keys):

- Go: `kv.Keys()`
- Java: `kv.keys()`
- JavaScript: `kv.keys(pattern?)`
- C#: `kv.GetKeysAsync()`, `kv.GetKeysAsync(filters)`
- C: `kvStore_Keys()`

### History

Returns all stored revisions for a key. Maximum history depth is 64 revisions (set on bucket creation, default 1 — no history beyond the current value):

- Go: `kv.History(key)`
- Java: `kv.history(key)`
- JavaScript: `kv.history(opts?)`
- C#: `kv.HistoryAsync<T>(key)`
- C: `kvStore_History()`

### Watch

Subscribe to changes on a key or all keys. Watcher receives the current values first, then real-time updates. A nil/null entry signals that all initial values have been sent.

- Go: `kv.Watch(keys)`, `kv.WatchAll()`
- Java: `kv.watch(key, watcher)`, `kv.watchAll(watcher)`
- JavaScript: `kv.watch(opts?)`
- C#: `kv.WatchAsync<T>(key)`, `kv.WatchAsync<T>(keys)`, `kv.WatchAsync<T>()`
- C: `kvStore_Watch()`, `kvStore_WatchAll()`

Wildcard keys work in Watch: `kv.Watch("orders.>")` receives updates for all keys under `orders.`.

---

## KV consistency model

The KV Store provides:
- **Monotonic writes** — writes are ordered
- **Monotonic reads** — reads are ordered

The KV Store does **not** guarantee **read-your-writes** for direct-get operations. Reads may be served by followers or mirrors. For consistent reads, send get requests to the stream leader of the KV bucket's underlying stream.

---

## Object Store overview

The Object Store stores arbitrarily large values by chunking them into multiple NATS messages. Use it when values exceed the maximum NATS message size (default 1 MB).

Unlike the KV Store, Object Store keys are file-path style strings (not NATS subjects). Object Store is built on JetStream streams.

Object store management:
- Go: `js.CreateObjectStore(ctx, cfg)`, `js.ObjectStore(ctx, bucket)`, `js.DeleteObjectStore(ctx, bucket)`
- Java: `jsm.objectStore()` — `create(config)`, `getList()`, `delete(name)`
- Python: `js.create_object_store(bucket, config?)`, `js.object_store(bucket)`, `js.delete_object_store(bucket)`
- C#: `js.CreateObjectStoreAsync(bucket)`, `js.GetObjectStoreAsync(bucket)`, `js.DeleteObjectStore(bucket)`

---

## Object Store operations

### Put (store an object)

- Go: `store.Put(ctx, meta, reader)`, `store.PutBytes(ctx, name, data)`, `store.PutString(ctx, name, data)`, `store.PutFile(ctx, filePath)`
- Java: `store.put(meta, inputStream)`, `store.put(name, bytes)`, `store.put(file)`
- C#: `store.PutAsync(key, bytes)`, `store.PutAsync(key, stream)`, `store.PutAsync(meta, stream)`

### Get (retrieve an object)

- Go: `store.Get(ctx, name)` → reader, `store.GetBytes(ctx, name)`, `store.GetString(ctx, name)`, `store.GetFile(ctx, name, destPath)`
- Java: `store.get(name, outputStream)`
- C#: `store.GetBytesAsync(key)`, `store.GetAsync(key, stream)`

Get verifies the SHA digest of retrieved data against the stored metadata. If the digest does not match, an error is returned.

### Info, Update, Delete

- Go: `store.GetInfo(ctx, name)`, `store.UpdateMeta(ctx, name, meta)`, `store.Delete(ctx, name)`
- Java: `store.getInfo(name)`, `store.updateMeta(name, meta)`, `store.delete(name)`
- C#: `store.GetInfoAsync(key)`, `store.UpdateMetaAsync(key, meta)`, `store.DeleteAsync(key)`

`Delete` marks the object as deleted and purges its chunks. Deleted objects can still be retrieved if `GetObjectShowDeleted` option is passed.

### Links

An object can be a link to another object or to another Object Store bucket:

- Go: `store.AddLink(ctx, name, targetInfo)`, `store.AddBucketLink(ctx, name, targetStore)`
- Java: `store.addLink(name, toInfo)`, `store.addBucketLink(name, toStore)`
- C#: `store.AddLinkAsync(link, target)`, `store.AddBucketLinkAsync(link, targetStore)`

### Seal

Prevents further modifications to the bucket:

- Go: `store.Seal(ctx)`
- Java: `store.seal()`
- C#: `store.SealAsync()`

### Watch and List

- Go: `store.Watch(ctx, opts?)` — receive metadata updates, `store.List(ctx, opts?)` — list all object infos
- Java: `store.watch(watcher, options...)`, `store.getList()`
- C#: `store.WatchAsync<ObjectMetadata>(opts?)`, `store.ListAsync(opts?)`
