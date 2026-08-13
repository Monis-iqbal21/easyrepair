import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/role_selection_page.dart';
import '../../features/auth/presentation/pages/client_otp_auth_page.dart';
import '../../features/auth/presentation/pages/worker_type_selection_page.dart';
import '../../features/auth/presentation/pages/worker_otp_register_page.dart';
import '../../features/auth/presentation/pages/worker_login_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/client_forgot_password_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/client/presentation/pages/client_home_page.dart';
import '../../features/client/presentation/pages/client_restricted_page.dart';
import '../../features/client/domain/entities/customer_agreement_entity.dart';
import '../../features/client/presentation/pages/customer_agreement_gate_page.dart';
import '../../features/client/presentation/providers/customer_agreement_providers.dart';
import '../../features/bookings/presentation/pages/my_bookings_page.dart';
import '../../features/client/presentation/pages/client_chat_page.dart';
import '../../features/client/presentation/pages/client_profile_page.dart';
import '../../features/bookings/presentation/pages/booking_detail_page.dart';
import '../../features/bookings/presentation/pages/inspection_report_page.dart';
import '../../features/client/presentation/pages/post_job_page.dart';
import '../../features/worker/presentation/pages/worker_home_page.dart';
import '../../features/worker/presentation/pages/worker_jobs_page.dart';
import '../../features/worker/presentation/pages/worker_chat_page.dart';
import '../../features/worker/presentation/pages/worker_profile_page.dart';
import '../../features/worker/presentation/pages/worker_profile_completion_page.dart';
import '../../features/worker/presentation/pages/worker_bid_page.dart';
import '../../features/worker/presentation/pages/worker_job_detail_page.dart';
import '../../features/worker/presentation/pages/inspection_report_form_page.dart';
import '../../features/worker/presentation/pages/worker_new_jobs_page.dart';
import '../../features/worker/presentation/pages/worker_reviews_page.dart';
import '../../features/worker/presentation/pages/worker_suspended_page.dart';
import '../../features/notifications/presentation/pages/notification_list_page.dart';
import '../../features/chat/presentation/pages/chat_detail_page.dart';
import '../../features/bookings/presentation/pages/track_worker_page.dart';
import '../presentation/pages/splash_page.dart';
import 'page_not_available_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ValueNotifier<bool>(false);

  ref.listen(authStateProvider, (_, __) {
    refreshNotifier.value = !refreshNotifier.value;
  });
  // The gate re-runs `redirect` the moment acceptance status changes — after
  // a successful accept (AcceptCustomerAgreementNotifier invalidates the
  // required-status provider) and after a locale change (which can flip
  // which language the required document resolves in).
  ref.listen(requiredCustomerAgreementProvider, (_, __) {
    refreshNotifier.value = !refreshNotifier.value;
  });

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    // Any unknown/invalid path (unmatched route, garbled deep link, a
    // notification pointing at an id-based route GoRouter can't match)
    // lands here instead of the framework's bare default error page. The
    // top-level `redirect` below still runs first for this location like
    // any other — a suspended Worker or a logged-out user is redirected
    // away before this is ever built, so this page is only ever reached by
    // a session that's actually allowed to be here.
    errorBuilder: (context, state) => const PageNotAvailablePage(),
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);

      final authRedirect = resolveAuthRedirect(
        authState: authState,
        matchedLocation: state.matchedLocation,
      );
      if (authRedirect != null) return authRedirect;

      final user = authState.valueOrNull;
      final isLoggedIn = user != null;

      // ── Suspended Worker lock ──────────────────────────────────────────
      // Central enforcement point — every Worker route, deep link and
      // notification tap navigates through GoRouter, so this one check is
      // enough; individual Worker pages never need their own suspension
      // check. Only WorkerStatus.SUSPENDED locks the app (ACTIVE/INACTIVE
      // are normal access).
      final suspensionRedirect = resolveWorkerSuspendedRedirect(
        user: user,
        matchedLocation: state.matchedLocation,
      );
      if (suspensionRedirect != null) return suspensionRedirect;

      // ── Restricted Client lock ─────────────────────────────────────────
      // Client-side analogue of the Worker-suspension lock above, driven by
      // the account-level AccountStatus rather than WorkerStatus. Runs
      // before the agreement gate below so a restricted account is never
      // routed through (or stuck behind) the agreement flow first.
      final restrictionRedirect = resolveClientRestrictedRedirect(
        user: user,
        matchedLocation: state.matchedLocation,
      );
      if (restrictionRedirect != null) return restrictionRedirect;

      // ── Mandatory Customer Terms gate ─────────────────────────────────
      // Applies to EVERY authenticated CLIENT route (not just the dispatch
      // above), so a notification, deep link or bottom-nav tap can never
      // navigate around it. Never applies to a WORKER. Runs on cold start,
      // right after OTP/password login/register (both invalidate
      // authStateProvider, which this redirect already re-evaluates on),
      // and on session restore — there is no separate trigger to wire per
      // flow because they all funnel through this one redirect.
      if (user != null) {
        final gateRedirect = resolveClientAgreementRedirect(
          isLoggedIn: isLoggedIn,
          isWorker: user.isWorker,
          matchedLocation: state.matchedLocation,
          agreementAsync: ref.read(requiredCustomerAgreementProvider),
        );
        if (gateRedirect != null) return gateRedirect;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashPage(),
      ),
      GoRoute(
        path: '/auth/role-select',
        builder: (_, __) => const RoleSelectionPage(),
      ),
      GoRoute(
        path: '/auth/client',
        builder: (_, __) => const ClientOtpAuthPage(),
      ),
      GoRoute(
        path: '/auth/worker/choice',
        builder: (_, __) => const WorkerTypeSelectionPage(),
      ),
      GoRoute(
        path: '/auth/worker/register',
        builder: (_, __) => const WorkerOtpRegisterPage(),
      ),
      GoRoute(
        path: '/auth/worker/login',
        builder: (_, __) => const WorkerLoginPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/auth/client/forgot-password',
        builder: (_, __) => const ClientForgotPasswordPage(),
      ),
      GoRoute(
        path: '/client/home',
        builder: (_, __) => const ClientHomePage(),
      ),
      GoRoute(
        path: '/client/agreement-gate',
        builder: (_, __) => const CustomerAgreementGatePage(),
      ),
      GoRoute(
        path: '/client/restricted',
        builder: (_, __) => const ClientRestrictedPage(),
      ),
      GoRoute(
        path: '/client/jobs',
        builder: (_, __) => const MyBookingsPage(),
      ),
      GoRoute(
        path: '/client/chat',
        builder: (_, __) => const ClientChatPage(),
      ),
      GoRoute(
        path: '/client/chat/:id',
        builder: (_, state) => ChatDetailPage(
          conversationId: state.pathParameters['id']!,
          // Only used when a notification or deep link opened the conversation
          // with no history behind it; otherwise back pops to whatever pushed
          // it (workers list, Ustaad detail, booking detail, Chats tab).
          fallbackRoute: '/client/chat',
        ),
      ),
      GoRoute(
        path: '/client/profile',
        builder: (_, __) => const ClientProfilePage(),
      ),
      GoRoute(
        path: '/client/booking/:id',
        builder: (_, state) =>
            BookingDetailPage(bookingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/client/booking/:id/inspection-report',
        builder: (_, state) => InspectionReportPage(
          bookingId: state.pathParameters['id']!,
          showDecisionButtons: true,
        ),
      ),
      GoRoute(
        path: '/client/post-job',
        builder: (context, state) {
          final service = state.uri.queryParameters['service'];
          final editId = state.uri.queryParameters['editId'];
          return BookServicePage(
            preselectedService: service,
            editBookingId: editId,
          );
        },
      ),
      GoRoute(
        path: '/worker/home',
        builder: (_, __) => const WorkerHomePage(),
      ),
      GoRoute(
        path: '/worker/new-jobs',
        builder: (_, __) => const WorkerNewJobsPage(),
      ),
      GoRoute(
        path: '/worker/jobs',
        builder: (_, __) => const WorkerJobsPage(),
      ),
      GoRoute(
        path: '/worker/chat',
        builder: (_, __) => const WorkerChatPage(),
      ),
      GoRoute(
        path: '/worker/chat/:id',
        builder: (_, state) => ChatDetailPage(
          conversationId: state.pathParameters['id']!,
          // Only used when a notification or deep link opened the conversation
          // with no history behind it; otherwise back pops to whatever pushed
          // it (job detail, new jobs, bid page, Chats tab).
          fallbackRoute: '/worker/chat',
        ),
      ),
      GoRoute(
        path: '/worker/profile',
        builder: (_, __) => const WorkerProfilePage(),
      ),
      GoRoute(
        path: '/worker/profile-completion',
        builder: (_, __) => const WorkerProfileCompletionPage(),
      ),
      GoRoute(
        path: '/worker/job/:id',
        builder: (_, state) => WorkerJobDetailPage(
          jobId: state.pathParameters['id']!,
          openMapOnLoad: state.uri.queryParameters['openMap'] == 'true',
        ),
      ),
      GoRoute(
        path: '/worker/job/:id/bid',
        builder: (_, state) => WorkerBidPage(
          jobId: state.pathParameters['id']!,
          // Empty means "not supplied" — WorkerBidPage renders the localized
          // fallback, which needs a context this builder does not have.
          jobTitle: state.uri.queryParameters['title'] ?? '',
        ),
      ),
      GoRoute(
        path: '/worker/job/:id/inspection-report',
        builder: (_, state) => InspectionReportFormPage(
          bookingId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/worker/job/:id/inspection-report/view',
        builder: (_, state) => InspectionReportPage(
          bookingId: state.pathParameters['id']!,
          showDecisionButtons: false,
        ),
      ),
      GoRoute(
        path: '/worker/reviews',
        builder: (_, __) => const WorkerReviewsPage(),
      ),
      GoRoute(
        path: '/worker/suspended',
        builder: (_, __) => const WorkerSuspendedPage(),
      ),
      GoRoute(
        path: '/client/track/:id',
        builder: (_, state) =>
            TrackWorkerPage(bookingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationListPage(),
      ),
    ],
  );
});

