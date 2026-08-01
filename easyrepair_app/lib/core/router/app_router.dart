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
  final authStateNotifier = ValueNotifier<bool>(false);

  ref.listen(authStateProvider, (_, __) {
    authStateNotifier.value = !authStateNotifier.value;
  });

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authStateNotifier,
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
          backRoute: '/client/chat',
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
          backRoute: '/worker/chat',
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
