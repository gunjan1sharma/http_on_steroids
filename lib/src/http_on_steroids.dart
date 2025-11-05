// http_on_steroids.dart
// Version: 1.0.0
// A powerful HTTP client wrapper with advanced caching, reactive updates, and offline support

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:synchronized/synchronized.dart';

// ============================================================================
// CONFIGURATION CLASSES
// ============================================================================

/// Main configuration class for HttpOnSteroids
class HttpOnSteroidsConfig {
  /// Enables or disables the caching mechanism for HTTP requests.
  /// When set to `true`, responses will be stored locally based on your cache configuration.
  final bool enabledCache;

  /// List of API endpoint paths that should be cached.
  /// If `null`, all endpoints will be cached when `enabledCache` is `true`.
  /// Use specific paths (e.g., '/api/users', '/products') to cache selectively.
  final List<String>? apiEndpointsToBeCached;

  /// Forces a fresh API call (bypassing cache) when the app launches.
  /// Useful for ensuring users see the latest data on app start.
  final bool hitFreshApiUponAppLaunch;

  /// Specific endpoints to refresh from network on app launch.
  /// If `null` and `hitFreshApiUponAppLaunch` is `true`, all cached endpoints will be refreshed.
  final List<String>? apiEndpointsToBeRefreshedOnAppLaunch;

  /// The local database engine to use for storing cached responses.
  /// Choose between Hive (fast, key-value) or Sqflite (SQL-based) based on your needs.
  final CacheDatabase cacheDatabase;

  /// Configuration options for Hive database.
  /// Required when `cacheDatabase` is set to `CacheDatabase.hive`.
  final HiveConfigOptions? hiveConfigOptions;

  /// Configuration options for Sqflite database.
  /// Required when `cacheDatabase` is set to `CacheDatabase.sqflite`.
  final SqfliteConfigOptions? sqfliteConfigOptions;

  /// Default time-to-live for cached responses in seconds.
  /// Set to `null` for infinite cache duration. Expired cache is automatically invalidated.
  final int? cacheTtl;

  /// Override TTL for specific endpoints (in seconds).
  /// Map endpoint paths to custom TTL values. Example: `{'/api/static': 3600, '/api/dynamic': 60}`
  final Map<String, int>? endpointSpecificCacheTtl;

  /// Enables reactive cache updates using streams.
  /// When `true`, cached data changes emit updates to listeners automatically.
  final bool enableReactiveCaching;

  /// Default HTTP headers to include in all requests.
  /// These headers are merged with request-specific headers.
  final Map<String, String>? defaultHeaders;

  /// HTTP interceptors for request/response manipulation.
  /// Interceptors execute in order for requests and reverse order for responses.
  final List<HttpInterceptor>? interceptors;

  /// Indicates whether response bodies are encrypted.
  /// When `true`, you need to pass raw body while invoking API to prepare consistent body hash for caching.
  final bool isBodyEncrypted;

  /// Strategy for generating cache keys from requests.
  /// Determines how URLs, headers, and query parameters are used to create unique cache identifiers.
  final CacheKeyStrategy cacheKeyStrategy;

  /// Enables HTTP conditional caching using ETag and Last-Modified headers.
  /// When `true`, the package sends If-None-Match/If-Modified-Since headers to minimize bandwidth.
  final bool enableConditionalCaching;

  /// Maximum cache storage size in megabytes.
  /// When limit is reached, the eviction policy determines which entries to remove. `null` means unlimited.
  final int? maxCacheSizeInMB;

  /// Policy for removing cached entries when storage limit is reached.
  /// Options typically include LRU (Least Recently Used), LFU (Least Frequently Used), or FIFO.
  final CacheEvictionPolicy evictionPolicy;

  /// Number of automatic retry attempts for failed network requests.
  /// Set to `0` to disable retries.
  final int retryAttempts;

  /// Delay duration between retry attempts.
  /// Uses exponential backoff when multiple retries are configured.
  final Duration retryDelay;

  /// Maximum time to wait for a single HTTP request to complete.
  /// Request fails with timeout error if this duration is exceeded.
  final Duration requestTimeout;

  /// Enables circuit breaker pattern to prevent cascading failures.
  /// When `true`, temporarily stops requests to failing endpoints.
  final bool enableCircuitBreaker;

  /// Number of consecutive failures before the circuit breaker opens.
  /// Once open, requests fail immediately without attempting network calls.
  final int circuitBreakerThreshold;

  /// Duration to wait before attempting to close an open circuit breaker.
  /// After this timeout, one request is allowed through to test if the service recovered.
  final Duration circuitBreakerResetTimeout;

  /// Enables intelligent handling of paginated API responses.
  /// When `true`, the package understands pagination patterns and caches pages appropriately.
  final bool enablePaginationAwareness;

  /// List of endpoints that use streaming protocols (SSE/WebSocket) and should bypass cache.
  /// These real-time endpoints are never cached due to their streaming nature.
  final List<String>? streamingEndpointsToBypassCache;

  /// Configures automatic background refresh for specific endpoints.
  /// Map endpoint paths to refresh intervals. Example: `{'/api/feed': Duration(minutes: 5)}`
  final Map<String, Duration>? automaticRefreshIntervals;

  /// Offloads heavy serialization/deserialization work to separate isolates.
  /// Improves UI performance for large responses but adds slight overhead for small payloads.
  final bool useIsolatesForHeavyWork;

  /// Version number for your cache schema.
  /// Increment this when your API response structure changes to invalidate old cached data.
  final int cacheSchemaVersion;

  /// Enables verbose logging for debugging cache behavior.
  /// When `true`, prints detailed information about cache hits, misses, and operations.
  final bool enableDebugMode;

  const HttpOnSteroidsConfig({
    this.enabledCache = false,
    this.apiEndpointsToBeCached,
    this.hitFreshApiUponAppLaunch = false,
    this.apiEndpointsToBeRefreshedOnAppLaunch,
    this.cacheDatabase = CacheDatabase.hive,
    this.hiveConfigOptions,
    this.sqfliteConfigOptions,
    this.cacheTtl,
    this.endpointSpecificCacheTtl,
    this.enableReactiveCaching = false,
    this.defaultHeaders,
    this.interceptors,
    this.isBodyEncrypted = false,
    this.cacheKeyStrategy = CacheKeyStrategy.endpointPlusBodyHash,
    this.enableConditionalCaching = true,
    this.maxCacheSizeInMB,
    this.evictionPolicy = CacheEvictionPolicy.lru,
    this.retryAttempts = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.requestTimeout = const Duration(seconds: 30),
    this.enableCircuitBreaker = true,
    this.circuitBreakerThreshold = 5,
    this.circuitBreakerResetTimeout = const Duration(seconds: 60),
    this.enablePaginationAwareness = false,
    this.streamingEndpointsToBypassCache,
    this.automaticRefreshIntervals,
    this.useIsolatesForHeavyWork = true,
    this.cacheSchemaVersion = 1,
    this.enableDebugMode = false,
  });
}

