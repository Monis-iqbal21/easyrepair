import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/data/cached_result.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/l10n/l10n_config.dart';
import 'package:handygo_app/core/theme/app_semantic_colors.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';
import 'package:handygo_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:handygo_app/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:handygo_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:handygo_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:handygo_app/features/notifications/presentation/pages/notification_list_page.dart';
import 'package:handygo_app/features/notifications/presentation/providers/notification_providers.dart';

const _client = UserEntity(
  id: 'client-1',
  phone: '+923001234567',
  role: 'CLIENT',
  firstName: 'Ali',
  lastName: 'Khan',
);

NotificationEntity _notification({
  required String id,
  required bool isRead,
  String title = 'Booking update',
  String body = 'Your booking has a new update from your Ustaad.',
  String? eventKey,
  String? bookingId,
}) {
  return NotificationEntity(
    id: id,
    title: title,
    body: body,
    isRead: isRead,
    eventKey: eventKey,
    bookingId: bookingId,
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
  );
}

NotificationEntity _asRead(NotificationEntity notification) {
  return NotificationEntity(
    id: notification.id,
    title: notification.title,
    body: notification.body,
    isRead: true,
    readAt: DateTime.now(),
    eventKey: notification.eventKey,
    entityType: notification.entityType,
    entityId: notification.entityId,
    bookingId: notification.bookingId,
    route: notification.route,
    payload: notification.payload,
    createdAt: notification.createdAt,
  );
}

class _FakeNotificationRepository implements NotificationRepository {
  _FakeNotificationRepository(this.notifications);

  List<NotificationEntity> notifications;
  Completer<void>? fetchGate;
  Completer<void>? markReadGate;
  Completer<void>? markAllGate;
  bool failFetch = false;
  int fetchCalls = 0;
  int unreadCountCalls = 0;
  int markAllCalls = 0;
  final List<String> markReadCalls = [];

  @override
  Future<Either<Failure, CachedResult<List<NotificationEntity>>>>
  getNotifications() async {
    fetchCalls++;
    await fetchGate?.future;
    if (failFetch) {
      return const Left(ServerFailure('backend details'));
    }
    return Right(CachedResult(List.of(notifications)));
  }

  @override
  Future<Either<Failure, int>> getUnreadCount() async {
    unreadCountCalls++;
    return Right(
      notifications.where((notification) => !notification.isRead).length,
    );
  }

