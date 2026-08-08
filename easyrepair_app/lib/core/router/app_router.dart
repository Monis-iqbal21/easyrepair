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
import '../../features/client/presentation/pages/client_home_page.dart';
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
import '../../features/notifications/presentation/pages/notification_list_page.dart';
import '../../features/chat/presentation/pages/chat_detail_page.dart';
import '../../features/bookings/presentation/pages/track_worker_page.dart';
import '../presentation/pages/splash_page.dart';

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
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isSplash = state.matchedLocation == '/splash';
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      // Auth still resolving → show splash
      if (authState.isLoading) {
        return isSplash ? null : '/splash';
      }

      final user = authState.valueOrNull;
      final isLoggedIn = user != null;

      // From splash or auth route: dispatch to correct home.
      // Workers always land on Home regardless of onboarding/approval status
      // — the profile-completion modal/banner and action-level gating (Go
      // Online, bid, apply) handle the "not approved yet" case there, rather
      // than hard-blocking the whole app on a dead-end page.
      if (isSplash || (isLoggedIn && isAuthRoute)) {
        if (!isLoggedIn) return '/auth/role-select';
        if (user!.isWorker) return '/worker/home';
        return '/client/home';
      }

      if (!isLoggedIn && !isAuthRoute) return '/auth/role-select';

      // ── Mandatory Customer Terms gate ─────────────────────────────────
      // Applies to EVERY authenticated CLIENT route (not just the dispatch
      // above), so a notification, deep link or bottom-nav tap can never
      // navigate around it. Never applies to a WORKER. Runs on cold start,
      // right after OTP/password login/register (both invalidate
      // authStateProvider, which this redirect already re-evaluates on),
      // and on session restore — there is no separate trigger to wire per
      // flow because they all funnel through this one redirect.
      if (isLoggedIn) {
        final gateRedirect = resolveClientAgreementRedirect(
          isLoggedIn: isLoggedIn,
          isWorker: user!.isWorker,
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

/// Pure decision logic for the mandatory Customer Terms gate redirect.
///
/// Extracted from the `redirect` closure so it can be unit-tested directly,
/// without booting a full GoRouter/widget tree. Returns the location to
/// redirect to, or `null` to leave navigation alone.
///
/// Rules:
///  * Never applies when logged out or to a WORKER (`null`).
///  * While [agreementAsync] is still resolving, stays on `/splash` rather
///    than flashing any client content.
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

  if (agreementAsync.isLoading) {
    return matchedLocation == '/splash' ? null : '/splash';
  }

  final mustShowGate = agreementAsync.hasError ||
      agreementAsync.valueOrNull?.acceptanceRequired == true;

  if (mustShowGate && !isGateRoute) return '/client/agreement-gate';
  if (!mustShowGate && isGateRoute) return '/client/home';
  return null;
}
