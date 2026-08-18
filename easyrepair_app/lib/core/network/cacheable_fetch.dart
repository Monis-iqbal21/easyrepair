import 'dart:async';

import 'package:dio/dio.dart';

import '../data/cache_policy.dart';
import '../data/cached_result.dart';
import '../errors/dio_failure_mapper.dart';
import '../errors/failures.dart';
import '../storage/local_cache_service.dart';
import '../storage/secure_storage_service.dart';

/// Runs a GET-style [request], caching the raw decoded JSON on success and
/// falling back to the last cached value (marked [CachedResult.isStale])
/// when the server could not be reached and something was previously cached
/// for this account. Rethrows the mapped [Failure] when there is nothing to
/// fall back on — the normal "no cache, no internet" path.
///
/// [request] performs the network call and returns the raw JSON body
/// (already unwrapped from the `{success, data}` envelope — a decoded `Map`
/// or `List`, never a parsed model) so it round-trips through
/// [LocalCacheService] without needing model `toJson()` methods. [decode]
/// turns that raw JSON (live or cached) into the real return type.
///
/// ## Which failures may serve cache
///
/// The rule is **"did the server give a definitive answer about this
/// request?"**, not "did something go wrong":
///
///  * **Unreachable** — no connectivity, DNS/socket error, timeout, bad
///    certificate, and 5xx/429 (the server is up but cannot answer right
///    now). These mean *we do not know the current state*, so the last known
///    state is the best available answer → **cache is served**, marked stale.
///  * **Answered** — 400, 401, 403, 404, 409. The server told us exactly what
///    is true for this request: the input is invalid, the session is gone,
///    this account is suspended/restricted, the resource does not exist. These
///    are **never** masked with cached data. Serving a cached bookings list
///    behind a 403 would make a suspended account look authorized, and hiding
///    a 401 behind cache would keep a logged-out user staring at somebody's
///    data instead of the login screen.
///
/// See [_mayServeCache].
///
/// ## [policy]
///
/// The retention rule for this KIND of data — see [CachePolicy]. Account
/// history (the default) keeps its last known snapshot indefinitely; live
/// marketplace lists such as New Jobs expire after their configured window so
/// a long-stale list is not presented as current; [CachePolicy.liveDiscovery]
/// disables offline fallback entirely.
Future<CachedResult<T>> fetchWithCache<T>({
  required LocalCacheService cache,
  required SecureStorageService secureStorage,
  required String cacheKey,
  required Future<dynamic> Function() request,
  required T Function(dynamic json) decode,
  CachePolicy policy = CachePolicy.accountHistory,
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

    // An authoritative answer from the server is surfaced as-is. Cache is a
    // substitute for an ANSWER WE DID NOT GET, never for one we did not like.
    if (!_mayServeCache(failure) || userId == null) throw failure;

    final cached = cache.read(userId, cacheKey);
    if (cached == null) throw failure;

    if (!policy.allowsFallback(cached.savedAt)) throw failure;

    try {
      return CachedResult(decode(cached.data), isStale: true);
    } catch (_) {
      // The cached payload no longer decodes — an app update changed this
      // model's shape, or the entry is corrupt. Evict just this entry so it
      // can never be retried, then surface the live failure. Deliberately
      // scoped: one poisoned key never invalidates the rest of the account's
      // cache, and a decode failure can never crash the app.
      unawaited(cache.remove(userId, cacheKey));
      throw failure;
    }
  }
}

/// Whether [failure] means "the server never gave us an answer", which is the
/// only condition under which stale cached data is a legitimate substitute.
bool _mayServeCache(Failure failure) {
  switch (failure.code) {
    // Genuinely unreachable — this is what offline fallback exists for.
    case FailureCode.noInternet:
    case FailureCode.timeout:
    case FailureCode.unknown:
    // The server is reachable but cannot answer: it is broken (5xx) or is
    // shedding load (429). Neither is a statement about this account's
    // authorization or this request's validity, so last-known data is still
    // the most accurate thing we can show.
    case FailureCode.server:
    case FailureCode.tooManyRequests:
      return true;

    // The server answered definitively. Never mask any of these.
    case FailureCode.unauthorized: // 401 — auth flow stays authoritative
    case FailureCode.forbidden: // 403 — suspension/restriction must surface
    case FailureCode.invalidRequest: // 400 — a real validation answer
    case FailureCode.notFound: // 404 — the resource is genuinely gone
    case FailureCode.conflict: // 409 — the resource moved on
    case FailureCode.requestCancelled: // caller walked away; show nothing
    case FailureCode.smsSendFailed:
    case FailureCode.otpResendTooSoon:
    case FailureCode.inspectorBusy:
    case FailureCode.phoneNotRegistered:
    case FailureCode.phoneAlreadyRegistered:
    case FailureCode.offlineActionBlocked:
      return false;
  }
}