/// Pure decision logic for the top-level login/logout redirect — splash
/// dispatch and the logged-out gate.
///
/// Extracted from the `redirect` closure so it can be unit-tested directly,
/// without booting a full GoRouter/widget tree.
///
/// Rules:
///  * [authState] has NO value yet — still resolving its very first check,
///    or errored before any user was ever confirmed (`!hasValue &&
///    (isLoading || hasError)`) → splash, since there is nothing to route on.
///  * A background REFRESH of an already-confirmed session (`isLoading` or
///    `hasError` while `hasValue` is still true — e.g. app-resume invalidates
///    [authStateProvider] while the user is deep in navigation, or a token
///    refresh races a `/auth/me` retry) falls straight through to the
///    `valueOrNull` below instead: Riverpod's `copyWithPrevious` keeps the
///    last confirmed user visible through both states (see
///    AuthStateNotifier), so a background refresh must never be read as
///    logged out or bounce the user off their current route.
///  * From splash, or a still-logged-in user sitting on an `/auth` route →
///    dispatch to the correct home, or back to role-select if logged out.
///  * A logged-out user anywhere else → role-select.
///  * Otherwise `null` — leave navigation alone (the caller applies further
///    redirects, e.g. the Customer Terms gate).
String? resolveAuthRedirect({
  required AsyncValue<UserEntity?> authState,
  required String matchedLocation,
}) {
  final isSplash = matchedLocation == '/splash';
  final isAuthRoute = matchedLocation.startsWith('/auth');

  if (!authState.hasValue && (authState.isLoading || authState.hasError)) {
    return isSplash ? null : '/splash';
  }

  final user = authState.valueOrNull;
  final isLoggedIn = user != null;

  // Workers always land on Home regardless of onboarding/approval status —
  // the profile-completion modal/banner and action-level gating (Go Online,
  // bid, apply) handle the "not approved yet" case there, rather than
  // hard-blocking the whole app on a dead-end page.
  if (isSplash || (isLoggedIn && isAuthRoute)) {
    if (user == null) return '/auth/role-select';
    return user.isWorker ? '/worker/home' : '/client/home';
  }

  if (!isLoggedIn && !isAuthRoute) return '/auth/role-select';

  return null;
}

