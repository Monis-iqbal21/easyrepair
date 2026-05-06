import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/client/presentation/pages/client_home_page.dart';
import '../../features/bookings/presentation/pages/my_bookings_page.dart';
import '../../features/client/presentation/pages/client_chat_page.dart';
import '../../features/client/presentation/pages/client_profile_page.dart';
import '../../features/bookings/presentation/pages/booking_detail_page.dart';
import '../../features/client/presentation/pages/post_job_page.dart';
import '../../features/worker/presentation/pages/verification_pending_page.dart';
import '../../features/worker/presentation/pages/worker_home_page.dart';
import '../../features/worker/presentation/pages/worker_jobs_page.dart';
import '../../features/worker/presentation/pages/worker_chat_page.dart';
import '../../features/worker/presentation/pages/worker_profile_page.dart';
import '../../features/worker/presentation/pages/worker_bid_page.dart';
import '../../features/worker/presentation/pages/worker_job_detail_page.dart';
import '../../features/worker/presentation/pages/worker_new_jobs_page.dart';
import '../../features/worker/presentation/pages/worker_reviews_page.dart';
import '../../features/notifications/presentation/pages/notification_list_page.dart';
import '../../features/chat/presentation/pages/chat_detail_page.dart';
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

      // From splash or auth route: dispatch to correct home
      if (isSplash || (isLoggedIn && isAuthRoute)) {
        if (!isLoggedIn) return '/auth/login';
        if (user!.isWorker) {
          return user.isVerifiedWorker
              ? '/worker/home'
              : '/worker/verification-pending';
        }
        return '/client/home';
      }

      if (!isLoggedIn && !isAuthRoute) return '/auth/login';

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashPage(),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (_, __) => const RegisterPage(),
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
        builder: (_, state) =>
            ChatDetailPage(conversationId: state.pathParameters['id']!),
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
        builder: (_, state) =>
            ChatDetailPage(conversationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/worker/profile',
        builder: (_, __) => const WorkerProfilePage(),
      ),
      GoRoute(
        path: '/worker/job/:id',
        builder: (_, state) => WorkerJobDetailPage(
          jobId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/worker/job/:id/bid',
        builder: (_, state) => WorkerBidPage(
          jobId: state.pathParameters['id']!,
          jobTitle: state.uri.queryParameters['title'] ?? 'Job',
        ),
      ),
      GoRoute(
        path: '/worker/reviews',
        builder: (_, __) => const WorkerReviewsPage(),
      ),
      GoRoute(
        path: '/worker/verification-pending',
        builder: (_, __) => const VerificationPendingPage(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationListPage(),
      ),
    ],
  );
});
