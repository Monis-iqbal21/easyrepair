import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/data/cached_result.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/l10n/locale_provider.dart';
import 'package:handygo_app/core/theme/app_semantic_colors.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/bids/domain/entities/bid_entity.dart';
import 'package:handygo_app/features/bids/domain/repositories/bid_repository.dart';
import 'package:handygo_app/features/bids/presentation/providers/bid_providers.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/domain/entities/inspection_report_entity.dart';
import 'package:handygo_app/features/bookings/presentation/pages/worker_discovery_map_page.dart';
import 'package:handygo_app/features/bookings/presentation/providers/booking_providers.dart';
import 'package:handygo_app/features/chat/domain/entities/chat_entities.dart';
import 'package:handygo_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:handygo_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n_test_app.dart';

const _workerName =
    'Muhammad Abdul Rehman Shaikh Qureshi Air Conditioning Specialist';
const _bidMessage =
    'I can inspect the complete installation, repair the damaged line, and '
    'finish the work after confirming every required material with you.';

class _FakeChatRepository implements ChatRepository {
  final List<(String, String)> getOrCreateCalls = [];

  @override
  Future<Either<Failure, ConversationEntity>> getOrCreateConversation(
    String bookingId,
    String workerProfileId,
  ) async {
    getOrCreateCalls.add((bookingId, workerProfileId));
    return Right(_conversation);
  }

  @override
  Future<Either<Failure, CachedResult<List<ConversationEntity>>>>
  getConversations() async => const Right(CachedResult([]));

