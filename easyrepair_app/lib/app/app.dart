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
import '../core/widgets/app_banner_overlay.dart';
import '../features/auth/domain/entities/user_entity.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/bookings/presentation/providers/booking_providers.dart';
import '../features/bookings/presentation/providers/review_prompt_controller.dart';
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
            // A review dismissed or failed earlier is still pending — clear
            // this session's deferrals and re-offer it. This is also what
            // recovers a completion push the client never saw, so a missed
            // notification can never permanently lose the review prompt.
            _promptPendingReviews(clearDeferrals: true);
          }
        }
      default:
        break;
    }
  }

  /// Asks the shared [ReviewPromptController] to re-check backend truth and
  /// prompt for anything still outstanding.
  ///
  /// Every review prompt in the app goes through that controller, so this can
  /// never stack a second modal on top of one already showing (including the
  /// mandatory Find-Other-Ustaad prompt).
  void _promptPendingReviews({bool clearDeferrals = false}) {
    final controller = ref.read(reviewPromptControllerProvider);
    if (clearDeferrals) controller.clearSessionDeferrals();
    final context = ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;
    if (context == null) return;
    unawaited(controller.refreshAndPrompt(context));
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

  void _navigateFromData(
    Map<String, dynamic> data, {
    required bool isWorker,
  }) {
    final eventKey = data['eventKey'] as String?;
    final bookingId = data['bookingId'] as String?;
    _refreshForEventKey(eventKey, isWorker: isWorker, bookingId: bookingId);

    final router = ref.read(routerProvider);
    NotificationNavigator.navigateByRouter(router, data, isWorker: isWorker);

    // A tapped completion notification is an explicit request to deal with
    // THAT booking, so it jumps the queue ahead of unrelated older pending
    // reviews (and overrides an earlier dismissal of it).
    if (!isWorker &&
        eventKey == 'booking.completed' &&
        bookingId != null &&
        bookingId.isNotEmpty) {
      final controller = ref.read(reviewPromptControllerProvider);
      final ctx = router.routerDelegate.navigatorKey.currentContext;
      if (ctx != null) controller.enqueueFront(ctx, bookingId);
    }

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
        // refresh My Jobs, New Jobs, profile stats, and — if the worker
        // already had this job's detail page cached from before the
        // hire/bid-acceptance (e.g. viewed it while still just bidding) —
        // its detail too, so a stale PENDING/"Bid Now" view doesn't linger.
        ref.invalidate(workerJobsProvider);
        ref.invalidate(newJobsProvider);
        ref.invalidate(workerProfileProvider);
        if (bookingId != null && bookingId.isNotEmpty) {
          ref.invalidate(workerJobDetailProvider(bookingId));
        }
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
      // A work unit just completed — prompt for its review. Backend truth is
      // re-fetched rather than trusting this callback, and the shared
      // controller collapses the request if a modal (e.g. the mandatory
      // Find-Other-Ustaad one) is already showing for that booking.
      if (eventKey == 'booking.completed') {
        _promptPendingReviews();
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
    return MaterialApp.router(
      title: 'EasyRepair',
      debugShowCheckedModeBanner: false,
      // Both brightnesses are built from the same semantic palette — see
      // core/theme/app_semantic_colors.dart. AppTheme.themeMode is the single
      // switch between them.
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: AppTheme.themeMode,
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
