import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/theme/app_semantic_colors.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/domain/entities/cash_payment_confirmation_entity.dart';
import 'package:handygo_app/features/bookings/domain/entities/inspection_report_entity.dart';
import 'package:handygo_app/features/bookings/presentation/pages/track_worker_page.dart';
import 'package:handygo_app/features/bookings/presentation/providers/booking_providers.dart';
import 'package:handygo_app/features/bookings/presentation/widgets/cash_payment_confirmation_card.dart';

import '../../support/l10n_test_app.dart';

/// Track Worker is part of the client's booking-detail experience, so
/// "Inspection report dekhein" must carry the SAME filled teal weight it has
/// on "Kaam ki tafseel" — not the outlined variant it used to inherit.
///
/// The treatment is not restated at either call site: it is the default of
/// the shared [ViewInspectionReportButton], so the two screens cannot drift.

const _bookingId = 'booking-1';

const _worker = AssignedWorkerEntity(
  id: 'worker-1',
  firstName: 'Ali',
  lastName: 'Khan',
  phone: '+923001234567',
);

BookingEntity _inspectionBooking({
  BookingStatus status = BookingStatus.inProgress,
}) => BookingEntity(
  id: _bookingId,
  referenceId: '#ER-123456',
  serviceCategory: 'AC Technician',
  serviceEmoji: '❄️',
  status: status,
  urgency: BookingUrgency.normal,
  createdAt: DateTime(2026, 8, 1),
  lane: BookingLane.inspection,
  assignedWorker: _worker,
  inspectionFeeSnapshot: 500,
);

final _report = InspectionReportEntity(
  id: 'report-1',
  bookingId: _bookingId,
  labourCost: 1500,
  partsNeeded: false,
  repairQuoteTotal: 1500,
  decisionStatus: InspectionDecisionStatus.pendingClientDecision,
  parts: const [],
  photos: const [],
  createdAt: DateTime(2026, 8, 18),
);

class _StubDetailNotifier extends BookingDetailNotifier {
  _StubDetailNotifier(this.booking);

  final BookingEntity booking;

  @override
  Future<BookingEntity> build(String arg) async => booking;
}

class _NoopCashPaymentPromptController implements CashPaymentPromptController {
  @override
  String? get activeBookingId => null;

  @override
  bool get isShowing => false;

  @override
  Future<void> get whenIdle => Future<void>.value();

  @override
  Future<CashPaymentConfirmationEntity?> showForBooking(
    BuildContext context,
    BookingEntity booking, {
    bool automatic = false,
  }) async => null;
}

Future<void> _pumpTrackWorker(
  WidgetTester tester,
  BookingEntity booking, {
  ThemeData? theme,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const SizedBox.shrink());

  final router = GoRouter(
    initialLocation: '/client/booking/$_bookingId/track',
    routes: [
      GoRoute(
        path: '/client/booking/:id/track',
        builder: (_, state) =>
            TrackWorkerPage(bookingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/client/booking/:id/inspection-report',
        builder: (_, _) => const Scaffold(body: Text('report-page')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bookingDetailProvider.overrideWith(() => _StubDetailNotifier(booking)),
        cashPaymentPromptControllerProvider.overrideWithValue(
          _NoopCashPaymentPromptController(),
        ),
        inspectionReportProvider(_bookingId).overrideWith((_) async => _report),
      ],
      child: localizedRouterApp(router, theme: theme ?? AppTheme.lightTheme),
    ),
  );
  await tester.pumpAndSettle();
}

/// `FilledButton.icon` builds a private subclass, so match on the supertype.
final _anyFilledButton = find.byWidgetPredicate((w) => w is FilledButton);
final _anyOutlinedButton = find.byWidgetPredicate((w) => w is OutlinedButton);

const _key = Key('view-inspection-report-button');

({Color? background, Color? foreground}) _fillOf(WidgetTester tester) {
  final button = tester.widget<FilledButton>(
    find.descendant(of: find.byKey(_key), matching: _anyFilledButton),
  );
  final style = button.style!;
  const states = <WidgetState>{};
  return (
    background: style.backgroundColor?.resolve(states),
    foreground: style.foregroundColor?.resolve(states),
  );
}

AppSemanticColors _colorsOf(WidgetTester tester) =>
    tester.element(find.byType(TrackWorkerPage)).semanticColors;

void main() {
  testWidgets('the report CTA is filled primary, never outlined', (
    tester,
  ) async {
    await _pumpTrackWorker(tester, _inspectionBooking());

    expect(find.byKey(_key), findsOneWidget);

    final colors = _colorsOf(tester);
    final fill = _fillOf(tester);

    expect(fill.background, colors.primary);
    expect(fill.foreground, colors.onPrimary);
    expect(
      find.descendant(of: find.byKey(_key), matching: _anyOutlinedButton),
      findsNothing,
      reason: 'Track Worker must not keep the outlined variant',
    );
  });

  testWidgets('resolves from the dark palette too — no baked-in literal', (
    tester,
  ) async {
    await _pumpTrackWorker(
      tester,
      _inspectionBooking(),
      theme: AppTheme.darkTheme,
    );

    final colors = _colorsOf(tester);
    final fill = _fillOf(tester);

    expect(fill.background, colors.primary);
    expect(fill.foreground, colors.onPrimary);
  });

  testWidgets('still navigates to the report page — behaviour unchanged', (
    tester,
  ) async {
    await _pumpTrackWorker(tester, _inspectionBooking());

    await tester.ensureVisible(find.byKey(_key));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_key));
    await tester.pumpAndSettle();

    expect(find.text('report-page'), findsOneWidget);
  });

  testWidgets('a non-inspection lane still offers no report CTA', (
    tester,
  ) async {
    await _pumpTrackWorker(
      tester,
      BookingEntity(
        id: _bookingId,
        referenceId: '#ER-123456',
        serviceCategory: 'Plumber',
        serviceEmoji: '🔧',
        status: BookingStatus.inProgress,
        urgency: BookingUrgency.normal,
        createdAt: DateTime(2026, 8, 1),
        lane: BookingLane.standard,
        assignedWorker: _worker,
      ),
    );

    expect(find.byKey(_key), findsNothing);
  });
}
