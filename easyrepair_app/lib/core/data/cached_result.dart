/// Wraps a successfully-returned value with whether it came from the network
/// just now ([isStale] `false`) or from [LocalCacheService] because the live
/// request failed ([isStale] `true`).
///
/// Only used by repository methods that support offline read fallback —
/// every other method keeps returning its plain type wrapped in `Either`.
class CachedResult<T> {
  final T data;
  final bool isStale;

  const CachedResult(this.data, {this.isStale = false});
}