  @override
  Future<Either<Failure, void>> markRead(String id) async {
    markReadCalls.add(id);
    await markReadGate?.future;
    notifications = notifications
        .map(
          (notification) =>
              notification.id == id ? _asRead(notification) : notification,
        )
        .toList();
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> markAllRead() async {
    markAllCalls++;
    await markAllGate?.future;
    notifications = notifications.map(_asRead).toList();
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> saveFcmToken(
    String token, {
    required String locale,
  }) async => const Right(null);
}

class _FakeAuthStateNotifier extends AuthStateNotifier {
  @override
  Future<UserEntity?> build() async => _client;
}

Future<ProviderContainer> _pumpPage(
  WidgetTester tester,
  _FakeNotificationRepository repository, {
  ThemeData? theme,
  Size size = const Size(390, 844),
  Locale locale = const Locale('en'),
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      notificationRepositoryProvider.overrideWithValue(repository),
      authStateProvider.overrideWith(_FakeAuthStateNotifier.new),
    ],
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    initialLocation: '/notifications',
    routes: [
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationListPage(),
      ),
      GoRoute(
        path: '/client/booking/:id',
        builder: (_, state) =>
            Scaffold(body: Text('BOOKING ${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/client/chat/:id',
        builder: (_, state) =>
            Scaffold(body: Text('CHAT ${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/report',
        builder: (_, _) => const Scaffold(body: Text('REPORT')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: theme ?? AppTheme.lightTheme,
        routerConfig: router,
        locale: locale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return container;
}

Material _cardMaterial(WidgetTester tester, String id) {
  final card = find.byKey(ValueKey('notification-card-$id'));
  return tester.widget<Material>(
    find.descendant(of: card, matching: find.byType(Material)).first,
  );
}

void main() {
  group('semantic read and unread presentation', () {
    testWidgets('light theme distinguishes read and unread cards', (
      tester,
    ) async {
      final repository = _FakeNotificationRepository([
        _notification(id: 'unread', isRead: false, title: 'Unread title'),
        _notification(id: 'read', isRead: true, title: 'Read title'),
      ]);

      await _pumpPage(tester, repository);

      expect(
        _cardMaterial(tester, 'unread').color,
        AppSemanticColors.light.softTeal,
      );
      expect(
        _cardMaterial(tester, 'read').color,
        AppSemanticColors.light.surface,
      );
      expect(
        find.byKey(const ValueKey('notification-unread-indicator-unread')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('notification-unread-indicator-read')),
        findsNothing,
      );
      expect(
        tester.widget<Text>(find.text('Unread title')).style?.fontWeight,
        FontWeight.w700,
      );
      expect(
        tester.widget<Text>(find.text('Read title')).style?.fontWeight,
        FontWeight.w500,
      );
    });

    testWidgets('dark theme keeps the semantic read distinction obvious', (
      tester,
    ) async {
      final repository = _FakeNotificationRepository([
        _notification(id: 'unread', isRead: false),
        _notification(id: 'read', isRead: true),
      ]);

      await _pumpPage(tester, repository, theme: AppTheme.darkTheme);

      expect(
        _cardMaterial(tester, 'unread').color,
        AppSemanticColors.dark.softTeal,
      );
      expect(
        _cardMaterial(tester, 'read').color,
        AppSemanticColors.dark.surface,
      );
      expect(
        _cardMaterial(tester, 'unread').color,
        isNot(_cardMaterial(tester, 'read').color),
      );
    });
  });

  testWidgets('tap marks only the selected card read immediately', (
    tester,
  ) async {
    final repository = _FakeNotificationRepository([
      _notification(id: 'first', isRead: false),
      _notification(id: 'second', isRead: false),
    ])..markReadGate = Completer<void>();

    await _pumpPage(tester, repository);
    await tester.tap(find.byKey(const ValueKey('notification-card-first')));
    await tester.pump();

    expect(repository.markReadCalls, ['first']);
    expect(
      _cardMaterial(tester, 'first').color,
      AppSemanticColors.light.surface,
    );
    expect(
      _cardMaterial(tester, 'second').color,
      AppSemanticColors.light.softTeal,
    );
    expect(
      find.byKey(const ValueKey('notification-unread-indicator-first')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('notification-unread-indicator-second')),
      findsOneWidget,
    );

    repository.markReadGate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'mark all updates every card and invalidates authoritative count',
    (tester) async {
      final repository = _FakeNotificationRepository([
        _notification(id: 'first', isRead: false),
        _notification(id: 'second', isRead: false),
      ]);
      final container = await _pumpPage(tester, repository);
      expect(await container.read(unreadNotificationCountProvider.future), 2);

      await tester.tap(find.byKey(const Key('notifications-mark-all-read')));
      await tester.pumpAndSettle();

      expect(repository.markAllCalls, 1);
      expect(
        _cardMaterial(tester, 'first').color,
        AppSemanticColors.light.surface,
      );
      expect(
        _cardMaterial(tester, 'second').color,
        AppSemanticColors.light.surface,
      );
      expect(
        find.byKey(const Key('notifications-mark-all-read')),
        findsNothing,
      );
      expect(await container.read(unreadNotificationCountProvider.future), 0);
      expect(repository.unreadCountCalls, 2);
    },
  );

  testWidgets('complaint tap persists read state and opens Booking Detail', (
    tester,
  ) async {
    final repository = _FakeNotificationRepository([
      _notification(
        id: 'complaint',
        isRead: false,
        eventKey: 'complaint.created',
        bookingId: 'booking-1',
        title: 'Report submitted',
      ),
    ]);

    await _pumpPage(tester, repository);
    await tester.tap(find.byKey(const ValueKey('notification-card-complaint')));
    await tester.pumpAndSettle();

    expect(repository.markReadCalls, ['complaint']);
    expect(find.text('BOOKING booking-1'), findsOneWidget);
    expect(find.text('REPORT'), findsNothing);
  });

  testWidgets('empty state preserves localized copy', (tester) async {
    await _pumpPage(tester, _FakeNotificationRepository([]));

    expect(find.text('No notifications yet'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.byKey(const Key('notifications-mark-all-read')), findsNothing);
  });

  testWidgets('loading and error states use progress and retry flow', (
    tester,
  ) async {
    final loadingRepository = _FakeNotificationRepository([])
      ..fetchGate = Completer<void>();
    await _pumpPage(tester, loadingRepository, settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    loadingRepository.fetchGate!.complete();
    await tester.pumpAndSettle();

    final errorRepository = _FakeNotificationRepository([])..failFetch = true;
    await _pumpPage(tester, errorRepository);
    expect(find.byKey(const Key('notifications-retry')), findsOneWidget);

    errorRepository.failFetch = false;
    await tester.tap(find.byKey(const Key('notifications-retry')));
    await tester.pumpAndSettle();
    expect(find.text('No notifications yet'), findsOneWidget);
    expect(errorRepository.fetchCalls, 2);
  });

  for (final width in [320.0, 360.0, 390.0, 430.0, 600.0]) {
    testWidgets('long content has no overflow at ${width.toInt()}px', (
      tester,
    ) async {
      final repository = _FakeNotificationRepository([
        _notification(
          id: 'long',
          isRead: false,
          title:
              'A very long notification title that must remain compact and readable',
          body:
              'This is a deliberately long backend-generated message that exercises wrapping without changing its content or overflowing the card.',
        ),
      ]);

      await _pumpPage(tester, repository, size: Size(width, 844));

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('notification-card-long')),
        findsOneWidget,
      );
    });
  }

  for (final locale in [
    const Locale.fromSubtags(languageCode: 'ur', scriptCode: 'Latn'),
    const Locale('ur'),
  ]) {
    testWidgets('localized header has no overflow at 320px in $locale', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        _FakeNotificationRepository([
          _notification(id: 'localized', isRead: false),
        ]),
        size: const Size(320, 844),
        locale: locale,
      );

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('notifications-mark-all-read')),
        findsOneWidget,
      );
    });
  }
}