  @override
  Future<Either<Failure, void>> ensureSupportConversation() async =>
      const Right(null);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

final _conversation = ConversationEntity(
  id: 'conversation-1',
  clientUserId: 'client-1',
  workerUserId: 'worker-user-1',
  createdByUserId: 'client-1',
  createdAt: '2026-08-28T10:00:00.000Z',
  updatedAt: '2026-08-28T10:00:00.000Z',
  otherParticipant: const ConversationParticipantEntity(
    userId: 'worker-user-1',
    firstName: 'Muhammad',
    lastName: 'Qureshi',
  ),
);

BookingEntity _booking({required bool inspectionOrigin}) => BookingEntity(
  id: inspectionOrigin ? 'inspection-child-1' : 'direct-1',
  referenceId: inspectionOrigin ? '#ER-INSPECT' : '#ER-DIRECT',
  serviceCategory: 'Air Conditioning',
  serviceEmoji: '❄️',
  description: 'The air conditioner is not cooling.',
  status: BookingStatus.pending,
  urgency: BookingUrgency.normal,
  createdAt: DateTime(2026, 8, 28, 10),
  lane: BookingLane.bidding,
  city: 'Karachi',
  latitude: 24.86,
  longitude: 67.0,
  sourceInspectionBookingId: inspectionOrigin ? 'inspection-1' : null,
  inspectingWorker: inspectionOrigin
      ? const AssignedWorkerEntity(
          id: 'inspector-1',
          firstName: 'Ali',
          lastName: 'Khan',
          rating: 4.8,
        )
      : null,
);

BidWithWorkerEntity _bid(String bookingId) => BidWithWorkerEntity(
  bid: BidEntity(
    id: 'bid-1',
    bookingId: bookingId,
    workerProfileId: 'worker-1',
    amount: 500000,
    message: _bidMessage,
    status: BidStatus.pending,
    editCount: 0,
    createdAt: DateTime(2026, 8, 28, 11),
    updatedAt: DateTime(2026, 8, 28, 11),
  ),
  workerProfileId: 'worker-1',
  firstName: 'Muhammad Abdul Rehman',
  lastName: 'Shaikh Qureshi Air Conditioning Specialist',
  rating: 4.9,
  completedJobs: 1234,
  distanceKm: 12.8,
  skills: const [
    'Air Conditioning Installation and Repair',
    'Refrigeration',
    'Electrical Diagnostics',
  ],
  currentLat: 24.87,
  currentLng: 67.01,
);

InspectionReportEntity _report(String bookingId) => InspectionReportEntity(
  id: 'report-1',
  bookingId: bookingId,
  workerProfileId: 'inspector-1',
  issueFound: 'Damaged cooling line',
  recommendedRepair: 'Replace the cooling line',
  labourCost: 3000,
  partsNeeded: true,
  partsTotal: 2000,
  repairQuoteTotal: 5000,
  decisionStatus: InspectionDecisionStatus.findOtherUstaad,
  createdAt: DateTime(2026, 8, 28, 9),
  linkedRepairBookingId: 'inspection-child-1',
);

Future<_FakeChatRepository> _pumpPage(
  WidgetTester tester, {
  required bool inspectionOrigin,
  SharedPreferences? preferences,
  AppLocale locale = AppLocale.english,
  Size size = const Size(390, 900),
  double textScale = 1,
  ThemeData? theme,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final booking = _booking(inspectionOrigin: inspectionOrigin);
  final chat = _FakeChatRepository();
  final router = GoRouter(
    initialLocation: '/client/bidding',
    routes: [
      GoRoute(
        path: '/client/bidding',
        builder: (_, _) => WorkerDiscoveryMapPage(booking: booking),
      ),
      GoRoute(
        path: '/client/chat/:id',
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('CHAT DETAIL'))),
      ),
      GoRoute(
        path: '/client/booking/:id/inspection-report',
        builder: (_, state) => Scaffold(
          body: Center(
            child: Text('READ ONLY: ${state.uri.queryParameters['readOnly']}'),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          preferences ?? await SharedPreferences.getInstance(),
        ),
        bookingBidsProvider(
          booking.id,
        ).overrideWith((_) async => [_bid(booking.id)]),
        if (inspectionOrigin)
          inspectionReportProvider(
            booking.id,
          ).overrideWith((_) async => _report(booking.id)),
        chatRepositoryProvider.overrideWithValue(chat),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          devicePixelRatio: 1,
          textScaler: TextScaler.linear(textScale),
        ),
        child: localizedRouterApp(
          router,
          locale: locale,
          theme: theme ?? AppTheme.lightTheme,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.drag(find.byType(CustomScrollView), const Offset(0, -420));
  await tester.pumpAndSettle();
  await tester.dragUntilVisible(
    find.text(_workerName),
    find.byType(CustomScrollView),
    const Offset(0, -60),
  );
  await tester.pumpAndSettle();
  return chat;
}

void main() {
  late SharedPreferences preferences;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  for (final inspectionOrigin in [false, true]) {
    testWidgets(
      '${inspectionOrigin ? 'inspection-origin' : 'direct'} bid card keeps '
      'identity, amount, message, Chat and Hire',
      (tester) async {
        await _pumpPage(
          tester,
          inspectionOrigin: inspectionOrigin,
          preferences: preferences,
        );

        expect(find.text(_workerName), findsOneWidget);
        expect(find.textContaining('500,000'), findsOneWidget);
        expect(find.text(_bidMessage), findsOneWidget);
        expect(find.byTooltip('Chat'), findsWidgets);
        expect(find.text('Hire'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Chat reuses the existing idempotent get-or-create flow', (
    tester,
  ) async {
    final chat = await _pumpPage(
      tester,
      inspectionOrigin: false,
      preferences: preferences,
    );

    await tester.tap(find.byTooltip('Chat'));
    await tester.pumpAndSettle();

    expect(chat.getOrCreateCalls, [('direct-1', 'worker-1')]);
    expect(find.text('CHAT DETAIL'), findsOneWidget);
  });

  testWidgets('pinned report link keeps the read-only route', (tester) async {
    await _pumpPage(tester, inspectionOrigin: true, preferences: preferences);

    await tester.tap(find.text('View Inspection Report'));
    await tester.pumpAndSettle();
    expect(find.text('READ ONLY: 1'), findsOneWidget);
  });

  for (final width in <double>[320, 360, 390, 430]) {
    testWidgets('normal bid card has no overflow at ${width.toInt()}px', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        inspectionOrigin: false,
        preferences: preferences,
        size: Size(width, 900),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final locale in AppLocale.values) {
    testWidgets('normal bid card has no overflow at text scale 2.0 '
        '(${locale.name})', (tester) async {
      await _pumpPage(
        tester,
        inspectionOrigin: false,
        preferences: preferences,
        locale: locale,
        size: const Size(320, 900),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('normal bid card renders from dark semantic surface tokens', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      inspectionOrigin: false,
      preferences: preferences,
      theme: AppTheme.darkTheme,
    );

    final containers = tester.widgetList<Container>(
      find.ancestor(
        of: find.text(_workerName),
        matching: find.byType(Container),
      ),
    );
    final card = containers.firstWhere((container) {
      final decoration = container.decoration;
      return decoration is BoxDecoration &&
          decoration.color == AppSemanticColors.dark.surface;
    });
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.color, AppSemanticColors.dark.surface);
    expect(decoration.boxShadow, isNull);
    expect(tester.takeException(), isNull);
  });
}
