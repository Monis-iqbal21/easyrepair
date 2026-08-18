import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/locale_provider.dart' show sharedPreferencesProvider;

/// A cache entry read back from disk: the raw JSON payload as it was written
/// (a `Map` or `List`, exactly what the backend returned — never a parsed
/// domain model) plus when it was saved.
class CachedEntry {
  final dynamic data;
  final DateTime savedAt;

  /// The [LocalCacheService.schemaVersion] this entry was written under.
  /// Entries written before versioning existed report
  /// [LocalCacheService.schemaVersion] (they are the current shape).
  final int schemaVersion;

  const CachedEntry(this.data, this.savedAt, {this.schemaVersion = 1});

  /// How long ago this entry was written.
  Duration get age => DateTime.now().difference(savedAt);
}

/// Generic, user-scoped, persistent JSON cache for "last known good" read
/// data — bookings, jobs, profiles, chat history, etc. Backed by
/// [SharedPreferences] (already a dependency; no new storage package needed
/// for this).
///
/// Every key is namespaced by the owning account's id, so a different user
/// logging in on the same device can never read a previous account's cached
/// data (see [clearUser] for the logout-time belt-and-suspenders clear).
/// Auth tokens are never stored here — see `SecureStorageService`.
class LocalCacheService {
  static const _prefix = 'hg_cache_v1';

  /// Envelope schema version, stamped into every entry written from now on.
  ///
  /// Bump this ONLY when the envelope itself changes shape (not when a
  /// feature model changes — a model change is handled by decode failing,
  /// which evicts just that entry; see `fetchWithCache`). Any entry stamped
  /// with a different version is treated as unreadable and discarded on read,
  /// so an app update can never crash on an envelope it does not understand.
  static const schemaVersion = 1;

  final SharedPreferences _prefs;

  const LocalCacheService(this._prefs);

  String _fullKey(String userId, String key) => '$_prefix:$userId:$key';

  /// Persists [jsonValue] (already-decoded JSON — a `Map`/`List`/primitive)
  /// under [key] for [userId], stamped with the current time.
  Future<void> write(String userId, String key, Object? jsonValue) async {
    final String envelope;
    try {
      envelope = jsonEncode({
        'v': schemaVersion,
        'savedAt': DateTime.now().toIso8601String(),
        'data': jsonValue,
      });
    } catch (_) {
      // Payload contains something jsonEncode cannot represent. Caching is a
      // best-effort optimisation — never let it break the live request that
      // just succeeded. Drop any previous entry so a later read cannot serve
      // something older than what the caller just received.
      await remove(userId, key);
      return;
    }
    await _prefs.setString(_fullKey(userId, key), envelope);
  }

  /// Reads back the entry for [key]/[userId], or `null` when nothing was ever
  /// cached, the stored envelope is corrupt, or it was written under a
  /// different [schemaVersion].
  ///
  /// Never throws: a `null` return always means "treat this as a cache miss
  /// and go to the network", which is the safe outcome in every case.
  CachedEntry? read(String userId, String key) {
    final raw = _prefs.getString(_fullKey(userId, key));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;

      // An entry from a future/older envelope layout is unreadable by
      // definition. Absent 'v' means it predates versioning, which IS the
      // current layout — those entries stay valid across this upgrade.
      final version = decoded['v'] as int? ?? schemaVersion;
      if (version != schemaVersion) return null;

      final savedAt =
          DateTime.tryParse(decoded['savedAt'] as String? ?? '') ??
              DateTime.now();
      return CachedEntry(decoded['data'], savedAt, schemaVersion: version);
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String userId, String key) =>
      _prefs.remove(_fullKey(userId, key));

  /// Clears every cache entry belonging to [userId]. Called on logout so a
  /// different account signing in next never has stale private data to
  /// stumble onto — belt-and-suspenders alongside the per-user key prefix,
  /// which already makes cross-account leakage impossible on its own.
  Future<void> clearUser(String userId) async {
    final prefix = '$_prefix:$userId:';
    final keys =
        _prefs.getKeys().where((k) => k.startsWith(prefix)).toList(growable: false);
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }
}

final localCacheServiceProvider = Provider<LocalCacheService>((ref) {
  return LocalCacheService(ref.watch(sharedPreferencesProvider));
});