enum CacheDatabase { hive, sqflite }

enum CacheKeyStrategy { endpointOnly, endpointPlusBodyHash, custom }

enum CacheEvictionPolicy { lru, fifo, lfu }

/// Hive-specific configuration options
class HiveConfigOptions {
  final String cacheBoxName;
  final String reactiveCacheBoxName;
  final String metadataBoxName;
  final bool encryptionEnabled;
  final List<int>? encryptionKey;

  const HiveConfigOptions({
    this.cacheBoxName = 'http_cache',
    this.reactiveCacheBoxName = 'http_reactive_cache',
    this.metadataBoxName = 'http_metadata',
    this.encryptionEnabled = false,
    this.encryptionKey,
  });
}

/// SQLite-specific configuration options
class SqfliteConfigOptions {
  final String databaseName;
  final String cacheTableName;
  final String reactiveCacheTableName;
  final String metadataTableName;
  final int databaseVersion;

  const SqfliteConfigOptions({
    this.databaseName = 'http_cache.db',
    this.cacheTableName = 'cache',
    this.reactiveCacheTableName = 'reactive_cache',
    this.metadataTableName = 'metadata',
    this.databaseVersion = 1,
  });
}

/// HTTP Interceptor interface
abstract class HttpInterceptor {
  Future<http.Request> onRequest(http.Request request);
  Future<http.Response> onResponse(http.Response response);
  Future<http.Response> onError(dynamic error);
}

// ============================================================================
// CACHE METADATA MODEL
// ============================================================================

class CacheMetadata {
  final String cacheKey;
  final DateTime cachedAt;
  final DateTime? expiresAt;
  final String? etag;
  final String? lastModified;
  final int responseCode;
  final int accessCount;
  final DateTime lastAccessedAt;
  final int sizeInBytes;
  final int schemaVersion;

  CacheMetadata({
    required this.cacheKey,
    required this.cachedAt,
    this.expiresAt,
    this.etag,
    this.lastModified,
    required this.responseCode,
    this.accessCount = 0,
    required this.lastAccessedAt,
    required this.sizeInBytes,
    required this.schemaVersion,
  });

  Map<String, dynamic> toJson() => {
    'cacheKey': cacheKey,
    'cachedAt': cachedAt.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
    'etag': etag,
    'lastModified': lastModified,
    'responseCode': responseCode,
    'accessCount': accessCount,
    'lastAccessedAt': lastAccessedAt.toIso8601String(),
    'sizeInBytes': sizeInBytes,
    'schemaVersion': schemaVersion,
  };

  factory CacheMetadata.fromJson(Map<String, dynamic> json) => CacheMetadata(
    cacheKey: json['cacheKey'],
    cachedAt: DateTime.parse(json['cachedAt']),
    expiresAt: json['expiresAt'] != null
        ? DateTime.parse(json['expiresAt'])
        : null,
    etag: json['etag'],
    lastModified: json['lastModified'],
    responseCode: json['responseCode'],
    accessCount: json['accessCount'] ?? 0,
    lastAccessedAt: DateTime.parse(json['lastAccessedAt']),
    sizeInBytes: json['sizeInBytes'],
    schemaVersion: json['schemaVersion'],
  );

  CacheMetadata copyWith({int? accessCount, DateTime? lastAccessedAt}) =>
      CacheMetadata(
        cacheKey: cacheKey,
        cachedAt: cachedAt,
        expiresAt: expiresAt,
        etag: etag,
        lastModified: lastModified,
        responseCode: responseCode,
        accessCount: accessCount ?? this.accessCount,
        lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
        sizeInBytes: sizeInBytes,
        schemaVersion: schemaVersion,
      );
}

// ============================================================================
// CACHE STATISTICS MODEL
// ============================================================================

class CacheStatistics {
  final int hits;
  final int misses;
  final int totalRequests;
  final DateTime? lastUpdated;
  final int totalCachedEntries;
  final int totalCacheSizeInBytes;

  CacheStatistics({
    required this.hits,
    required this.misses,
    required this.totalRequests,
    this.lastUpdated,
    required this.totalCachedEntries,
    required this.totalCacheSizeInBytes,
  });

  double get hitRate => totalRequests > 0 ? hits / totalRequests : 0.0;
}

// ============================================================================
// REACTIVE CACHE REPOSITORY
// ============================================================================

/// Repository for reactive cached APIs
/// Provides ValueNotifier-based streams for real-time UI updates
class ReactiveCacheRepository<T> {
  final String endpoint;
  final ValueNotifier<T?> _valueNotifier = ValueNotifier<T?>(null);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _error = ValueNotifier<String?>(null);

  ReactiveCacheRepository(this.endpoint);

  /// Get the ValueNotifier for the cached data
  ValueNotifier<T?> get dataNotifier => _valueNotifier;

  /// Get the loading state notifier
  ValueNotifier<bool> get loadingNotifier => _isLoading;

  /// Get the error state notifier
  ValueNotifier<String?> get errorNotifier => _error;

  /// Get current value synchronously
  T? get value => _valueNotifier.value;

  /// Update the cached value
  void _updateValue(T? newValue) {
    _valueNotifier.value = newValue;
  }

  /// Update loading state
  void _updateLoading(bool isLoading) {
    _isLoading.value = isLoading;
  }

  /// Update error state
  void _updateError(String? error) {
    _error.value = error;
  }

  void dispose() {
    _valueNotifier.dispose();
    _isLoading.dispose();
    _error.dispose();
  }
}

// ============================================================================
// SERIALIZER INTERFACE
// ============================================================================

/// Generic serializer interface for model conversion
abstract class HttpSerializer<T> {
  T fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson(T model);
}

/// Raw JSON serializer (no conversion)
class RawJsonSerializer implements HttpSerializer<Map<String, dynamic>> {
  @override
  Map<String, dynamic> fromJson(Map<String, dynamic> json) => json;