/// Pure decision logic for the Worker-suspension lock — the central gate
/// that fully blocks the Worker app for `WorkerStatus.SUSPENDED` while
/// leaving ACTIVE/INACTIVE untouched.
///
/// Extracted from the `redirect` closure so it can be unit-tested directly.
/// This is the ONLY place suspension is enforced — individual Worker pages
/// never duplicate this check.
///
/// Rules:
///  * Never applies when logged out or to a CLIENT (`null`).
///  * A suspended Worker anywhere except `/worker/suspended` is redirected
///    there — covers every route, deep link and notification tap, since
///    they all navigate through GoRouter.
///  * A Worker who is no longer suspended (admin restored ACTIVE/INACTIVE)
///    sitting on `/worker/suspended` is redirected to `/worker/home` — this
///    is what makes "next session refresh restores normal access" true.
String? resolveWorkerSuspendedRedirect({
  required UserEntity? user,
  required String matchedLocation,
}) {
  if (user == null || !user.isWorker) return null;

  final isSuspendedRoute = matchedLocation == '/worker/suspended';

  if (user.isSuspendedWorker) {
    return isSuspendedRoute ? null : '/worker/suspended';
  }
  return isSuspendedRoute ? '/worker/home' : null;
}

/// Pure decision logic for the Client account-restriction lock — the
/// Client-side analogue of [resolveWorkerSuspendedRedirect], driven by
/// `AccountStatus.SUSPENDED` (User-level) rather than `WorkerStatus`.
///
/// Extracted from the `redirect` closure so it can be unit-tested directly.
/// This is the ONLY place Client restriction is enforced — individual
/// Client pages never duplicate this check.
///
/// Rules:
///  * Never applies when logged out or to a WORKER (`null`).
///  * A restricted Client anywhere except `/client/restricted` is
///    redirected there — covers every route, deep link and notification
///    tap, since they all navigate through GoRouter.
///  * A Client who is no longer restricted (admin reactivated) sitting on
///    `/client/restricted` is redirected to `/client/home` — this is what
///    makes "next session refresh restores normal access" true.
String? resolveClientRestrictedRedirect({
  required UserEntity? user,
  required String matchedLocation,
}) {
  if (user == null || user.isWorker) return null;

  final isRestrictedRoute = matchedLocation == '/client/restricted';

  if (user.isRestrictedClient) {
    return isRestrictedRoute ? null : '/client/restricted';
  }
  return isRestrictedRoute ? '/client/home' : null;
}

