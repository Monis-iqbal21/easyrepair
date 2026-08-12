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
  const CachedEntry(this.data, this.savedAt);
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

  final SharedPreferences _prefs;

  const LocalCacheService(this._prefs);

  String _fullKey(String userId, String key) => '$_prefix:$userId:$key';

  /// Persists [jsonValue] (already-decoded JSON — a `Map`/`List`/primitive)
  /// under [key] for [userId], stamped with the current time.
  Future<void> write(String userId, String key, Object? jsonValue) async {
    final envelope = jsonEncode({
      'savedAt': DateTime.now().toIso8601String(),
      'data': jsonValue,
    });
    await _prefs.setString(_fullKey(userId, key), envelope);
  }

  /// Reads back the entry for [key]/[userId], or `null` if nothing was ever
  /// cached (or the stored envelope is corrupt).
  CachedEntry? read(String userId, String key) {
    final raw = _prefs.getString(_fullKey(userId, key));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt =
          DateTime.tryParse(decoded['savedAt'] as String? ?? '') ??
              DateTime.now();
      return CachedEntry(decoded['data'], savedAt);
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
