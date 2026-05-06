import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/local_notification_service.dart';
import '../core/router/app_router.dart';
import '../core/services/chat_socket_service.dart';
import '../core/storage/secure_storage_service.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/notifications/data/datasources/notification_remote_datasource.dart';
import '../features/notifications/presentation/providers/notification_providers.dart';

class EasyRepairApp extends ConsumerStatefulWidget {
  const EasyRepairApp({super.key});

  @override
  ConsumerState<EasyRepairApp> createState() => _EasyRepairAppState();
}

class _EasyRepairAppState extends ConsumerState<EasyRepairApp>
    with WidgetsBindingObserver {
  bool _fcmTokenRegistered = false;

  /// Queues a notification data map that arrived before the user finished
  /// authenticating (e.g. tapping a notification that cold-starts the app).
  /// Drained once [authStateProvider] resolves to a logged-in user.
  Map<String, dynamic>? _pendingNotificationData;

  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupFcmListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  // ── App lifecycle ────────────────────────────────────────────────────────
  //
  // paused  = app fully backgrounded/minimized
  //   → disconnect chat socket so socket.io stops its internal reconnect loop
  //     and OS-suspended DNS calls stop producing SocketException spam.
  //
  // resumed = app returned to foreground
  //   → re-establish connection once if the user is authenticated.
  //     connect() is a no-op when the socket is already connected, so
  //     calling it here is safe even on brief inactive→resumed transitions.
  //
  // FCM background delivery is independent: it runs in its own Dart isolate
  // (_firebaseMessagingBackgroundHandler in main.dart) and is unaffected by
  // anything we do here.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        ChatSocketService.instance.disconnect();
      case AppLifecycleState.resumed:
        final user = ref.read(authStateProvider).valueOrNull;
        if (user != null) _connectChatSocket();
      default:
        break;
    }
  }

  void _setupFcmListeners() {
    // ── Background → foreground tap (app was running in background) ──────────
    _subs.add(
      FirebaseMessaging.onMessageOpenedApp.listen(_handleFcmMessage),
    );

    // ── Terminated-launch tap via FCM (not a local notification) ─────────────
    // Checked once at startup; null if app was not opened from a notification.
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleFcmMessage(message);
    });

    // ── Foreground FCM message ────────────────────────────────────────────────
    _subs.add(
      FirebaseMessaging.onMessage.listen(_handleForegroundFcmMessage),
    );

    // ── FCM token refresh ─────────────────────────────────────────────────────
    _subs.add(
      FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh),
    );

    // ── Local notification tap (from flutter_local_notifications) ────────────
    // Covers: foreground tap, background tap, and terminated-launch tap.
    // The setter drains any payload stored by LocalNotificationService.init()
    // before this point (i.e. the terminated-launch case).
    LocalNotificationService.onTap = _handleNotificationData;
  }

  // ── Message handlers ─────────────────────────────────────────────────────

  void _handleFcmMessage(RemoteMessage message) {
    _handleNotificationData(message.data);
  }

  void _handleForegroundFcmMessage(RemoteMessage message) {
    // Always refresh in-app notification state so the list and badge update
    // without requiring a manual pull-to-refresh.
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);

    // On Android, FCM does NOT show a system-tray notification while the app
    // is in the foreground — show a local notification to fill that gap.
    // On iOS, setForegroundNotificationPresentationOptions handles visibility.
    if (Platform.isAndroid) {
      // Fire-and-forget; failures are logged inside the service.
      LocalNotificationService.instance.showFromMessage(message).ignore();
    }
  }

  /// Central navigation handler for ALL notification tap sources.
  /// Safe to call from any context — queues navigation if auth is not ready.
  void _handleNotificationData(Map<String, dynamic> data) {
    final authState = ref.read(authStateProvider);
    final user = authState.valueOrNull;

    if (user == null) {
      // Auth is not ready yet (e.g. app cold-started from a notification tap).
      // Store and process once authentication completes.
      _pendingNotificationData = data;
      return;
    }

    _navigateFromData(data, isWorker: user.isWorker);
  }

  void _navigateFromData(
    Map<String, dynamic> data, {
    required bool isWorker,
  }) {
    final bookingId = data['bookingId'] as String?;
    final conversationId = data['conversationId'] as String?;
    final route = data['route'] as String?;

    final router = ref.read(routerProvider);

    // bookingId takes priority.
    if (bookingId != null && bookingId.isNotEmpty) {
      final destination = isWorker
          ? '/worker/job/$bookingId'
          : '/client/booking/$bookingId';
      router.go(destination);
      return;
    }

    // Chat message tap — navigate to the conversation.
    if (conversationId != null && conversationId.isNotEmpty) {
      final destination = isWorker
          ? '/worker/chat/$conversationId'
          : '/client/chat/$conversationId';
      router.go(destination);
      return;
    }

    // Fallback: use explicit route from payload.
    if (route != null && route.isNotEmpty) {
      router.go(route);
    }
  }

  // ── Token management ─────────────────────────────────────────────────────

  /// Connect the chat socket using the stored access token.
  /// Non-critical — failures are silently ignored.
  Future<void> _connectChatSocket() async {
    try {
      final token =
          await ref.read(secureStorageServiceProvider).getAccessToken();
      if (token != null) {
        ChatSocketService.instance.connect(token);
      }
    } catch (_) {}
  }

  Future<void> _registerFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveFcmToken(token);
    } catch (_) {
      // Non-critical — silently ignore.
    }
  }

  Future<void> _saveFcmToken(String token) async {
    try {
      await ref
          .read(notificationRemoteDatasourceProvider)
          .saveFcmToken(token);
    } catch (_) {}
  }

  void _onTokenRefresh(String newToken) {
    // Only update if the user is currently logged in.
    if (ref.read(authStateProvider).valueOrNull != null) {
      _saveFcmToken(newToken).ignore();
    }
  }

  // ── Widget ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (_, next) {
      final user = next.valueOrNull;

      if (user != null) {
        // Connect chat socket on login.
        _connectChatSocket();

        // Register FCM token on first login.
        if (!_fcmTokenRegistered) {
          _fcmTokenRegistered = true;
          _registerFcmToken();
        }

        // Drain any notification that arrived before auth was ready.
        final pending = _pendingNotificationData;
        if (pending != null) {
          _pendingNotificationData = null;
          // addPostFrameCallback ensures the router has completed its initial
          // redirect (e.g. from /auth/login to the home page) before we
          // attempt to push a booking-detail route on top of it.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _navigateFromData(pending, isWorker: user.isWorker);
          });
        }
      }

      if (user == null) {
        _fcmTokenRegistered = false;
        _pendingNotificationData = null;
        // Disconnect chat socket on logout.
        ChatSocketService.instance.disconnect();
      }
    });

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'EasyRepair',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
