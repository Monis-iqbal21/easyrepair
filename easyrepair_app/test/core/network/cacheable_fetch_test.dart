import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/data/cache_policy.dart';
import 'package:handygo_app/core/network/cacheable_fetch.dart';
import 'package:handygo_app/core/storage/local_cache_service.dart';
import 'package:handygo_app/core/storage/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSecureStorage extends SecureStorageService {
  _FakeSecureStorage(this._userId) : super(const FlutterSecureStorage());
  final String? _userId;

  @override
  Future<String?> getCurrentUserId() async => _userId;
}

Future<LocalCacheService> _cache() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return LocalCacheService(prefs);
}

DioException _connectionError() => DioException(
      requestOptions: RequestOptions(path: '/bookings/my'),
      type: DioExceptionType.connectionError,
    );

void main() {
  group('fetchWithCache', () {
    test('a successful fetch writes the raw response to cache and returns '
        'fresh (non-stale) data', () async {
      final cache = await _cache();
      final storage = _FakeSecureStorage('u1');

      final result = await fetchWithCache<List<int>>(
        cache: cache,
        secureStorage: storage,
        cacheKey: 'nums',
        request: () async => [1, 2, 3],
        decode: (json) => (json as List<dynamic>).cast<int>(),
      );

      expect(result.isStale, isFalse);
      expect(result.data, [1, 2, 3]);
      expect(cache.read('u1', 'nums')!.data, [1, 2, 3]);
    });

    test('a network failure with something cached falls back to it, marked '
        'stale', () async {
      final cache = await _cache();
      final storage = _FakeSecureStorage('u1');
      await cache.write('u1', 'nums', [9, 9]);

      final result = await fetchWithCache<List<int>>(
        cache: cache,
        secureStorage: storage,
        cacheKey: 'nums',
        request: () async => throw _connectionError(),
        decode: (json) => (json as List<dynamic>).cast<int>(),
      );

      expect(result.isStale, isTrue);
      expect(result.data, [9, 9]);
    });

    test('a 500 with something cached also falls back to it', () async {
      final cache = await _cache();
      final storage = _FakeSecureStorage('u1');
      await cache.write('u1', 'nums', [5]);

      final serverError = DioException(
        requestOptions: RequestOptions(path: '/bookings/my'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/bookings/my'),
          statusCode: 500,
        ),
      );

      final result = await fetchWithCache<List<int>>(
        cache: cache,
        secureStorage: storage,
        cacheKey: 'nums',
        request: () async => throw serverError,
        decode: (json) => (json as List<dynamic>).cast<int>(),
      );

      expect(result.isStale, isTrue);
      expect(result.data, [5]);
    });

    test('a network failure with nothing cached rethrows a friendly, mapped '
        'Failure — never the raw DioException', () async {
      final cache = await _cache();
      final storage = _FakeSecureStorage('u1');

      await expectLater(
        fetchWithCache<List<int>>(
          cache: cache,
          secureStorage: storage,
          cacheKey: 'nums',
          request: () async => throw _connectionError(),
          decode: (json) => (json as List<dynamic>).cast<int>(),
        ),
        throwsA(
          isA<NetworkFailure>().having(
            (f) => f.code,
            'code',
            FailureCode.noInternet,
          ),
        ),
      );
    });

    test('a fresh successful response replaces stale cached data', () async {
      final cache = await _cache();
      final storage = _FakeSecureStorage('u1');
      await cache.write('u1', 'nums', [1]);

      final result = await fetchWithCache<List<int>>(
        cache: cache,
        secureStorage: storage,
        cacheKey: 'nums',
        request: () async => [2, 3],
        decode: (json) => (json as List<dynamic>).cast<int>(),
      );

      expect(result.isStale, isFalse);
      expect(result.data, [2, 3]);
      expect(cache.read('u1', 'nums')!.data, [2, 3]);
    });

    test('cache is scoped per account — a different user never reads the '
        'previous account\'s cached entry', () async {
      final cache = await _cache();
      await cache.write('u1', 'nums', [1, 1, 1]);
      final storageForU2 = _FakeSecureStorage('u2');

      // u2 is offline and has never fetched 'nums' — must NOT see u1's data.
      await expectLater(
        fetchWithCache<List<int>>(
          cache: cache,
          secureStorage: storageForU2,
          cacheKey: 'nums',
          request: () async => throw _connectionError(),
          decode: (json) => (json as List<dynamic>).cast<int>(),
        ),
        throwsA(anything),
      );
    });

    test('no signed-in account (no token) never reads or writes cache',
        () async {
      final cache = await _cache();
      final storage = _FakeSecureStorage(null);

      final result = await fetchWithCache<List<int>>(
        cache: cache,
        secureStorage: storage,
        cacheKey: 'nums',
        request: () async => [7],
        decode: (json) => (json as List<dynamic>).cast<int>(),
      );

      expect(result.data, [7]);
      // Nothing was persisted under any key for a null account.
      expect(cache.read('u1', 'nums'), isNull);
    });

    // ── maxAge (New Jobs 24h discovery-cache TTL) ─────────────────────────
    group('cache policy (was: maxAge)', () {
      Future<SharedPreferences> writeAgedEntry(
        String userId,
        String key,
        Object? data,
        DateTime savedAt,
      ) async {
        final prefs = await SharedPreferences.getInstance();
        final envelope = jsonEncode({
          'savedAt': savedAt.toIso8601String(),
          'data': data,
        });
        await prefs.setString('hg_cache_v1:$userId:$key', envelope);
        return prefs;
      }

      test('omitted (default) — a cache many days old is still served, '
          'exactly as before this option existed', () async {
        SharedPreferences.setMockInitialValues({});
        await writeAgedEntry(
          'u1',
          'nums',
          [1, 1],
          DateTime.now().subtract(const Duration(days: 30)),
        );
        final prefs = await SharedPreferences.getInstance();
        final cache = LocalCacheService(prefs);
        final storage = _FakeSecureStorage('u1');

        final result = await fetchWithCache<List<int>>(
          cache: cache,
          secureStorage: storage,
          cacheKey: 'nums',
          request: () async => throw _connectionError(),
          decode: (json) => (json as List<dynamic>).cast<int>(),
        );

        expect(result.isStale, isTrue);
        expect(result.data, [1, 1]);
      });

      test('a cache just inside maxAge is still served, marked stale',
          () async {
        SharedPreferences.setMockInitialValues({});
        await writeAgedEntry(
          'u1',
          'new_jobs',
          [1],
          DateTime.now().subtract(const Duration(hours: 23)),
        );
        final prefs = await SharedPreferences.getInstance();
        final cache = LocalCacheService(prefs);
        final storage = _FakeSecureStorage('u1');

        final result = await fetchWithCache<List<int>>(
          cache: cache,
          secureStorage: storage,
          cacheKey: 'new_jobs',
          policy: CachePolicy.newJobs,
          request: () async => throw _connectionError(),
          decode: (json) => (json as List<dynamic>).cast<int>(),
        );

        expect(result.isStale, isTrue);
        expect(result.data, [1]);
      });

      test('a cache older than maxAge is NOT served — the live failure is '
          'rethrown instead of implying stale data is still usable',
          () async {
        SharedPreferences.setMockInitialValues({});
        await writeAgedEntry(
          'u1',
          'new_jobs',
          [1],
          DateTime.now().subtract(const Duration(hours: 25)),
        );
        final prefs = await SharedPreferences.getInstance();
        final cache = LocalCacheService(prefs);
        final storage = _FakeSecureStorage('u1');

        await expectLater(
          fetchWithCache<List<int>>(
            cache: cache,
            secureStorage: storage,
            cacheKey: 'new_jobs',
            policy: CachePolicy.newJobs,
            request: () async => throw _connectionError(),
            decode: (json) => (json as List<dynamic>).cast<int>(),
          ),
          throwsA(isA<NetworkFailure>()),
        );
      });

      test('a live success always refreshes regardless of maxAge', () async {
        SharedPreferences.setMockInitialValues({});
        await writeAgedEntry(
          'u1',
          'new_jobs',
          [1],
          DateTime.now().subtract(const Duration(hours: 25)),
        );
        final prefs = await SharedPreferences.getInstance();
        final cache = LocalCacheService(prefs);
        final storage = _FakeSecureStorage('u1');

        final result = await fetchWithCache<List<int>>(
          cache: cache,
          secureStorage: storage,
          cacheKey: 'new_jobs',
          policy: CachePolicy.newJobs,
          request: () async => [9, 9],
          decode: (json) => (json as List<dynamic>).cast<int>(),
        );

        expect(result.isStale, isFalse);
        expect(result.data, [9, 9]);
      });
    });
  });
}
