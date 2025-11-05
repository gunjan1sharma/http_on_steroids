import 'package:flutter_test/flutter_test.dart';
import 'package:http_on_steroids/http_on_steroids.dart';

void main() {
  group('HttpOnSteroids basic setup', () {
    test('should initialize with default config without throwing', () async {
      await HttpOnSteroids.initialize(
        HttpOnSteroidsConfig(enabledCache: false, enableDebugMode: true),
      );

      final instance = HttpOnSteroids.instance;
      expect(instance, isNotNull);
    });

    test('should accept valid configuration', () async {
      final config = HttpOnSteroidsConfig(
        enabledCache: true,
        cacheTtl: 120,
        enableDebugMode: true,
      );

      expect(config.enabledCache, true);
      expect(config.cacheTtl, 120);
      expect(config.enableDebugMode, true);
    });

    test('should expose cache management methods', () async {
      final client = HttpOnSteroids.instance;

      // These should not throw (even if internally mocked or disabled)
      await client.invalidateAllCache();
      await client.getCacheStatistics();
    });

    test('should handle reactive repository creation safely', () {
      final client = HttpOnSteroids.instance;
      final repo = client.getReactiveRepository<Map<String, dynamic>>(
        '/test',
        RawJsonSerializer(),
      );
      expect(repo, isNotNull);
    });
  });
}
