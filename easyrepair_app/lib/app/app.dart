import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/l10n_config.dart';
import '../core/l10n/locale_provider.dart';
import '../core/notifications/local_notification_service.dart';
import '../core/permissions/app_permission_service.dart';
import '../core/notifications/notification_navigator.dart';
import '../core/notifications/pending_notification_store.dart';
import '../core/router/app_router.dart';
import '../core/services/chat_socket_service.dart';
import '../core/storage/secure_storage_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_provider.dart';
import '../core/widgets/app_banner_overlay.dart';
import '../features/auth/domain/entities/user_entity.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/bookings/presentation/providers/booking_providers.dart';
import '../features/complaints/presentation/providers/complaint_providers.dart';
import '../features/chat/presentation/providers/chat_providers.dart';
import '../features/notifications/data/datasources/notification_remote_datasource.dart';
import '../features/notifications/data/repositories/notification_repository_impl.dart';
import '../features/notifications/presentation/providers/notification_providers.dart';
import '../features/notifications/presentation/utils/notification_event_refresh.dart';
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
          // Re-fetch current-user/session state now that the app is
          // foreground again, so a Worker suspended/reactivated, a Client
          // suspended/restricted, or an account deleted/deactivated while
          // backgrounded is picked up without requiring re-login. GoRouter's
          // redirect already listens to authStateProvider (see
          // core/router/app_router.dart) and reacts automatically once this
          // resolves. A temporary network failure here never logs the user
          // out — AuthStateNotifier.build only nulls state on a genuine 401.
          ref.invalidate(authStateProvider);
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
    _subs.add(FirebaseMessaging.onMessageOpenedApp.listen(_handleFcmMessage));

    // ── Terminated-launch tap via FCM (not a local notification) ─────────────
    // Checked once at startup; null if app was not opened from a notification.
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleFcmMessage(message);
    });

    // ── Foreground FCM message ────────────────────────────────────────────────
    _subs.add(FirebaseMessaging.onMessage.listen(_handleForegroundFcmMessage));

    // ── FCM token refresh ─────────────────────────────────────────────────────
    _subs.add(
      FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh),
    );

    // The authenticated socket is the fastest foreground lifecycle path.
    // It carries the same eventKey/bookingId as FCM, so run the same provider
    // refresh instead of only painting the app-banner overlay.
    _subs.add(
      ChatSocketService.instance.onAppBanner.listen(_handleSocketAppBanner),
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
      _refreshForEventKey(
        eventKey,
        isWorker: user.isWorker,
        bookingId: bookingId,
      );
    }

    // On Android, FCM does NOT show a system-tray notification while the app
    // is in the foreground — show a local notification to fill that gap.
    // On iOS, setForegroundNotificationPresentationOptions handles visibility.
    if (Platform.isAndroid) {
      // Fire-and-forget; failures are logged inside the service.
      LocalNotificationService.instance.showFromMessage(message).ignore();
    }
  }

  void _handleSocketAppBanner(Map<String, dynamic> payload) {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    _refreshForEventKey(
      payload['eventKey'] as String?,
      isWorker: user.isWorker,
      bookingId: payload['bookingId'] as String?,
    );
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);
  }

  /// Central navigation handler for ALL notification tap sources.
  /// Safe to call from any context — queues navigation if auth is not ready.
  void _handleNotificationData(Map<String, dynamic> data) {
    final authState = ref.read(authStateProvider);
    final user = authState.valueOrNull;

    if (user == null) {
      // Auth is not ready yet (e.g. app cold-started from a notification tap)
      // or the user is genuinely logged out. Keep it in memory for the
      // same-process case (unchanged), and also persist a minimal version so
      // it survives the process being killed before login completes — see
      // _consumePersistedPendingNotification.
      _pendingNotificationData = data;
      ref.read(pendingNotificationStoreProvider).save(data);
      return;
    }

    _navigateFromData(data, isWorker: user.isWorker);
  }

  /// Restores a notification destination saved by [_handleNotificationData]
  /// that survived the app process being killed before login completed.
  /// Only reached when there was nothing to drain from the in-memory
  /// [_pendingNotificationData] (that path already handles the same-process
  /// case unchanged).
  ///
  /// Fails closed: a missing, corrupt, expired, or account-mismatched entry
  /// is discarded without navigating anywhere — see PendingNotificationStore
  /// for the TTL and PendingNotification.ownerUserIdHint for the mismatch
  /// check. Always clears the persisted entry so it is never consumed twice.
  Future<void> _consumePersistedPendingNotification(UserEntity user) async {
    final store = ref.read(pendingNotificationStoreProvider);
    final pending = await store.read();
    if (pending == null) return;
    await store.clear();

    if (pending.ownerUserIdHint != user.id) {
      // Saved while a different account (or no known account) was last
      // authenticated on this device — never navigate a freshly-logged-in
      // account into another account's booking/chat/job.
      return;
    }

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateFromData(pending.data, isWorker: user.isWorker);
    });
  }

  void _navigateFromData(Map<String, dynamic> data, {required bool isWorker}) {
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
          })
          .catchError((Object _) {});
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
    final hasBookingId = bookingId != null && bookingId.isNotEmpty;
    final targets = notificationRefreshTargets(
      eventKey,
      isWorker: isWorker,
      hasBookingId: hasBookingId,
    );
    for (final target in targets) {
      switch (target) {
        case NotificationRefreshTarget.conversations:
          ref.invalidate(chatConversationsProvider);
        case NotificationRefreshTarget.bookings:
          ref.invalidate(bookingsNotifierProvider);
        case NotificationRefreshTarget.bookingDetail:
          ref.invalidate(bookingDetailProvider(bookingId!));
        case NotificationRefreshTarget.inspectionReport:
          ref.invalidate(inspectionReportProvider(bookingId!));
        case NotificationRefreshTarget.complaint:
          ref.invalidate(bookingComplaintProvider(bookingId!));
        case NotificationRefreshTarget.workerJobs:
          ref.invalidate(workerJobsProvider);
        case NotificationRefreshTarget.workerJobDetail:
          ref.invalidate(workerJobDetailProvider(bookingId!));
        case NotificationRefreshTarget.newJobs:
          ref.invalidate(newJobsProvider);
        case NotificationRefreshTarget.workerProfile:
          ref.invalidate(workerProfileProvider);
      }
    }
  }

  // ── Token management ─────────────────────────────────────────────────────

  /// Connect the chat socket using the stored access token.
  /// Non-critical — failures are silently ignored.
  Future<void> _connectChatSocket() async {
    try {
      final token = await ref
          .read(secureStorageServiceProvider)
          .getAccessToken();
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
          .saveFcmToken(token, locale: ref.read(localeProvider).storageValue);
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
    ref.listen(localeProvider, (previous, next) {
      if (previous == null || previous == next) return;
      if (ref.read(authStateProvider).valueOrNull == null) return;
      // Language changes must reach the server even when Firebase keeps the
      // same token. Re-registering the existing token is idempotent and now
      // updates its notification locale in the same authenticated request.
      _registerFcmToken();
    });

    ref.listen(authStateProvider, (previous, next) {
      final user = next.valueOrNull;
      if (previous?.valueOrNull?.id != user?.id) {
        ref.invalidate(chatConversationsProvider);
        ref.invalidate(newJobsProvider);
        ref.invalidate(newJobsUnfilteredProvider);
        ref.invalidate(workerProfileProvider);
        ref.invalidate(markNewJobsSeenProvider);
        ref.invalidate(newJobsSeenAtOverrideProvider);
      }

      if (user != null) {
        // Connect chat socket on login.
        _connectChatSocket();

        // Register FCM token on first login.
        if (!_fcmTokenRegistered) {
          _fcmTokenRegistered = true;
          _registerFcmToken();
        }

        // Records this device as last used by this account — the only
        // signal a notification saved later, while logged out, can be
        // tagged with (see _consumePersistedPendingNotification's
        // account-mismatch check). Deliberately not awaited; harmless if it
        // loses a race with an immediate logout.
        ref.read(pendingNotificationStoreProvider).setLastKnownUserId(user.id);

        // Request any missing permissions once per session.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            AppPermissionService.instance.maybeRequest(context);
          }
        });

        // Drain any notification that arrived before auth was ready —
        // in-memory first (same-process case, unchanged), else fall back to
        // whatever survived a process kill in between.
        final pending = _pendingNotificationData;
        _pendingNotificationData = null;
        if (pending != null) {
          // addPostFrameCallback ensures the router has completed its initial
          // redirect (e.g. from /auth/role-select to the home page) before we
          // attempt to push a booking-detail route on top of it.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _navigateFromData(pending, isWorker: user.isWorker);
          });
          // The same notification was also persisted (save() runs
          // unconditionally in _handleNotificationData) — clear it now so a
          // later session on this device never replays it a second time.
          ref.read(pendingNotificationStoreProvider).clear();
        } else {
          _consumePersistedPendingNotification(user);
        }
      }

      if (user == null) {
        _fcmTokenRegistered = false;
        _pendingNotificationData = null;
        // A pending destination saved before this logout was, at best,
        // meant for the account that just signed out — never carry it
        // forward to whoever logs in next on this device.
        ref.read(pendingNotificationStoreProvider).clear();
        // Disconnect chat socket on logout.
        ChatSocketService.instance.disconnect();
        // Reset permission session flag so it runs again on next login.
        AppPermissionService.instance.reset();
        // Reset the onboarding-modal session flag so a different Ustaad
        // logging in on the same app session sees it if they need to.
        ref.read(onboardingModalShownProvider.notifier).state = false;
      }
    });

    final router = ref.watch(routerProvider);
    final appLocale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'EasyRepair',
      debugShowCheckedModeBanner: false,
      // Both brightnesses are built from the same semantic palette — see
      // core/theme/app_semantic_colors.dart. AppTheme.themeMode is the single
      // switch between them.
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      locale: appLocale.locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      // The language is always an explicit user choice, never negotiated from
      // the device. Returning it verbatim also stops ur_Latn from collapsing
      // into plain ur during locale resolution.
      localeResolutionCallback: (_, _) => appLocale.locale,
      builder: (context, child) =>
          AppBannerOverlay(child: child ?? const SizedBox.shrink()),
    );
  }
}