/// Pure decision logic for the mandatory Customer Terms gate redirect.
///
/// Extracted from the `redirect` closure so it can be unit-tested directly,
/// without booting a full GoRouter/widget tree. Returns the location to
/// redirect to, or `null` to leave navigation alone.
///
/// Rules:
///  * Never applies when logged out or to a WORKER (`null`).
///  * While [agreementAsync] has NO value yet (its very first resolution),
///    stays on `/splash` rather than flashing any client content. A
///    background REFRESH of an already-resolved status (`isLoading` while
///    `hasValue` is still true — e.g. after accepting, or a locale change,
///    while the client is already deep in navigation) falls straight through
///    to the retained `valueOrNull` below instead of bouncing to splash.
///  * A network/server error ([agreementAsync] has an error) is treated the
///    same as "acceptance required" — it must never be read as "accepted".
///  * Once required, every location except the gate itself redirects to it.
///  * Once no longer required, sitting on the gate redirects to home.
String? resolveClientAgreementRedirect({
  required bool isLoggedIn,
  required bool isWorker,
  required String matchedLocation,
  required AsyncValue<CustomerAgreementStatusEntity?> agreementAsync,
}) {
  if (!isLoggedIn || isWorker) return null;

  final isGateRoute = matchedLocation == '/client/agreement-gate';

  if (agreementAsync.isLoading && !agreementAsync.hasValue) {
    return matchedLocation == '/splash' ? null : '/splash';
  }

  final mustShowGate = agreementAsync.hasError ||
      agreementAsync.valueOrNull?.acceptanceRequired == true;

  if (mustShowGate && !isGateRoute) return '/client/agreement-gate';
  if (!mustShowGate && isGateRoute) return '/client/home';
  return null;
}
