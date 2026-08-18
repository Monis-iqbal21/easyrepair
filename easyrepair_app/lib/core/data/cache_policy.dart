/// The ONE place HandyGo decides how long a cached read may be presented as
/// a usable offline fallback.
///
/// Before this existed, TTLs were bare `Duration(...)` literals at individual
/// call sites (the New Jobs 24h rule lived inline in the worker datasource)
/// and every other cached endpoint simply had none, which made "is this
/// intentional or an oversight?" unanswerable per endpoint. Naming the
/// policies makes each datasource declare which KIND of data it is caching,
/// and the answer to "what is our offline retention rule for account history?"
/// lives in one file.
///
/// IMPORTANT: these values are the ALREADY-APPROVED product rules, read off
/// the existing implementation — not new decisions. In particular the New
/// Jobs 24h offline fallback is unchanged.
class CachePolicy {
  /// How stale a cached entry may be and still be served when the network is
  /// unreachable. `null` means "no expiry" — the last known snapshot stays
  /// available indefinitely offline.
  final Duration? maxAge;

  /// Human-readable name, for debugging and test assertions.
  final String name;

  const CachePolicy._(this.name, this.maxAge);

  // ── TYPE A — live / highly volatile ──────────────────────────────────────

  /// Worker New Jobs marketplace discovery.
  ///
  /// A live marketplace list, not account history: once the cached copy is
  /// older than this it stops being offered as an offline fallback, so the
  /// Worker sees a clean "no current data" state instead of a list of jobs
  /// that were very likely taken hours ago. **24h — the existing, approved
  /// rule; do not change without a product decision.**
  static const newJobs = CachePolicy._('newJobs', Duration(hours: 24));

  /// Live Worker availability / nearby discovery.
  ///
  /// Deliberately NOT cached for offline use at all. A cached "this Ustaad is
  /// online 2km away" is actively misleading — it drives a hire, which is a
  /// write, which needs the network anyway. Datasources for these endpoints
  /// should not call `fetchWithCache`; this constant exists so that choice is
  /// explicit and greppable rather than an omission.
  static const liveDiscovery = CachePolicy._('liveDiscovery', Duration.zero);

  // ── TYPE B — account state / history ─────────────────────────────────────

  /// The signed-in account's own bookings, jobs, bids, earnings,
  /// notifications, profile and chat history.
  ///
  /// No expiry: last-known state stays viewable offline for as long as it is
  /// the last thing the server told us. Age alone never makes a completed job
  /// or a past booking wrong — and the offline banner already tells the user
  /// they are looking at saved data. Refreshed on every successful fetch, on
  /// reconnect and on app resume.
  static const accountHistory = CachePolicy._('accountHistory', null);

  // ── TYPE C — static / slow-changing reference data ───────────────────────

  /// Service categories, standard-service catalog, and similar
  /// rarely-changing reference lists that are identical for every user.
  static const referenceData =
      CachePolicy._('referenceData', Duration(days: 7));

  /// True when this policy permits no offline fallback whatsoever.
  bool get isOfflineFallbackDisabled => maxAge == Duration.zero;

  /// Whether an entry saved at [savedAt] may still be served now.
  bool allowsFallback(DateTime savedAt, {DateTime? now}) {
    final limit = maxAge;
    if (limit == null) return true;
    if (limit == Duration.zero) return false;
    return (now ?? DateTime.now()).difference(savedAt) <= limit;
  }

  @override
  String toString() => 'CachePolicy($name, maxAge: $maxAge)';
}
