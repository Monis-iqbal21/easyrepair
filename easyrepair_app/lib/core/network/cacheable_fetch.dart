import 'package:dio/dio.dart';

import '../data/cached_result.dart';
import '../errors/dio_failure_mapper.dart';
import '../storage/local_cache_service.dart';
import '../storage/secure_storage_service.dart';

/// Runs a GET-style [request], caching the raw decoded JSON on success and
/// falling back to the last cached value (marked [CachedResult.isStale])
/// when the request fails and something was previously cached for this
/// account. Rethrows the mapped [Failure] when there is nothing to fall
/// back on — the normal "no cache, no internet" path.
///
/// [request] performs the network call and returns the raw JSON body
/// (already unwrapped from the `{success, data}` envelope — a decoded `Map`
/// or `List`, never a parsed model) so it round-trips through
/// [LocalCacheService] without needing model `toJson()` methods. [decode]
/// turns that raw JSON (live or cached) into the real return type.
Future<CachedResult<T>> fetchWithCache<T>({
  required LocalCacheService cache,
  required SecureStorageService secureStorage,
  required String cacheKey,
  required Future<dynamic> Function() request,
  required T Function(dynamic json) decode,
}) async {
  final userId = await secureStorage.getCurrentUserId();
  try {
    final raw = await request();
    if (userId != null) {
      await cache.write(userId, cacheKey, raw);
    }
    return CachedResult(decode(raw));
  } on DioException catch (e) {
    final failure = dioExceptionToFailure(e);
    if (userId != null) {
      final cached = cache.read(userId, cacheKey);
      if (cached != null) {
        try {
          return CachedResult(decode(cached.data), isStale: true);
        } catch (_) {
          // Corrupt/incompatible cached shape (e.g. an old app version's
          // payload) — fall through to surfacing the live failure instead.
        }
      }
    }
    throw failure;
  }
}