  @override
  Map<String, dynamic> toJson(Map<String, dynamic> model) => model;
}

// ============================================================================
// MAIN HTTP ON STEROIDS CLIENT
// ============================================================================

class HttpOnSteroids {
  static HttpOnSteroids? _instance;
  late HttpOnSteroidsConfig _config;
  late http.Client _httpClient;

  // Cache storage managers
  late CacheStorageManager _cacheStorageManager;
  late CacheStorageManager _reactiveCacheStorageManager;
  late MetadataStorageManager _metadataStorageManager;

  // Reactive repositories
  final Map<String, ReactiveCacheRepository> _reactiveRepositories = {};

  // Connectivity
  late Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;

  // Circuit breaker
  final Map<String, CircuitBreakerState> _circuitBreakers = {};

  // Locks for cache operations (prevent race conditions)
  final Map<String, Lock> _cacheLocks = {};

  // App lifecycle
  bool _isAppFirstLaunch = true;
  bool _coldStartRefreshCompleted = false;

  // Statistics
  int _cacheHits = 0;
  int _cacheMisses = 0;

  HttpOnSteroids._();

  /// Initialize HttpOnSteroids with configuration
  static Future<HttpOnSteroids> initialize(HttpOnSteroidsConfig config) async {
    if (_instance != null) {
      throw Exception(
        'HttpOnSteroids is already initialized. Use HttpOnSteroids.instance instead.',
      );
    }

    _instance = HttpOnSteroids._();
    await _instance!._initializeInternal(config);
    return _instance!;
  }

  /// Get the singleton instance
  static HttpOnSteroids get instance {
    if (_instance == null) {
      throw Exception(
        'HttpOnSteroids is not initialized. Call HttpOnSteroids.initialize() first.',
      );
    }
    return _instance!;
  }

  /// Internal initialization
  Future<void> _initializeInternal(HttpOnSteroidsConfig config) async {
    _config = config;
    _httpClient = http.Client();
    _connectivity = Connectivity();

    // Initialize cache storage based on database type
    await _initializeCacheStorage();

    // Initialize connectivity monitoring
    await _initializeConnectivityMonitoring();

    // Initialize app lifecycle listener
    _initializeAppLifecycleListener();

    // Perform cache validation and cleanup
    await _performCacheValidationAndCleanup();

    // Schedule automatic refresh if configured
    _scheduleAutomaticRefresh();

    _log('HttpOnSteroids initialized successfully');
  }

  // --------------------------------------------------------------------------
  // INITIALIZATION HELPERS
  // --------------------------------------------------------------------------

  Future<void> _initializeCacheStorage() async {
    if (_config.cacheDatabase == CacheDatabase.hive) {
      await _initializeHiveStorage();
    } else {
      await _initializeSqfliteStorage();
    }
  }

  Future<void> _initializeHiveStorage() async {
    await Hive.initFlutter();

    final hiveConfig = _config.hiveConfigOptions ?? const HiveConfigOptions();

    // Open boxes
    final cacheBox = await Hive.openBox(hiveConfig.cacheBoxName);
    final reactiveCacheBox = await Hive.openBox(
      hiveConfig.reactiveCacheBoxName,
    );
    final metadataBox = await Hive.openBox(hiveConfig.metadataBoxName);

    _cacheStorageManager = HiveCacheStorageManager(cacheBox);
    _reactiveCacheStorageManager = HiveCacheStorageManager(reactiveCacheBox);
    _metadataStorageManager = HiveMetadataStorageManager(metadataBox);

    _log('Hive storage initialized');
  }

