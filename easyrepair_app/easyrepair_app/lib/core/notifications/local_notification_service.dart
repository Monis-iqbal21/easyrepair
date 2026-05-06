import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles visible local notifications for foreground FCM messages and
/// provides unified tap-routing across all app lifecycle states.
///
/// Lifecycle coverage:
///   Foreground tap  → [onDidReceiveNotificationResponse] → calls [onTap]
///   Background tap  → [onDidReceiveNotificationResponse] → calls [onTap]
///   Terminated tap  → [init] calls [getNotificationAppLaunchDetails]
///                     → stored in [_pendingPayload], drained when [onTap] is set
///
/// Android only: FCM does NOT show a system-tray notification while the app
/// is in the foreground — [showFromMessage] fills that gap.
/// iOS: [FirebaseMessaging.setForegroundNotificationPresentationOptions] handles
/// foreground FCM visibility; this service is not used for iOS foreground display.
class LocalNotificationService {
  LocalNotificationService._();
  static final instance = LocalNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const channelId = 'easyrepair_bookings';
  static const _kChannelName = 'Booking Updates';
  static const _kChannelDesc =
      'Notifications for booking status changes and job assignments';

  static const chatChannelId = 'easyrepair_chat';
  static const _kChatChannelName = 'Chat Messages';
  static const _kChatChannelDesc = 'Notifications for new chat messages';

  // ── Tap callback ─────────────────────────────────────────────────────────

  /// Stores a payload that arrived before [onTap] was registered.
  static Map<String, dynamic>? _pendingPayload;
  static void Function(Map<String, dynamic>)? _onTap;

  /// Set this once the widget tree is ready (in [initState]).
  /// Setting it automatically drains any payload that was stored before it
  /// was assigned (covers background-tap and terminated-launch cases).
  static set onTap(void Function(Map<String, dynamic>) handler) {
    _onTap = handler;
    final pending = _pendingPayload;
    if (pending != null) {
      _pendingPayload = null;
      // Defer so the caller's initState completes before navigation is attempted.
      Future.microtask(() => handler(pending));
    }
  }

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    // Permissions are already requested via FirebaseMessaging.requestPermission.
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _handleResponse,
      // Background isolate tap on Android (app is in background, not terminated)
      onDidReceiveBackgroundNotificationResponse: _backgroundHandler,
    );

    // ── Android notification channels ─────────────────────────────────────
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          _kChannelName,
          description: _kChannelDesc,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          chatChannelId,
          _kChatChannelName,
          description: _kChatChannelDesc,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );
    }

    // ── Terminated-launch: check if app was opened by tapping a local notif ─
    // This handles the case where the app was killed and the user taps a local
    // notification from the Android notification tray (local notifs are not
    // FCM messages, so getInitialMessage() returns null for them).
    await _checkLaunchDetails();
  }

  Future<void> _checkLaunchDetails() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return;
      final payload = details!.notificationResponse?.payload;
      if (payload == null || payload.isEmpty) return;
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _dispatchOrStore(data);
    } catch (_) {
      // Non-critical — silently ignore
    }
  }

  // ── Show ─────────────────────────────────────────────────────────────────

  /// Display a visible local notification from an FCM [RemoteMessage].
  ///
  /// The full FCM data map is JSON-encoded as the notification payload so it
  /// is available verbatim when the user taps the notification.
  Future<void> showFromMessage(RemoteMessage message) async {
    final n = message.notification;
    final title =
        n?.title ?? (message.data['title'] as String?) ?? 'EasyRepair';
    final body = n?.body ?? (message.data['body'] as String?) ?? '';

    // Route chat messages to the dedicated chat channel.
    final isChat = message.data.containsKey('conversationId');
    final androidChannelId = isChat ? chatChannelId : channelId;
    final androidChannelName = isChat ? _kChatChannelName : _kChannelName;
    final androidChannelDesc = isChat ? _kChatChannelDesc : _kChannelDesc;

    await _plugin.show(
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          androidChannelId,
          androidChannelName,
          channelDescription: androidChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  // ── Private ──────────────────────────────────────────────────────────────

  static void _handleResponse(NotificationResponse details) {
    final payload = details.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _dispatchOrStore(data);
    } catch (_) {}
  }

  static void _dispatchOrStore(Map<String, dynamic> data) {
    final handler = _onTap;
    if (handler != null) {
      handler(data);
    } else {
      // Store for later — drained when onTap setter is called.
      _pendingPayload = data;
    }
  }
}

/// Top-level function required by flutter_local_notifications for background
/// notification responses (Android only, when app is not in foreground).
/// Must be a top-level function annotated with @pragma('vm:entry-point').
@pragma('vm:entry-point')
void _backgroundHandler(NotificationResponse details) {
  LocalNotificationService._handleResponse(details);
}
