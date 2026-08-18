import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/data/cache_policy.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/network/cacheable_fetch.dart';
import 'package:handygo_app/core/storage/local_cache_service.dart';
import 'package:handygo_app/core/storage/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// THE security-critical property of the offline cache.
///
/// Offline fallback exists for "we could not get an answer". It must never be
/// used for "we got an answer we did not like": a 401 means the session is
/// gone, a 403 means this account is suspended or restricted, a 400 means the
/// request itself was rejected. Serving cached protected data behind any of
/// those would make a logged-out or suspended account look authorized, which
/// is exactly the failure mode the auth/account-status work exists to prevent.
class _FakeSecureStorage extends SecureStorageService {
  _FakeSecureStorage(this._userId) : super(const FlutterSecureStorage());
  final String? _userId;

  @override
  Future<String?> getCurrentUserId() async => _userId;
}

Future<LocalCacheService> _cacheWith(
  String userId,
  String key,
  Object? data,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final cache = LocalCacheService(prefs);
  await cache.write(userId, key, data);
  return cache;
}

DioException _status(int code) => DioException(
      requestOptions: RequestOptions(path: '/bookings/my'),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: RequestOptions(path: '/bookings/my'),
        statusCode: code,
      ),
    );

DioException _network(DioExceptionType type) => DioException(
      requestOptions: RequestOptions(path: '/bookings/my'),
      type: type,
    );

Future<Object?> _failureFrom(Future<Object?> Function() run) async {
  try {
    await run();
    return null;
  } catch (e) {
    return e;
  }
}