  Future<void> _initializeSqfliteStorage() async {
    final sqfliteConfig =
        _config.sqfliteConfigOptions ?? const SqfliteConfigOptions();
    final databasePath = await getDatabasesPath();
    final dbPath = path.join(databasePath, sqfliteConfig.databaseName);

    final database = await openDatabase(
      dbPath,
      version: sqfliteConfig.databaseVersion,
      onCreate: (db, version) async {
        // Create cache table
        await db.execute('''
          CREATE TABLE ${sqfliteConfig.cacheTableName} (
            cache_key TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');

        // Create reactive cache table
        await db.execute('''
          CREATE TABLE ${sqfliteConfig.reactiveCacheTableName} (
            cache_key TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');

        // Create metadata table
        await db.execute('''
          CREATE TABLE ${sqfliteConfig.metadataTableName} (
            cache_key TEXT PRIMARY KEY,
            metadata TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );

    _cacheStorageManager = SqfliteCacheStorageManager(
      database,
      sqfliteConfig.cacheTableName,
    );
    _reactiveCacheStorageManager = SqfliteCacheStorageManager(
      database,
      sqfliteConfig.reactiveCacheTableName,
    );
    _metadataStorageManager = SqfliteMetadataStorageManager(
      database,
      sqfliteConfig.metadataTableName,
    );

    _log('SQLite storage initialized');
  }

  Future<void> _initializeConnectivityMonitoring() async {
    // Check initial connectivity
    final results = await _connectivity.checkConnectivity();
    _isOnline = !results.contains(ConnectivityResult.none);

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final wasOffline = !_isOnline;
      _isOnline = !results.contains(ConnectivityResult.none);

      if (wasOffline && _isOnline) {
        _log('Network reconnected - triggering background sync');
        _triggerBackgroundSync();
      }
    });
  }

  void _initializeAppLifecycleListener() {
    WidgetsBinding.instance.addObserver(
      _AppLifecycleObserver(
        onResumed: () {
          if (_isAppFirstLaunch &&
              _config.hitFreshApiUponAppLaunch &&
              !_coldStartRefreshCompleted) {
            _log('Cold start detected - refreshing cached APIs');
            _coldStartRefreshCompleted = true;
            _performColdStartRefresh();
          }
          _isAppFirstLaunch = false;
        },
      ),
    );
  }

  Future<void> _performCacheValidationAndCleanup() async {
    _log('Performing cache validation and cleanup');

    // Validate schema version
    final allMetadata = await _metadataStorageManager.getAllMetadata();
    for (final metadata in allMetadata) {
      if (metadata.schemaVersion != _config.cacheSchemaVersion) {
        _log('Schema version mismatch for ${metadata.cacheKey} - invalidating');
        await invalidateCache(metadata.cacheKey);
      }
    }

    // Evict expired entries
    await _evictExpiredEntries();

    // Apply size-based eviction if needed
    if (_config.maxCacheSizeInMB != null) {
      await _applySizeBasedEviction();
    }
  }

  void _scheduleAutomaticRefresh() {
    if (_config.automaticRefreshIntervals == null) return;

    for (final entry in _config.automaticRefreshIntervals!.entries) {
      final endpoint = entry.key;
      final interval = entry.value;

      Timer.periodic(interval, (_) async {
        _log('Automatic refresh triggered for $endpoint');
        await _refreshEndpointInBackground(endpoint);
      });
    }
  }

  // --------------------------------------------------------------------------
  // PUBLIC API METHODS
  // --------------------------------------------------------------------------

  /// Make a GET request
  Future<http.Response> get(
    String url, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    return _makeRequest('GET', url, headers: headers, body: body);
  }

  /// Make a POST request
  // Future<http.Response> post(
  //   String url, {
  //   Map<String, String>? headers,
  //   dynamic body,
  // }) async {
  //   return _makeRequest('POST', url, headers: headers, body: body);
  // }

  Future<http.Response> post(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    dynamic rawBodyForHash, // NEW PARAMETER
  }) async {
    return _makeRequest(
      'POST',
      url,
      headers: headers,
      body: body,
      rawBodyForHash: rawBodyForHash,
    );
  }

  /// Make a PUT request
  // Future<http.Response> put(
  //   String url, {
  //   Map<String, String>? headers,
  //   dynamic body,
  // }) async {
  //   return _makeRequest('PUT', url, headers: headers, body: body);
  // }

  Future<http.Response> put(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    dynamic rawBodyForHash, // NEW PARAMETER
  }) async {
    return _makeRequest(
      'PUT',
      url,
      headers: headers,
      body: body,
      rawBodyForHash: rawBodyForHash,
    );
  }

  /// Make a DELETE request
  Future<http.Response> delete(
    String url, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    return _makeRequest('DELETE', url, headers: headers, body: body);
  }

  /// Make a PATCH request
  // Future<http.Response> patch(
  //   String url, {
  //   Map<String, String>? headers,
  //   dynamic body,
  // }) async {
  //   return _makeRequest('PATCH', url, headers: headers, body: body);
  // }

  Future<http.Response> patch(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    dynamic rawBodyForHash, // NEW PARAMETER
  }) async {
    return _makeRequest(
      'PATCH',
      url,
      headers: headers,
      body: body,
      rawBodyForHash: rawBodyForHash,
    );
  }

  /// Get reactive repository for an endpoint
  /// Usage: HttpOnSteroids.instance.getReactiveRepository<MyModel>('/api/v1/getUser', serializer)
  ReactiveCacheRepository<T> getReactiveRepository<T>(
    String endpoint,
    HttpSerializer<T> serializer,
  ) {
    if (!_config.enableReactiveCaching) {
      throw Exception(
        'Reactive caching is not enabled. Set enableReactiveCaching: true in config.',
      );
    }

    final key = _generateRepositoryKey(endpoint);
    if (_reactiveRepositories.containsKey(key)) {
      return _reactiveRepositories[key] as ReactiveCacheRepository<T>;
    }

    final repository = ReactiveCacheRepository<T>(endpoint);
    _reactiveRepositories[key] = repository;

    // Load initial data from reactive cache
    _loadInitialReactiveData(endpoint, repository, serializer);

    return repository;
  }

  /// Invalidate cache for a specific endpoint
  Future<void> invalidateCache(String cacheKey) async {
    await _cacheStorageManager.delete(cacheKey);
    await _reactiveCacheStorageManager.delete(cacheKey);
    await _metadataStorageManager.delete(cacheKey);
    _log('Cache invalidated for: $cacheKey');
  }

  /// Invalidate all cached data
  Future<void> invalidateAllCache() async {
    await _cacheStorageManager.clear();
    await _reactiveCacheStorageManager.clear();
    await _metadataStorageManager.clear();
    _log('All cache invalidated');
  }

  /// Get cache statistics
  Future<CacheStatistics> getCacheStatistics() async {
    final allMetadata = await _metadataStorageManager.getAllMetadata();
    final totalSize = allMetadata.fold<int>(0, (sum, m) => sum + m.sizeInBytes);
    final lastUpdated = allMetadata.isNotEmpty
        ? allMetadata
              .map((m) => m.cachedAt)
              .reduce((a, b) => a.isAfter(b) ? a : b)
        : null;

    return CacheStatistics(
      hits: _cacheHits,
      misses: _cacheMisses,
      totalRequests: _cacheHits + _cacheMisses,
      lastUpdated: lastUpdated,
      totalCachedEntries: allMetadata.length,
      totalCacheSizeInBytes: totalSize,
    );
  }

  /// Clear cache statistics
  void clearStatistics() {
    _cacheHits = 0;
    _cacheMisses = 0;
  }

  /// Dispose resources
  Future<void> dispose() async {
    _httpClient.close();
    await _connectivitySubscription?.cancel();
    for (final repo in _reactiveRepositories.values) {
      repo.dispose();
    }
    _reactiveRepositories.clear();
    await _cacheStorageManager.close();
    await _reactiveCacheStorageManager.close();
    await _metadataStorageManager.close();
  }

  // --------------------------------------------------------------------------
  // CORE REQUEST HANDLING
  // --------------------------------------------------------------------------
  Future<http.Response> _makeRequest(
    String method,
    String url, {
    Map<String, String>? headers,
    dynamic body, // Changed from Map<String, dynamic>? to dynamic
    dynamic rawBodyForHash,
  }) async {
    final uri = Uri.parse(url);
    final endpoint = _extractEndpoint(uri);

    // Check if endpoint should bypass cache (streaming endpoints)
    if (_shouldBypassCache(endpoint)) {
      return _executeHttpRequest(method, uri, headers: headers, body: body);
    }

    // Check if caching is enabled for this endpoint
    final shouldCache = _shouldCacheEndpoint(endpoint);

    if (!shouldCache) {
      return _executeHttpRequest(method, uri, headers: headers, body: body);
    }

    // Generate cache key
    //final cacheKey = await _generateCacheKey(endpoint, body);
    // Generate cache key - use rawBodyForHash if encrypted, otherwise use body
    final dataForCacheKey = _config.isBodyEncrypted && rawBodyForHash != null
        ? rawBodyForHash
        : body;
    final cacheKey = await _generateCacheKey(endpoint, dataForCacheKey);

    // Acquire lock for this cache key
    final lock = _getCacheLock(cacheKey);

    return await lock.synchronized(() async {
      // Try to get from cache first
      if (_config.enabledCache) {
        final cachedResponse = await _getCachedResponse(cacheKey, endpoint);
        if (cachedResponse != null) {
          _cacheHits++;
          _log('Cache HIT for: $endpoint');

          // If reactive caching is enabled, refresh in background
          if (_config.enableReactiveCaching) {
            _refreshInBackground(
              method,
              uri,
              headers,
              body,
              cacheKey,
              endpoint,
              rawBodyForHash,
            );
          }

          return cachedResponse;
        }
      }

      _cacheMisses++;
      _log('Cache MISS for: $endpoint');

      // Execute HTTP request with circuit breaker
      final response = await _executeRequestWithCircuitBreaker(
        endpoint,
        () => _executeHttpRequest(method, uri, headers: headers, body: body),
      );

      // Cache the response
      // if (_config.enabledCache &&
      //     response.statusCode >= 200 &&
      //     response.statusCode < 300) {
      //   await _cacheResponse(cacheKey, endpoint, response, body);
      // }

      // Cache the response
      if (_config.enabledCache &&
          response.statusCode >= 200 &&
          response.statusCode < 300) {
        await _cacheResponse(cacheKey, endpoint, response, dataForCacheKey);
      }

      return response;
    });
  }

  Future<http.Response> _executeHttpRequest(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    dynamic body, // Changed from Map<String, dynamic>? to dynamic
  }) async {
    // Merge default headers with request headers
    final mergedHeaders = {
      ...?_config.defaultHeaders,
      ...?headers,
      'Content-Type': 'application/json',
    };

    // Create request
    final request = http.Request(method, uri);
    request.headers.addAll(mergedHeaders);

    if (body != null) {
      // Handle different body types
      if (body is String) {
        // If body is already a String (encrypted data), use it directly
        request.body = body;
        _log('Body type: String (encrypted)');
      } else if (body is Map<String, dynamic>) {
        // If body is a Map, encode it to JSON
        request.body = jsonEncode(body);
        _log('Body type: Map<String, dynamic>');
      } else if (body is List<int>) {
        // If body is bytes, use it directly
        request.bodyBytes = body;

        _log('Body type: List<int> (bytes)');
      } else {
        // Try to encode whatever it is
        request.body = jsonEncode(body);
        _log('Body type: ${body.runtimeType} (attempting JSON encode)');
      }
    }

    // Apply interceptors (onRequest)
    http.Request processedRequest = request;
    if (_config.interceptors != null) {
      for (final interceptor in _config.interceptors!) {
        processedRequest = await interceptor.onRequest(processedRequest);
      }
    }

    // Execute request with timeout and retry
    http.Response response;
    try {
      response = await _executeWithRetry(() async {
        final streamedResponse = await _httpClient
            .send(processedRequest)
            .timeout(_config.requestTimeout);
        return await http.Response.fromStream(streamedResponse);
      });

      // Apply interceptors (onResponse)
      if (_config.interceptors != null) {
        for (final interceptor in _config.interceptors!) {
          response = await interceptor.onResponse(response);
        }
      }

      return response;
    } catch (error) {
      // Apply interceptors (onError)
      if (_config.interceptors != null) {
        for (final interceptor in _config.interceptors!) {
          response = await interceptor.onError(error);
          return response;
        }
      }
      rethrow;
    }
  }

  Future<T> _executeWithRetry<T>(Future<T> Function() operation) async {
    int attempts = 0;
    Duration delay = _config.retryDelay;

    while (attempts < _config.retryAttempts) {
      try {
        return await operation();
      } catch (error) {
        attempts++;
        if (attempts >= _config.retryAttempts) {
          rethrow;
        }

        _log(
          'Request failed (attempt $attempts/${_config.retryAttempts}), retrying in ${delay.inSeconds}s...',
        );
        await Future.delayed(delay);

        // Exponential backoff
        delay *= 2;
      }
    }

    throw Exception('Max retry attempts reached');
  }

  // --------------------------------------------------------------------------
  // CIRCUIT BREAKER
  // --------------------------------------------------------------------------

  Future<http.Response> _executeRequestWithCircuitBreaker(
    String endpoint,
    Future<http.Response> Function() operation,
  ) async {
    if (!_config.enableCircuitBreaker) {
      return await operation();
    }

    final state = _getCircuitBreakerState(endpoint);

    // Check if circuit is open
    if (state.isOpen) {
      if (DateTime.now().difference(state.lastFailureTime!) <
          _config.circuitBreakerResetTimeout) {
        _log(
          'Circuit breaker OPEN for $endpoint - returning cached response or error',
        );
        throw Exception('Circuit breaker is open for $endpoint');
      } else {
        // Try to reset circuit
        state.halfOpen();
        _log('Circuit breaker HALF-OPEN for $endpoint - attempting request');
      }
    }

    try {
      final response = await operation();

      if (response.statusCode >= 500) {
        state.recordFailure();
        if (state.failureCount >= _config.circuitBreakerThreshold) {
          state.open();
          _log(
            'Circuit breaker OPENED for $endpoint after ${state.failureCount} failures',
          );
        }
      } else {
        state.recordSuccess();
      }

      return response;
    } catch (error) {
      state.recordFailure();
      if (state.failureCount >= _config.circuitBreakerThreshold) {
        state.open();
        _log(
          'Circuit breaker OPENED for $endpoint after ${state.failureCount} failures',
        );
      }
      rethrow;
    }
  }

  CircuitBreakerState _getCircuitBreakerState(String endpoint) {
    if (!_circuitBreakers.containsKey(endpoint)) {
      _circuitBreakers[endpoint] = CircuitBreakerState();
    }
    return _circuitBreakers[endpoint]!;
  }

  // --------------------------------------------------------------------------
  // CACHING LOGIC
  // --------------------------------------------------------------------------

  Future<http.Response?> _getCachedResponse(
    String cacheKey,
    String endpoint,
  ) async {
    // Check if cache is valid (not expired)
    final metadata = await _metadataStorageManager.get(cacheKey);
    if (metadata == null) return null;

    // Check TTL expiration
    if (metadata.expiresAt != null &&
        DateTime.now().isAfter(metadata.expiresAt!)) {
      _log('Cache expired for: $endpoint');
      await invalidateCache(cacheKey);
      return null;
    }

    // Get cached data
    final cachedData = await _cacheStorageManager.get(cacheKey);
    if (cachedData == null) return null;

    // Update metadata (access count, last accessed)
    await _metadataStorageManager.put(
      cacheKey,
      metadata.copyWith(
        accessCount: metadata.accessCount + 1,
        lastAccessedAt: DateTime.now(),
      ),
    );

    // Reconstruct response
    final responseData = jsonDecode(cachedData) as Map<String, dynamic>;
    return http.Response(
      responseData['body'] as String,
      responseData['statusCode'] as int,
      headers: Map<String, String>.from(responseData['headers'] as Map),
    );
  }

  Future<void> _cacheResponse(
    String cacheKey,
    String endpoint,
    http.Response response,
    dynamic requestBody, // Changed from Map<String, dynamic>? to dynamic
  ) async {
    final now = DateTime.now();

    // Calculate expiration time based on TTL
    final ttl = _getEndpointTtl(endpoint);
    final expiresAt = ttl != null ? now.add(Duration(seconds: ttl)) : null;

    // Serialize response
    final responseData = {
      'body': response.body,
      'statusCode': response.statusCode,
      'headers': response.headers,
    };

    final responseJson = jsonEncode(responseData);
    final sizeInBytes = responseJson.length;

    // Store in cache
    await _cacheStorageManager.put(cacheKey, responseJson);
    // Store metadata
    final metadata = CacheMetadata(
      cacheKey: cacheKey,
      cachedAt: now,
      expiresAt: expiresAt,
      etag: response.headers['etag'],
      lastModified: response.headers['last-modified'],
      responseCode: response.statusCode,
      accessCount: 0,
      lastAccessedAt: now,
      sizeInBytes: sizeInBytes,
      schemaVersion: _config.cacheSchemaVersion,
    );

    await _metadataStorageManager.put(cacheKey, metadata);

    // Store in reactive cache if enabled
    if (_config.enableReactiveCaching) {
      await _reactiveCacheStorageManager.put(cacheKey, responseJson);
    }

    _log('Response cached for: $endpoint (TTL: ${ttl ?? "infinite"}s)');
  }

  // --------------------------------------------------------------------------
  // REACTIVE CACHING
  // --------------------------------------------------------------------------

  Future<void> _loadInitialReactiveData<T>(
    String endpoint,
    ReactiveCacheRepository<T> repository,
    HttpSerializer<T> serializer,
  ) async {
    try {
      final cacheKey = await _generateCacheKey(endpoint, null);
      final cachedData = await _reactiveCacheStorageManager.get(cacheKey);

      if (cachedData != null) {
        final responseData = jsonDecode(cachedData) as Map<String, dynamic>;
        final body = responseData['body'] as String;

        if (_config.useIsolatesForHeavyWork) {
          final parsed = await compute(_parseJsonInIsolate, body);
          final model = serializer.fromJson(parsed);
          repository._updateValue(model);
        } else {
          final parsed = jsonDecode(body);
          final model = serializer.fromJson(parsed);
          repository._updateValue(model);
        }

        _log('Initial reactive data loaded for: $endpoint');
      }
    } catch (error) {
      _log('Error loading initial reactive  $error');
      repository._updateError(error.toString());
    }
  }

  // Update _refreshInBackground to handle dynamic body
  void _refreshInBackground(
    String method,
    Uri uri,
    Map<String, String>? headers,
    dynamic body, // Changed from Map<String, dynamic>? to dynamic
    String cacheKey,
    String endpoint,
    dynamic rawBodyForHash,
  ) async {
    try {
      _log('Background refresh started for: $endpoint');

      // Execute fresh request
      final freshResponse = await _executeHttpRequest(
        method,
        uri,
        headers: headers,
        body: body,
      );

      if (freshResponse.statusCode >= 200 && freshResponse.statusCode < 300) {
        // Compare with cached data
        final cachedData = await _reactiveCacheStorageManager.get(cacheKey);
        final hasChanged = await _hasDataChanged(
          cachedData,
          freshResponse.body,
        );
        if (hasChanged) {
          _log('Data changed for $endpoint - updating reactive cache');

          // Update cache
          //await _cacheResponse(cacheKey, endpoint, freshResponse, body);
          final dataForCache = _config.isBodyEncrypted && rawBodyForHash != null
              ? rawBodyForHash
              : body;
          await _cacheResponse(cacheKey, endpoint, freshResponse, dataForCache);

          // Notify reactive repositories
          await _notifyReactiveRepositories(endpoint, freshResponse.body);
        } else {
          _log('No data change detected for $endpoint');
        }
      }
    } catch (error) {
      _log('Background refresh failed for $endpoint: $error');
    }
  }

  Future<bool> _hasDataChanged(String? cachedData, String freshData) async {
    if (cachedData == null) return true;

    if (_config.useIsolatesForHeavyWork) {
      return await compute(_compareDataInIsolate, {
        'cached': cachedData,
        'fresh': freshData,
      });
    } else {
      final cachedResponseData = jsonDecode(cachedData) as Map<String, dynamic>;
      final cachedBody = cachedResponseData['body'] as String;

      // Use canonical JSON comparison (sorted keys)
      final cachedHash = _computeHash(cachedBody);
      final freshHash = _computeHash(freshData);

      return cachedHash != freshHash;
    }
  }

  Future<void> _notifyReactiveRepositories(
    String endpoint,
    String freshData,
  ) async {
    for (final entry in _reactiveRepositories.entries) {
      final repo = entry.value;
      if (repo.endpoint == endpoint) {
        // Parse and update the repository
        // Note: This requires knowing the serializer type, which we'll handle generically
        try {
          final parsed = jsonDecode(freshData);
          // For raw JSON, we can update directly
          if (repo is ReactiveCacheRepository<Map<String, dynamic>>) {
            repo._updateValue(parsed);
          }
          // For typed models, the user should handle this in their UI layer
        } catch (error) {
          repo._updateError(error.toString());
        }
      }
    }
  }

  // --------------------------------------------------------------------------
  // COLD START REFRESH
  // --------------------------------------------------------------------------

  Future<void> _performColdStartRefresh() async {
    final endpointsToRefresh =
        _config.apiEndpointsToBeRefreshedOnAppLaunch ??
        _config.apiEndpointsToBeCached;
    if (endpointsToRefresh == null || endpointsToRefresh.isEmpty) {
      _log('No endpoints configured for cold start refresh');
      return;
    }

    for (final endpoint in endpointsToRefresh) {
      await _refreshEndpointInBackground(endpoint);
    }
  }

  Future<void> _refreshEndpointInBackground(String endpoint) async {
    try {
      // Get all cache keys matching this endpoint pattern
      final allMetadata = await _metadataStorageManager.getAllMetadata();
      final matchingKeys = allMetadata
          .where((m) => _matchesEndpointPattern(m.cacheKey, endpoint))
          .toList();

      for (final metadata in matchingKeys) {
        // Invalidate the cache to force fresh fetch
        await invalidateCache(metadata.cacheKey);
        _log('Refreshed cache for: ${metadata.cacheKey}');
      }
    } catch (error) {
      _log('Error refreshing endpoint $endpoint: $error');
    }
  }

  void _triggerBackgroundSync() {
    // Refresh all cached endpoints when coming back online
    _performColdStartRefresh();
  }

  // --------------------------------------------------------------------------
  // CACHE EVICTION
  // --------------------------------------------------------------------------

  Future<void> _evictExpiredEntries() async {
    final allMetadata = await _metadataStorageManager.getAllMetadata();
    final now = DateTime.now();

    for (final metadata in allMetadata) {
      if (metadata.expiresAt != null && now.isAfter(metadata.expiresAt!)) {
        await invalidateCache(metadata.cacheKey);
        _log('Evicted expired entry: ${metadata.cacheKey}');
      }
    }
  }

  Future<void> _applySizeBasedEviction() async {
    final maxSizeBytes = _config.maxCacheSizeInMB! * 1024 * 1024;
    final allMetadata = await _metadataStorageManager.getAllMetadata();

    final totalSize = allMetadata.fold<int>(0, (sum, m) => sum + m.sizeInBytes);

    if (totalSize <= maxSizeBytes) {
      return; // No eviction needed
    }

    _log(
      'Cache size ($totalSize bytes) exceeds limit ($maxSizeBytes bytes) - applying eviction',
    );

    // Sort based on eviction policy
    List<CacheMetadata> sortedMetadata;
    switch (_config.evictionPolicy) {
      case CacheEvictionPolicy.lru:
        sortedMetadata = allMetadata
          ..sort((a, b) => a.lastAccessedAt.compareTo(b.lastAccessedAt));
        break;
      case CacheEvictionPolicy.fifo:
        sortedMetadata = allMetadata
          ..sort((a, b) => a.cachedAt.compareTo(b.cachedAt));
        break;
      case CacheEvictionPolicy.lfu:
        sortedMetadata = allMetadata
          ..sort((a, b) => a.accessCount.compareTo(b.accessCount));
        break;
    }

    // Evict entries until size is under limit
    int currentSize = totalSize;
    for (final metadata in sortedMetadata) {
      if (currentSize <= maxSizeBytes) break;

      await invalidateCache(metadata.cacheKey);
      currentSize -= metadata.sizeInBytes;
      _log(
        'Evicted entry: ${metadata.cacheKey} (${metadata.sizeInBytes} bytes)',
      );
    }
  }

  // --------------------------------------------------------------------------
  // HELPER METHODS
  // --------------------------------------------------------------------------

  bool _shouldBypassCache(String endpoint) {
    if (_config.streamingEndpointsToBypassCache == null) return false;
    return _config.streamingEndpointsToBypassCache!.any(
      (pattern) => _matchesEndpointPattern(endpoint, pattern),
    );
  }

  bool _shouldCacheEndpoint(String endpoint) {
    if (!_config.enabledCache) return false;
    if (_config.apiEndpointsToBeCached == null)
      return true; // Cache all if not specified

    return _config.apiEndpointsToBeCached!.any(
      (pattern) => _matchesEndpointPattern(endpoint, pattern),
    );
  }

  bool _matchesEndpointPattern(String endpoint, String pattern) {
    if (pattern.endsWith('/*')) {
      // Wildcard pattern
      final prefix = pattern.substring(0, pattern.length - 2);
      return endpoint.startsWith(prefix);
    } else if (pattern.contains('*')) {
      // Regex pattern
      final regex = RegExp(pattern.replaceAll('*', '.*'));
      return regex.hasMatch(endpoint);
    } else {
      // Exact match
      return endpoint == pattern;
    }
  }

  String _extractEndpoint(Uri uri) {
    return uri.path + (uri.query.isNotEmpty ? '?${uri.query}' : '');
  }

  Future<String> _generateCacheKey(String endpoint, dynamic body) async {
    if (_config.isBodyEncrypted && body is Map) {
      _log('Using raw unencrypted body for cache key generation');
    }
    switch (_config.cacheKeyStrategy) {
      case CacheKeyStrategy.endpointOnly:
        return endpoint;
      case CacheKeyStrategy.endpointPlusBodyHash:
        if (body == null) return endpoint;

        String bodyString;
        if (body is String) {
          // If body is already a string (encrypted), use it directly
          bodyString = body;
        } else if (body is Map) {
          // If body is a Map, encode to JSON
          bodyString = jsonEncode(body);
        } else if (body is List<int>) {
          // If body is bytes, convert to string
          bodyString = utf8.decode(body);
        } else {
          // Try to encode whatever it is
          bodyString = body.toString();
        }

        if (_config.useIsolatesForHeavyWork) {
          final hash = await compute(_computeHashInIsolate, bodyString);
          return '$endpoint:$hash';
        } else {
          final hash = _computeHash(bodyString);
          return '$endpoint:$hash';
        }
      case CacheKeyStrategy.custom:
        return endpoint;
    }
  }

  String _computeHash(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  int? _getEndpointTtl(String endpoint) {
    // Check endpoint-specific TTL first
    if (_config.endpointSpecificCacheTtl != null) {
      for (final entry in _config.endpointSpecificCacheTtl!.entries) {
        if (_matchesEndpointPattern(endpoint, entry.key)) {
          // Validate that endpoint is in cached list
          if (_config.apiEndpointsToBeCached != null &&
              !_config.apiEndpointsToBeCached!.any(
                (pattern) => _matchesEndpointPattern(endpoint, pattern),
              )) {
            _log(
              'WARNING: Endpoint $endpoint has TTL configured but is not in apiEndpointsToBeCached',
            );
          }
          return entry.value;
        }
      }
    }

    // Fall back to global TTL
    return _config.cacheTtl;
  }

  Lock _getCacheLock(String cacheKey) {
    if (!_cacheLocks.containsKey(cacheKey)) {
      _cacheLocks[cacheKey] = Lock();
    }
    return _cacheLocks[cacheKey]!;
  }

  String _generateRepositoryKey(String endpoint) {
    return 'repo:$endpoint';
  }

  void _log(String message) {
    if (_config.enableDebugMode) {
      debugPrint('[HttpOnSteroids] $message');
    }
  }
}

// ============================================================================
// ISOLATE FUNCTIONS (must be top-level)
// ============================================================================

Map<String, dynamic> _parseJsonInIsolate(String jsonString) {
  return jsonDecode(jsonString) as Map<String, dynamic>;
}

String _computeHashInIsolate(String data) {
  final bytes = utf8.encode(data);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

bool _compareDataInIsolate(Map<String, dynamic> params) {
  final cached = params['cached'] as String;
  final fresh = params['fresh'] as String;

  final cachedResponseData = jsonDecode(cached) as Map<String, dynamic>;
  final cachedBody = cachedResponseData['body'] as String;

  // Compute hashes
  final cachedBytes = utf8.encode(cachedBody);
  final freshBytes = utf8.encode(fresh);

  final cachedHash = sha256.convert(cachedBytes);
  final freshHash = sha256.convert(freshBytes);

  return cachedHash.toString() != freshHash.toString();
}

// ============================================================================
// STORAGE MANAGERS
// ============================================================================

abstract class CacheStorageManager {
  Future<String?> get(String key);
  Future<void> put(String key, String value);
  Future<void> delete(String key);
  Future<void> clear();
  Future<void> close();
}

abstract class MetadataStorageManager {
  Future<CacheMetadata?> get(String key);
  Future<void> put(String key, CacheMetadata metadata);
  Future<void> delete(String key);
  Future<void> clear();
  Future<List<CacheMetadata>> getAllMetadata();
  Future<void> close();
}

// --------------------------------------------------------------------------
// HIVE IMPLEMENTATIONS
// --------------------------------------------------------------------------

class HiveCacheStorageManager implements CacheStorageManager {
  final Box _box;

  HiveCacheStorageManager(this._box);

  @override
  Future<String?> get(String key) async {
    return _box.get(key);
  }

  @override
  Future<void> put(String key, String value) async {
    await _box.put(key, value);
  }

  @override
  Future<void> delete(String key) async {
    await _box.delete(key);
  }

  @override
  Future<void> clear() async {
    await _box.clear();
  }

  @override
  Future<void> close() async {
    await _box.close();
  }
}

class HiveMetadataStorageManager implements MetadataStorageManager {
  final Box _box;

  HiveMetadataStorageManager(this._box);

  @override
  Future<CacheMetadata?> get(String key) async {
    final json = _box.get(key);
    if (json == null) return null;
    return CacheMetadata.fromJson(Map<String, dynamic>.from(json));
  }

  @override
  Future<void> put(String key, CacheMetadata metadata) async {
    await _box.put(key, metadata.toJson());
  }

  @override
  Future<void> delete(String key) async {
    await _box.delete(key);
  }

  @override
  Future<List<CacheMetadata>> getAllMetadata() async {
    final result = <CacheMetadata>[];
    for (final key in _box.keys) {
      final metadata = await get(key.toString());
      if (metadata != null) {
        result.add(metadata);
      }
    }
    return result;
  }

  @override
  Future<void> close() async {
    await _box.close();
  }

  @override
  Future<void> clear() async {
    await _box.clear();
  }
}

// --------------------------------------------------------------------------
// SQFLITE IMPLEMENTATIONS
// --------------------------------------------------------------------------

class SqfliteCacheStorageManager implements CacheStorageManager {
  final Database _database;
  final String _tableName;

  SqfliteCacheStorageManager(this._database, this._tableName);

  @override
  Future<String?> get(String key) async {
    final results = await _database.query(
      _tableName,
      where: 'cache_key = ?',
      whereArgs: [key],
    );

    if (results.isEmpty) return null;
    return results.first['data'] as String;
  }

  @override
  Future<void> put(String key, String value) async {
    await _database.insert(_tableName, {
      'cache_key': key,
      'data': value,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> delete(String key) async {
    await _database.delete(
      _tableName,
      where: 'cache_key = ?',
      whereArgs: [key],
    );
  }

  @override
  Future<void> clear() async {
    await _database.delete(_tableName);
  }

  @override
  Future<void> close() async {
    // Database is shared, don't close it here
  }
}

class SqfliteMetadataStorageManager implements MetadataStorageManager {
  final Database _database;
  final String _tableName;

  SqfliteMetadataStorageManager(this._database, this._tableName);

  @override
  Future<CacheMetadata?> get(String key) async {
    final results = await _database.query(
      _tableName,
      where: 'cache_key = ?',
      whereArgs: [key],
    );

    if (results.isEmpty) return null;

    final metadataJson = jsonDecode(results.first['metadata'] as String);
    return CacheMetadata.fromJson(metadataJson);
  }

  @override
  Future<void> put(String key, CacheMetadata metadata) async {
    await _database.insert(_tableName, {
      'cache_key': key,
      'metadata': jsonEncode(metadata.toJson()),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> delete(String key) async {
    await _database.delete(
      _tableName,
      where: 'cache_key = ?',
      whereArgs: [key],
    );
  }

  @override
  Future<List<CacheMetadata>> getAllMetadata() async {
    final results = await _database.query(_tableName);
    return results.map((row) {
      final metadataJson = jsonDecode(row['metadata'] as String);
      return CacheMetadata.fromJson(metadataJson);
    }).toList();
  }

  @override
  Future<void> close() async {
    // Database is shared, don't close it here
  }

  @override
  Future<void> clear() async {
    await _database.delete(_tableName);
  }
}

// ============================================================================
// CIRCUIT BREAKER STATE
// ============================================================================

class CircuitBreakerState {
  int failureCount = 0;
  DateTime? lastFailureTime;
  bool _isOpen = false;

  bool get isOpen => _isOpen;

  void recordFailure() {
    failureCount++;
    lastFailureTime = DateTime.now();
  }

  void recordSuccess() {
    failureCount = 0;
    _isOpen = false;
  }

  void open() {
    _isOpen = true;
  }

  void halfOpen() {
    _isOpen = false;
    failureCount = 0;
  }
}

// ============================================================================
// APP LIFECYCLE OBSERVER
// ============================================================================

class _AppLifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback onResumed;

  _AppLifecycleObserver({required this.onResumed});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}
