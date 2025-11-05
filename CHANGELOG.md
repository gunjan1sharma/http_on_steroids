# Changelog

All notable changes to this project will be documented in this file.

---

## [0.0.8] - 2025-11-05

### 🎉 Initial Stable Release

- Introduced **HttpOnSteroids** – a high-performance wrapper around Flutter’s HTTP client.
- Added **reactive caching layer** supporting both Hive and Sqflite.
- Built-in **endpoint-specific TTLs** and **cache eviction policies (LRU, FIFO)**.
- Added **automatic refresh intervals**, **retry mechanism**, and **circuit breaker pattern**.
- Included **custom interceptor system** for request, response, and error handling.
- Provided **detailed cache statistics** API with hit/miss tracking.
- Supports both **typed models** and **raw JSON** caching.
- Enabled **debug mode** for better observability during development.
- Added **configuration class** `HttpOnSteroidsConfig` for granular control of caching and behavior.
- Introduced **ReactiveCacheRepository** for real-time UI updates from cached or live data.

---

## [0.0.2] - 2025-11-10

### 🛠 Improvements

- Enhanced cache invalidation performance.
- Improved error handling in interceptors.
- Added better logging and debug output formatting.

---

## [0.0.5] - 2025-11-15

### ⚙️ Maintenance

- Code cleanup and documentation polish.
- Minor dependency upgrades.
- README improved with full examples and structured explanation.

---

## Author

**Gunjan Sharma**  
Tech Lead @ Alt DRX

> Built this library after hitting the limits of traditional HTTP packages — to supercharge app networking and caching in real-world Flutter apps.  
> Open to PRs, community contributions, and change requests.
