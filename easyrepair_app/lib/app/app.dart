import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/local_notification_service.dart';
import '../core/permissions/app_permission_service.dart';
import '../core/notifications/notification_navigator.dart';
import '../core/router/app_router.dart';
import '../core/services/chat_socket_service.dart';
import '../core/storage/secure_storage_service.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_banner_overlay.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/bookings/presentation/providers/booking_providers.dart';
import '../features/chat/presentation/providers/chat_providers.dart';
import '../features/notifications/data/datasources/notification_remote_datasource.dart';
import '../features/notifications/data/repositories/notification_repository_impl.dart';
import '../features/notifications/presentation/providers/notification_providers.dart';
import '../features/worker/presentation/providers/worker_job_providers.dart';
import '../features/worker/presentation/providers/worker_providers.dart';

class EasyRepairApp extends ConsumerStatefulWidget {
  const EasyRepairApp({super.key});

  @override
  ConsumerState<EasyRepairApp> createState() => _EasyRepairAppState();
}

class _EasyRepairAppState extends ConsumerState<EasyRepairApp>
    with WidgetsBindingObserver {
  bool _fcmTokenRegistered = false;

  /// Event keys pushed to a worker when a booking becomes theirs — STANDARD/
  /// INSPECTION direct hire (`booking.assigned`, see bookings.service.ts) and
  /// BIDDING lane bid acceptance (`bid.accepted`, see bids.service.ts).
  static const _assignedJobEventKeys = {'booking.assigned', 'bid.accepted'};

  /// Worker-side lifecycle events that should silently refresh the CLIENT's
  /// booking detail/list (and the inspection report for the report_submitted
  /// case). See bookings.service.ts / inspection-reports.service.ts for the
  /// eventKey source of each.
  static const _clientLiveSyncEventKeys = {
    'booking.status.en_route',
    'booking.status.arrived',
    'booking.status.in_progress',
    'booking.inspection.report_submitted',
    'booking.completed',
    'booking.cancelled.by_worker',
  };

  /// Client-side lifecycle events (beyond hire/bid-accept, already covered by
  /// [_assignedJobEventKeys]) that should silently refresh the WORKER's job
  /// list/detail/profile stats.
  static const _workerLiveSyncEventKeys = {
    'booking.cancelled.by_client',
    'booking.inspection.quote_accepted',
    'booking.inspection.closed',
    'booking.review.created',
  };

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
        if (user != null) {
          _connectChatSocket();
          // Refresh notification badge and chat list once on resume — no polling.
          ref.invalidate(unreadNotificationCountProvider);
          ref.invalidate(chatConversationsProvider);
          // Covers a lifecycle push that arrived while backgrounded: per-page
          // resume/poll handlers only run if that specific page is currently
          // mounted, so refresh the list-level provider here unconditionally
          // to catch e.g. Home-tab resumes too. Detail pages (keyed by a
          // specific bookingId) keep their own resume/poll handlers since
          // there's no single provider to invalidate without knowing which
          // booking was open.
          if (user.isWorker) {
            ref.invalidate(workerJobsProvider);
            ref.invalidate(newJobsProvider);
            ref.invalidate(workerProfileProvider);
          } else {
            ref.invalidate(bookingsNotifierProvider);
          }
        }
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

    final eventKey = message.data['eventKey'] as String?;
    final bookingId = message.data['bookingId'] as String?;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user != null) {
      _refreshForEventKey(eventKey, isWorker: user.isWorker, bookingId: bookingId);
    }

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
    final eventKey = data['eventKey'] as String?;
    final bookingId = data['bookingId'] as String?;
    _refreshForEventKey(eventKey, isWorker: isWorker, bookingId: bookingId);

    final router = ref.read(routerProvider);
    NotificationNavigator.navigateByRouter(router, data, isWorker: isWorker);

    // Mark the tapped notification as read and refresh unread count.
    final notificationId = data['notificationId'] as String?;
    if (notificationId != null && notificationId.isNotEmpty) {
      ref
          .read(notificationRepositoryProvider)
          .markRead(notificationId)
          .then((_) {
        ref.invalidate(unreadNotificationCountProvider);
        // Also patch the in-memory list if it is already loaded.
        final notifier = ref.read(notificationsProvider.notifier);
        notifier.markRead(notificationId);
      }).catchError((Object _) {});
    } else {
      // No notificationId in payload — still refresh the count in case the
      // backend already marked it (e.g. via a different code path).
      ref.invalidate(unreadNotificationCountProvider);
    }
  }

  /// Silently refreshes the relevant provider(s) for a booking-lifecycle
  /// push notification — shared by the foreground-message handler and the
  /// notification-tap handler so both paths react identically. Every
  /// invalidate() here targets a non-autoDispose provider that preserves its
  /// previous value while refetching (AsyncNotifier's isRefreshing /
  /// copyWithPrevious), so none of this shows a full-tab spinner. No-op for
  /// eventKeys not recognized below.
  void _refreshForEventKey(
    String? eventKey, {
    required bool isWorker,
    String? bookingId,
  }) {
    if (isWorker) {
      if (eventKey == 'new_job') {
        // A new_job notification arrived — immediately refresh the New Jobs
        // tab so the job appears without waiting for the 30-second auto-poll.
        ref.invalidate(newJobsProvider);
      } else if (_assignedJobEventKeys.contains(eventKey)) {
        // Worker was just hired/assigned (direct hire or accepted bid) —
        // refresh My Jobs, New Jobs, and profile stats.
        ref.invalidate(workerJobsProvider);
        ref.invalidate(newJobsProvider);
        ref.invalidate(workerProfileProvider);
      } else if (_workerLiveSyncEventKeys.contains(eventKey)) {
        // Client-side action on a booking this worker is assigned to
        // (cancelled, quote accepted/closed, review left) — refresh the
        // worker's list and, if we know which booking, its detail page too.
        ref.invalidate(workerJobsProvider);
        if (bookingId != null && bookingId.isNotEmpty) {
          ref.invalidate(workerJobDetailProvider(bookingId));
        }
        if (eventKey == 'booking.review.created') {
          // A new review can move the worker's average rating shown on Home.
          ref.invalidate(workerProfileProvider);
        }
      }
    } else if (_clientLiveSyncEventKeys.contains(eventKey)) {
      // Worker-side lifecycle action on the client's booking — refresh the
      // bookings list and, if we know which booking, its detail page (plus
      // the inspection report when one was just submitted).
      ref.invalidate(bookingsNotifierProvider);
      if (bookingId != null && bookingId.isNotEmpty) {
        ref.invalidate(bookingDetailProvider(bookingId));
        if (eventKey == 'booking.inspection.report_submitted') {
          ref.invalidate(inspectionReportProvider(bookingId));
        }
      }
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

        // Request any missing permissions once per session.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            AppPermissionService.instance.maybeRequest(context);
          }
        });

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
        // Reset permission session flag so it runs again on next login.
        AppPermissionService.instance.reset();
      }
    });

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'EasyRepair',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) =>
          AppBannerOverlay(child: child ?? const SizedBox.shrink()),
    );
  }
}
