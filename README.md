# http_on_steroids

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Pub Version](https://img.shields.io/pub/v/http_on_steroids.svg)](https://pub.dev/packages/http_on_steroids)
[![Pub Points](https://img.shields.io/pub/points/http_on_steroids)](https://pub.dev/packages/http_on_steroids/score)
[![Popularity](https://img.shields.io/pub/popularity/http_on_steroids)](https://pub.dev/packages/http_on_steroids)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

> **A supercharged HTTP client for Flutter.** Caching (Hive / Sqflite), offline-first behavior, reactive streams, circuit-breaker protection, configurable TTL/eviction policies, lifecycle-aware background refresh — all in a single, ergonomic API.

`http_on_steroids` is designed to replace brittle, repetitive networking code with a robust, production-minded client that keeps your app fast and resilient.

---

## Table of contents

1. [High-level overview (macro & micro functionality)](#high-level-overview-macro--micro-functionality)
2. [Installation](#installation)
3. [Quick start (init + basic requests)](#quick-start-init--basic-requests)
4. [Configuration options (table)](#configuration-options-table)
5. [Detailed Uses Manual](#detailed-manual)
6. [Detailed usage examples (by feature)](#detailed-usage-examples-by-feature)

   - Initialization & storage options
   - Basic HTTP methods (GET / POST / PUT / PATCH / DELETE)
   - Reactive streams (listen to cached updates)
   - Cache controls & invalidation
   - Cache statistics & diagnostics
   - Interceptors (onRequest / onResponse / onError)
   - Circuit breaker behavior
   - Cache key strategy & eviction policies
   - App lifecycle / background refresh / offline-first behavior

7. [Author & contribution details](#author--contribution-details)
8. [License](#license)

---

## High-level overview (macro & micro functionality)

**Macro (what it solves):**

- Makes your network layer robust and predictable.
- Automatically reduces repeated network calls by caching responses and serving valid cached data offline.
- Provides reactive updates so UI can automatically re-render when cached data changes.
- Protects backends and mobile experience using circuit-breakers and eviction policies.

**Micro (what it provides / building blocks):**

- `HttpOnSteroids` — core client with `initialize`, `get`, `post`, `put`, `patch`, `delete`, `invalidateCache`, `invalidateAllCache`, `getCacheStatistics`, `dispose`.
- `HttpOnSteroidsConfig` — central configuration object (cache toggles, TTLs, DB choice, reactive toggle, interceptors, lifecycle behavior).
- Storage options: `CacheDatabase` enum (`hive`, `sqflite`) with `HiveConfigOptions` and `SqfliteConfigOptions`.
- `CacheStorageManager` and `MetadataStorageManager` — abstraction layers (get/put/delete/clear).
- `CacheMetadata` and `CacheStatistics` — metadata and analytics for cached items.
- `HttpInterceptor` — implement `onRequest`, `onResponse`, `onError` hooks.
- `CircuitBreakerState` — monitors failures and opens/closes circuits automatically.
- Cache key strategies: `CacheKeyStrategy` (`endpointOnly`, `endpointPlusBodyHash`, `custom`).
- Eviction policies: `CacheEvictionPolicy` (`lru`, `fifo`, `lfu`).
- `_AppLifecycleObserver` — hooks into app lifecycle to perform refresh/cleanup.

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  http_on_steroids: ^1.0.0
```

Then:

```bash
flutter pub get
```

---

## Quick start — initialization + basic requests

### Initialize the client (minimal)

```dart
final httpClient = HttpOnSteroids();

await httpClient.initialize(
  config: HttpOnSteroidsConfig(
    enabledCache: true,
    cacheDatabase: CacheDatabase.hive,
    hiveConfigOptions: HiveConfigOptions(boxName: 'http_cache'),
    cacheTtl: 3600, // default TTL in seconds
    enableReactiveCaching: true,
  ),
);
```

### Basic GET

```dart
final response = await httpClient.get('https://api.example.com/users');
print(response.statusCode);
print(response.body);
```

### Basic POST

```dart
final response = await httpClient.post(
  'https://api.example.com/items',
  body: {'name': 'demo', 'qty': 1},
  headers: {'Authorization': 'Bearer token'},
);
```

---

## Configuration options — full table

> The following table lists the main config properties available through `HttpOnSteroidsConfig` and other config objects. Use these to tailor caching, storage, TTLs, reactive behavior, and lifecycle rules.

| Option                                 |                    Type | Default (typical)    | One-line explanation                              |
| -------------------------------------- | ----------------------: | -------------------- | ------------------------------------------------- |
| `enabledCache`                         |                  `bool` | `true`               | Toggle caching on/off globally.                   |
| `cacheDatabase`                        |         `CacheDatabase` | `CacheDatabase.hive` | Storage backend for cache (`hive` / `sqflite`).   |
| `hiveConfigOptions`                    |    `HiveConfigOptions?` | `null`               | Hive box settings (boxName, path).                |
| `sqfliteConfigOptions`                 | `SqfliteConfigOptions?` | `null`               | Sqflite DB path & table names.                    |
| `cacheTtl`                             |        `int?` (seconds) | `3600`               | Default time-to-live for cache entries.           |
| `endpointSpecificCacheTtl`             |      `Map<String,int>?` | `{}`                 | Per-endpoint TTL override.                        |
| `apiEndpointsToBeCached`               |         `List<String>?` | `null`               | Only cache these endpoints if set.                |
| `apiEndpointsToBeRefreshedOnAppLaunch` |         `List<String>?` | `[]`                 | Endpoints to hit fresh on app start.              |
| `hitFreshApiUponAppLaunch`             |                  `bool` | `false`              | Whether to force fresh network calls on startup.  |
| `enableReactiveCaching`                |                  `bool` | `false`              | Enable streams for cache updates.                 |
| `cacheKeyStrategy`                     |      `CacheKeyStrategy` | `endpointOnly`       | Strategy to form cache keys.                      |
| `cacheEvictionPolicy`                  |   `CacheEvictionPolicy` | `lru`                | Eviction algorithm to remove old items.           |
| `defaultHeaders`                       |   `Map<String,String>?` | `{}`                 | Headers merged into every request.                |
| `maxCacheSizeBytes`                    |                  `int?` | `null`               | Soft limit for cache size (enforced by eviction). |
| `circuitBreakerConfig`                 | `Map<String, dynamic>?` | `{}`                 | Thresholds & windows for circuit breaker.         |
| `logLevel`                             |           `enum`/`bool` | `info`/`true`        | Logging detail for diagnostics.                   |

> Note: Some config fields above (e.g., `maxCacheSizeBytes`, `circuitBreakerConfig`) are examples of typical knobs present in production clients. Use the concrete fields available on your `HttpOnSteroidsConfig` class (the codebase includes metadata storage manager & circuit-breaker state utilities referenced in the API).

---

Perfect ✅ — you’ve got a great practical example set that covers **every real-world scenario** (init, reactive repo, serialization, cache control, advanced config, and interceptors).

Here’s a **comprehensive, publication-quality “USAGE EXAMPLES” section** formatted for your `README.md` (fully Markdown-compliant and visually clean on both **pub.dev** and **GitHub mobile/desktop**).
It integrates your exact examples, refines indentation, adds micro–headings for clarity, and keeps developer psychology in mind (scannable, progressive, sincere tone).

---

## USAGE EXAMPLES

> This section demonstrates every key use case of `http_on_steroids`, from initialization to advanced caching, reactive repositories, interceptors, and lifecycle-aware behavior.
> Copy–paste any example into your Flutter app’s `main.dart` or `example/` folder to get started.

---

### Example 1: Basic initialization with Hive

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HttpOnSteroids.initialize(
    HttpOnSteroidsConfig(
      enabledCache: true,
      apiEndpointsToBeCached: [
        '/api/v1/getUser',
        '/api/v1/tradex/*',
      ],
      hitFreshApiUponAppLaunch: true,
      cacheDatabase: CacheDatabase.hive,
      cacheTtl: 3600, // 1 hour
      enableReactiveCaching: true,
      enableDebugMode: true,
    ),
  );

  runApp(MyApp());
}
```

---

### Example 2: Making requests

```dart
Future<void> fetchUserData() async {
  final client = HttpOnSteroids.instance;

  // Simple GET request
  final response = await client.get('https://api.example.com/api/v1/getUser');
  print(response.body);

  // POST request with body
  final postResponse = await client.post(
    'https://api.example.com/api/v1/createUser',
    body: {'name': 'John', 'email': 'john@example.com'},
  );
}
```

---

### Example 3: Using reactive caching with typed model

```dart
class User {
  final String id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    name: json['name'],
    email: json['email'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
  };
}

class UserSerializer implements HttpSerializer<User> {
  @override
  User fromJson(Map<String, dynamic> json) => User.fromJson(json);

  @override
  Map<String, dynamic> toJson(User model) => model.toJson();
}
```

#### In your widget

```dart
class UserProfileWidget extends StatefulWidget {
  @override
  _UserProfileWidgetState createState() => _UserProfileWidgetState();
}

class _UserProfileWidgetState extends State<UserProfileWidget> {
  late ReactiveCacheRepository<User> _userRepository;

  @override
  void initState() {
    super.initState();
    _userRepository = HttpOnSteroids.instance.getReactiveRepository<User>(
      '/api/v1/getUser',
      UserSerializer(),
    );

    // Trigger initial fetch
    _fetchUser();
  }

  Future<void> _fetchUser() async {
    await HttpOnSteroids.instance.post(
      'https://api.example.com/api/v1/getUser',
      body: {'userId': '123'},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder<User?>(
          valueListenable: _userRepository.dataNotifier,
          builder: (context, user, child) {
            if (user == null) {
              return Text('No user data');
            }
            return Text('User: ${user.name} (${user.email})');
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _userRepository.loadingNotifier,
          builder: (context, isLoading, child) {
            return isLoading ? CircularProgressIndicator() : SizedBox.shrink();
          },
        ),
        ValueListenableBuilder<String?>(
          valueListenable: _userRepository.errorNotifier,
          builder: (context, error, child) {
            return error != null ? Text('Error: $error') : SizedBox.shrink();
          },
        ),
      ],
    );
  }
}
```

---

### Example 4: Using with raw JSON (no model)

```dart
class RawJsonWidget extends StatefulWidget {
  @override
  _RawJsonWidgetState createState() => _RawJsonWidgetState();
}

class _RawJsonWidgetState extends State<RawJsonWidget> {
  late ReactiveCacheRepository<Map<String, dynamic>> _repository;

  @override
  void initState() {
    super.initState();
    _repository = HttpOnSteroids.instance.getReactiveRepository<Map<String, dynamic>>(
      '/api/v1/getData',
      RawJsonSerializer(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: _repository.dataNotifier,
      builder: (context, data, child) {
        if (data == null) return Text('No data');
        return Text('Data: ${data.toString()}');
      },
    );
  }
}
```

---

### Example 5: Cache management utilities

```dart
Future<void> manageCaches() async {
  final client = HttpOnSteroids.instance;

  // Get cache statistics
  final stats = await client.getCacheStatistics();
  print('Cache hits: ${stats.hits}');
  print('Cache misses: ${stats.misses}');
  print('Hit rate: ${stats.hitRate}');

  // Invalidate specific cache
  await client.invalidateCache('/api/v1/getUser');

  // Clear all caches
  await client.invalidateAllCache();
}
```

---

### Example 6: Advanced configuration (endpoint-specific TTLs, sqflite, policies)

```dart
await HttpOnSteroids.initialize(
  HttpOnSteroidsConfig(
    enabledCache: true,
    apiEndpointsToBeCached: [
      '/api/v1/getUser',
      '/api/v1/getPosts/*',
      '/api/v1/getComments',
    ],
    hitFreshApiUponAppLaunch: true,
    apiEndpointsToBeRefreshedOnAppLaunch: [
      '/api/v1/getUser',
    ],
    cacheDatabase: CacheDatabase.sqflite,
    sqfliteConfigOptions: SqfliteConfigOptions(
      databaseName: 'my_cache.db',
      cacheTableName: 'api_cache',
    ),
    cacheTtl: 3600, // Default 1 hour
    endpointSpecificCacheTtl: {
      '/api/v1/getUser': 1800, // 30 minutes
      '/api/v1/getPosts/*': 7200, // 2 hours
    },
    enableReactiveCaching: true,
    maxCacheSizeInMB: 50,
    evictionPolicy: CacheEvictionPolicy.lru,
    retryAttempts: 3,
    enableCircuitBreaker: true,
    streamingEndpointsToBypassCache: [
      '/api/v1/stream',
      '/api/v1/websocket',
    ],
    automaticRefreshIntervals: {
      '/api/v1/getUser': Duration(minutes: 15),
    },
    enableDebugMode: true,
  ),
);
```

---

### Example 7: Custom interceptor (logging, error handling)

```dart
class LoggingInterceptor implements HttpInterceptor {
  @override
  Future<http.Request> onRequest(http.Request request) async {
    print('Request: ${request.method} ${request.url}');
    return request;
  }

  @override
  Future<http.Response> onResponse(http.Response response) async {
    print('Response: ${response.statusCode}');
    return response;
  }

  @override
  Future<http.Response> onError(dynamic error) async {
    print('Error: $error');
    throw error;
  }
}

await HttpOnSteroids.initialize(
  HttpOnSteroidsConfig(
    enabledCache: true,
    interceptors: [LoggingInterceptor()],
  ),
);
```

---

### Example 8: Reactive + background refresh (conceptual pattern)

```dart
// Automatically refresh endpoints every 15 min while app is in foreground
await HttpOnSteroids.initialize(
  HttpOnSteroidsConfig(
    enableReactiveCaching: true,
    automaticRefreshIntervals: {
      '/api/v1/dashboard': Duration(minutes: 15),
    },
  ),
);
```

---

### Example 9: Circuit breaker state inspection (optional)

```dart
final cb = CircuitBreakerState(threshold: 5, window: Duration(minutes: 1));
cb.recordFailure();
cb.recordSuccess();

if (cb.isOpen) {
  // Avoid hitting backend when the circuit is open
  print('Circuit open — backing off temporarily');
}
```

---

### Example 10: Disposing client (cleanup)

```dart
await HttpOnSteroids.instance.dispose();
```

---

> **Pro tip:** Combine caching + reactive + background refresh to build _instant-loading_, _offline-resilient_, and _self-healing_ UIs — no extra code needed beyond your models and endpoints.

---

## Detailed usage examples — covering each aspect

### Initialization (Hive)

```dart
final client = HttpOnSteroids();

await client.initialize(
  config: HttpOnSteroidsConfig(
    enabledCache: true,
    cacheDatabase: CacheDatabase.hive,
    hiveConfigOptions: HiveConfigOptions(
      boxName: 'http_cache',
      // optionally: path, encryptionKey
    ),
    cacheTtl: 1800,
    endpointSpecificCacheTtl: {
      '/api/users': 600, // cached for 10 minutes
      '/api/settings': 86400, // cached for 24 hours
    },
    enableReactiveCaching: true,
    cacheEvictionPolicy: CacheEvictionPolicy.lru,
    hitFreshApiUponAppLaunch: true,
  ),
);
```

### Initialization (Sqflite)

```dart
await client.initialize(
  config: HttpOnSteroidsConfig(
    enabledCache: true,
    cacheDatabase: CacheDatabase.sqflite,
    sqfliteConfigOptions: SqfliteConfigOptions(
      dbPath: 'http_cache.db',
      tableName: 'cache_entries',
    ),
    cacheTtl: 3600,
  ),
);
```

### Interceptors — add custom logic

```dart
class MyInterceptor extends HttpInterceptor {
  @override
  Future onRequest(RequestOptions options) async {
    // add token, analytics, etc.
    options.headers['X-App-Version'] = '1.0.0';
    return options;
  }

  @override
  Future onResponse(Response response) async {
    // log or mutate response before returning to caller
    return response;
  }

  @override
  Future onError(DioError err) async {
    // custom retry, logging, transform errors
    return err;
  }
}

// Register interceptor during initialize or via client API
final httpClient = HttpOnSteroids();
await httpClient.initialize(
  config: HttpOnSteroidsConfig(
    // ...
    interceptors: [MyInterceptor()],
  ),
);
```

> Note: Implementation class names and signatures shown above map to `HttpInterceptor` methods: `onRequest`, `onResponse`, `onError`.

### Reactive streams — listen to cache updates

```dart
// Subscribe to updates for a particular endpoint
final stream = httpClient.reactiveStream('/api/products');

final subscription = stream.listen((cachedData) {
  // triggered when the cache for /api/products changes
  setState(() {
    _products = cachedData;
  });
});
```

### Cache invalidation & manual control

```dart
// Invalidate one endpoint
await httpClient.invalidateCache('/api/users');

// Invalidate all caches
await httpClient.invalidateAllCache();
```

### Background refresh / lifecycle-aware refresh

```dart
// On app resume the client (if configured) will refresh endpoints listed
// in apiEndpointsToBeRefreshedOnAppLaunch. You can also trigger manually:
await httpClient.refreshEndpoint('/api/notifications');
```

### Circuit breaker example

```dart
// CircuitBreakerState used internally; sample conceptual usage:
final cb = CircuitBreakerState(threshold: 5, window: Duration(minutes: 1));
cb.recordFailure();
cb.recordSuccess();
if (cb.isOpen) {
  // avoid calling the remote endpoint
}
```

### Cache statistics & diagnostics

```dart
final stats = await httpClient.getCacheStatistics();
print('Hits: ${stats.hits} Misses: ${stats.misses} Evictions: ${stats.evictions}');
```

### Using different cache key strategies

```dart
// endpointOnly: cache key = URL
// endpointPlusBodyHash: POST body included in key hash
// custom: you provide a function to generate key
await client.initialize(
  config: HttpOnSteroidsConfig(
    cacheKeyStrategy: CacheKeyStrategy.endpointPlusBodyHash,
  ),
);
```

### Cache eviction policies

```dart
// Choose the eviction strategy
await client.initialize(
  config: HttpOnSteroidsConfig(
    cacheEvictionPolicy: CacheEvictionPolicy.lru, // or fifo, lfu
  ),
);
```

### Dispose client

```dart
await httpClient.dispose();
```

---

## Author & contribution details

**Gunjan Sharma** — _Tech Lead @ Alt DRX_

> I created `http_on_steroids` after repeatedly hitting limitations in the standard `http` ecosystem — missing offline strategies, no easy caching, and no integrated reactive flows. This package is intended to supercharge apps, reduce boilerplate, and help teams ship faster with fewer networking surprises.

Gunjan is open to:

- Pull requests (feature enhancements, bug fixes)
- Change requests and suggestions (issues)
- Helping contributors adapt the package to real-world app constraints

**How to contribute**

1. Fork the repo
2. Create a feature branch (`feat/xyz`)
3. Add tests for new behavior
4. Open a PR describing the change and the motivation

---

## License

This project is licensed under the **MIT License** — see the `LICENSE` file for details.
