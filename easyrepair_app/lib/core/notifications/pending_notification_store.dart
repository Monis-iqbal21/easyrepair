import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/locale_provider.dart' show sharedPreferencesProvider;

/// A notification tap that arrived while logged out, persisted long enough
/// to survive the app/process being killed before login completes.
class PendingNotification {
  /// The minimal routing fields from the original FCM/local-notification
  /// data payload — never the full payload, never message bodies. See
  /// [PendingNotificationStore.save] for exactly which keys are kept.
  final Map<String, dynamic> data;

  /// The id of whoever was last known to be authenticated on this device
  /// when the notification was saved (see
  /// [PendingNotificationStore.setLastKnownUserId]) — `null` if genuinely
  /// unknown (e.g. a notification somehow arrived before any account ever
  /// logged in on this device, which should not happen in practice since
  /// the FCM token is only registered after a first login).
  ///
  /// Compared against whoever actually logs in next before this is ever
  /// consumed — a mismatch means this destination was meant for a
  /// different account and must be discarded, not navigated to.
  final String? ownerUserIdHint;

  final DateTime savedAt;

  const PendingNotification({
    required this.data,
    required this.ownerUserIdHint,
    required this.savedAt,
  });
}

/// Persists at most one "logged-out notification tap" destination so it can
/// be restored after a successful login even if the app process was killed
/// in between — the existing in-memory-only mechanism in app.dart only
/// survives within the same process. Backed by [SharedPreferences] (already
/// a dependency, same pattern as `LocalCacheService`) — never secure
/// storage, since nothing sensitive is stored here: no tokens, no message
/// bodies, no full payload, just enough routing identifiers to resolve a
/// destination (eventKey, bookingId/conversationId/entityType+entityId,
/// route, notificationId) plus bookkeeping.
class PendingNotificationStore {
  static const _dataKey = 'hg_pending_notification_v1';
  static const _lastUserKey = 'hg_last_authenticated_user_id';

  /// Stale pending destinations are never resolved — long past the point a
  /// tapped notification is still a meaningful "take me there" intent.
  static const ttl = Duration(hours: 24);

  /// Only these keys are ever persisted from a notification data payload —
  /// exactly what NotificationNavigator.resolveRoute needs, nothing else
  /// (never a message body or any other payload field).
  static const _allowedKeys = {
    'eventKey',
    'bookingId',
    'conversationId',
    'entityType',
    'entityId',
    'route',
    'notificationId',
  };

  final SharedPreferences _prefs;

  const PendingNotificationStore(this._prefs);

  /// Saves the minimal routing subset of [data], stamped with the current
  /// time and the last known authenticated user (see [setLastKnownUserId]).
  Future<void> save(Map<String, dynamic> data) async {
    final minimal = <String, dynamic>{
      for (final key in _allowedKeys)
        if (data[key] != null) key: data[key],
    };
    if (minimal.isEmpty) return;

    final envelope = jsonEncode({
      'data': minimal,
      'ownerUserIdHint': _prefs.getString(_lastUserKey),
      'savedAtEpochMs': DateTime.now().millisecondsSinceEpoch,
    });
    await _prefs.setString(_dataKey, envelope);
  }

  /// Reads back the pending destination, or `null` if there isn't one, it's
  /// corrupt, or it has expired past [ttl] (both of the latter also clear
  /// it, so a bad/stale entry is never read twice).
  Future<PendingNotification?> read() async {
    final raw = _prefs.getString(_dataKey);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final savedAtEpochMs = decoded['savedAtEpochMs'] as int?;
      if (savedAtEpochMs == null) {
        await clear();
        return null;
      }
      final savedAt = DateTime.fromMillisecondsSinceEpoch(savedAtEpochMs);
      if (DateTime.now().difference(savedAt) > ttl) {
        await clear();
        return null;
      }
      return PendingNotification(
        data: Map<String, dynamic>.from(decoded['data'] as Map),
        ownerUserIdHint: decoded['ownerUserIdHint'] as String?,
        savedAt: savedAt,
      );
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> clear() => _prefs.remove(_dataKey);

  /// Records [userId] as the last account known to be authenticated on this
  /// device — call on every successful login/session-restore. Deliberately
  /// NOT cleared on logout: it exists solely so a notification that arrives
  /// later, while logged out, can still be tagged with "who this device was
  /// last used by" for the cross-account leakage check in [read]'s caller.
  /// Just an opaque backend id — never sent anywhere, never used for
  /// anything security-sensitive.
  Future<void> setLastKnownUserId(String userId) =>
      _prefs.setString(_lastUserKey, userId);
}

final pendingNotificationStoreProvider = Provider<PendingNotificationStore>((ref) {
  return PendingNotificationStore(ref.watch(sharedPreferencesProvider));
});