void main() {
  group('an ANSWERED request is never masked by cache', () {
    // Every one of these is the server stating something definitive about
    // this request. The cached list must stay hidden and the failure must
    // reach the caller so auth/error handling can act on it.
    final answered = <String, int>{
      '401 — session gone, the auth flow stays authoritative': 401,
      '403 — suspended/restricted account must not look authorized': 403,
      '400 — a real validation answer, not an outage': 400,
      '404 — the resource is genuinely gone': 404,
      '409 — the resource moved on': 409,
    };

    answered.forEach((description, status) {
      test(description, () async {
        final cache = await _cacheWith('u1', 'nums', [1, 2, 3]);

        final error = await _failureFrom(() => fetchWithCache<List<int>>(
              cache: cache,
              secureStorage: _FakeSecureStorage('u1'),
              cacheKey: 'nums',
              request: () async => throw _status(status),
              decode: (json) => (json as List<dynamic>).cast<int>(),
            ));

        expect(error, isA<Failure>(),
            reason: 'the mapped failure must surface, not cached data');
        expect(
          (error as Failure).code,
          isNot(FailureCode.noInternet),
          reason: 'an answered request is not an offline condition',
        );
        // The entry is still there — it just was not allowed to be served.
        expect(cache.read('u1', 'nums'), isNotNull);
      });
    });

    test('a 403 does not even reach the cache — no read is attempted',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cache = LocalCacheService(prefs);
      await cache.write('u1', 'nums', [7]);

      final error = await _failureFrom(() => fetchWithCache<List<int>>(
            cache: cache,
            secureStorage: _FakeSecureStorage('u1'),
            cacheKey: 'nums',
            request: () async => throw _status(403),
            decode: (json) => (json as List<dynamic>).cast<int>(),
          ));

      expect((error! as Failure).code, FailureCode.forbidden);
    });
  });

  group('an UNANSWERED request may fall back to cache', () {
    final unanswered = <String, DioException>{
      'no connectivity / socket error': _network(DioExceptionType.connectionError),
      'connection timeout': _network(DioExceptionType.connectionTimeout),
      'receive timeout': _network(DioExceptionType.receiveTimeout),
      // The server is reachable but cannot answer — it is broken or shedding
      // load. Neither says anything about this account's authorization.
      '500 — server is broken': _status(500),
      '503 — server unavailable': _status(503),
      '429 — rate limited': _status(429),
    };

    unanswered.forEach((description, exception) {
      test('$description serves the cached value, marked stale', () async {
        final cache = await _cacheWith('u1', 'nums', [1, 2, 3]);

        final result = await fetchWithCache<List<int>>(
          cache: cache,
          secureStorage: _FakeSecureStorage('u1'),
          cacheKey: 'nums',
          request: () async => throw exception,
          decode: (json) => (json as List<dynamic>).cast<int>(),
        );

        expect(result.isStale, isTrue);
        expect(result.data, [1, 2, 3]);
      });
    });
  });

  group('malformed / incompatible cached payloads', () {
    test('a cached shape the current model can no longer decode is discarded, '
        'the live failure surfaces, and the app does not crash', () async {
      // Simulates an app update that changed this endpoint's model: the
      // stored payload is valid JSON but the wrong shape.
      final cache = await _cacheWith('u1', 'nums', {'unexpected': 'shape'});

      final error = await _failureFrom(() => fetchWithCache<List<int>>(
            cache: cache,
            secureStorage: _FakeSecureStorage('u1'),
            cacheKey: 'nums',
            request: () async =>
                throw _network(DioExceptionType.connectionError),
            decode: (json) => (json as List<dynamic>).cast<int>(),
          ));

      expect(error, isA<NetworkFailure>());
      // Evicted, so the poisoned entry can never be retried.
      await Future<void>.delayed(Duration.zero);
      expect(cache.read('u1', 'nums'), isNull);
    });

    test('evicting a poisoned entry leaves the rest of the account cache '
        'untouched', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cache = LocalCacheService(prefs);
      await cache.write('u1', 'bad', {'unexpected': 'shape'});
      await cache.write('u1', 'good', [1]);

      await _failureFrom(() => fetchWithCache<List<int>>(
            cache: cache,
            secureStorage: _FakeSecureStorage('u1'),
            cacheKey: 'bad',
            request: () async =>
                throw _network(DioExceptionType.connectionError),
            decode: (json) => (json as List<dynamic>).cast<int>(),
          ));
      await Future<void>.delayed(Duration.zero);

      expect(cache.read('u1', 'bad'), isNull);
      expect(cache.read('u1', 'good')!.data, [1]);
    });

    test('a corrupt stored envelope reads as a cache miss, never a throw',
        () async {
      SharedPreferences.setMockInitialValues({
        'hg_cache_v1:u1:nums': 'not json at all',
      });
      final prefs = await SharedPreferences.getInstance();
      final cache = LocalCacheService(prefs);

      expect(cache.read('u1', 'nums'), isNull);
    });

    test('an entry written under a different envelope schema version is '
        'ignored instead of crashing a future app build', () async {
      SharedPreferences.setMockInitialValues({
        'hg_cache_v1:u1:nums': jsonEncode({
          'v': LocalCacheService.schemaVersion + 1,
          'savedAt': DateTime.now().toIso8601String(),
          'data': [1, 2],
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final cache = LocalCacheService(prefs);

      expect(cache.read('u1', 'nums'), isNull);
    });

    test('entries written before versioning existed remain readable', () async {
      // Nobody should lose their offline history to this upgrade.
      SharedPreferences.setMockInitialValues({
        'hg_cache_v1:u1:nums': jsonEncode({
          'savedAt': DateTime.now().toIso8601String(),
          'data': [4, 5],
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final cache = LocalCacheService(prefs);

      expect(cache.read('u1', 'nums')!.data, [4, 5]);
    });
  });

  group('cache keys isolate accounts and queries', () {
    test('user A can never be served user B\'s cached entry', () async {
      final cache = await _cacheWith('userA', 'client_bookings', ['A-booking']);

      final error = await _failureFrom(() => fetchWithCache<List<String>>(
            cache: cache,
            secureStorage: _FakeSecureStorage('userB'),
            cacheKey: 'client_bookings',
            request: () async =>
                throw _network(DioExceptionType.connectionError),
            decode: (json) => (json as List<dynamic>).cast<String>(),
          ));

      // No fallback at all for B — not B seeing A's bookings.
      expect(error, isA<NetworkFailure>());
    });

    test('a cached filter cannot satisfy a different filter', () async {
      // My Jobs caches per filter (worker_jobs:<filter>) precisely so the
      // Completed tab can never render the Active tab's rows.
      final cache =
          await _cacheWith('u1', 'worker_jobs:active', ['active-job']);

      final active = await fetchWithCache<List<String>>(
        cache: cache,
        secureStorage: _FakeSecureStorage('u1'),
        cacheKey: 'worker_jobs:active',
        request: () async => throw _network(DioExceptionType.connectionError),
        decode: (json) => (json as List<dynamic>).cast<String>(),
      );
      expect(active.data, ['active-job']);

      final completed = await _failureFrom(() => fetchWithCache<List<String>>(
            cache: cache,
            secureStorage: _FakeSecureStorage('u1'),
            cacheKey: 'worker_jobs:completed',
            request: () async =>
                throw _network(DioExceptionType.connectionError),
            decode: (json) => (json as List<dynamic>).cast<String>(),
          ));
      expect(completed, isA<NetworkFailure>());
    });

    test('a per-id detail cache cannot satisfy a different id', () async {
      final cache =
          await _cacheWith('u1', 'booking_detail:b1', {'id': 'b1'});

      final other = await _failureFrom(() => fetchWithCache<Map<String, dynamic>>(
            cache: cache,
            secureStorage: _FakeSecureStorage('u1'),
            cacheKey: 'booking_detail:b2',
            request: () async =>
                throw _network(DioExceptionType.connectionError),
            decode: (json) => json as Map<String, dynamic>,
          ));
      expect(other, isA<NetworkFailure>());
    });
  });

  group('policy is honoured end to end', () {
    test('liveDiscovery refuses to serve cache even seconds after writing it',
        () async {
      final cache = await _cacheWith('u1', 'nearby', ['worker-1']);

      final error = await _failureFrom(() => fetchWithCache<List<String>>(
            cache: cache,
            secureStorage: _FakeSecureStorage('u1'),
            cacheKey: 'nearby',
            policy: CachePolicy.liveDiscovery,
            request: () async =>
                throw _network(DioExceptionType.connectionError),
            decode: (json) => (json as List<dynamic>).cast<String>(),
          ));

      expect(error, isA<NetworkFailure>(),
          reason: 'cached live availability must never look current');
    });

    test('a live success still refreshes the cache under every policy',
        () async {
      final cache = await _cacheWith('u1', 'new_jobs', ['old']);

      final result = await fetchWithCache<List<String>>(
        cache: cache,
        secureStorage: _FakeSecureStorage('u1'),
        cacheKey: 'new_jobs',
        policy: CachePolicy.newJobs,
        request: () async => ['fresh'],
        decode: (json) => (json as List<dynamic>).cast<String>(),
      );

      expect(result.isStale, isFalse);
      expect(result.data, ['fresh']);
      expect(cache.read('u1', 'new_jobs')!.data, ['fresh'],
          reason: 'server data is authoritative and replaces the cache');
    });
  });
}
