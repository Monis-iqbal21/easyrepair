import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/theme/app_semantic_colors.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';
import 'package:handygo_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/domain/entities/cash_payment_confirmation_entity.dart';
import 'package:handygo_app/features/bookings/domain/entities/inspection_report_entity.dart';
import 'package:handygo_app/features/bookings/presentation/pages/booking_detail_page.dart';
import 'package:handygo_app/features/bookings/presentation/providers/booking_providers.dart';
import 'package:handygo_app/features/bookings/presentation/widgets/cash_payment_confirmation_card.dart';
import 'package:handygo_app/features/complaints/domain/entities/complaint_entity.dart';
import 'package:handygo_app/features/complaints/presentation/providers/complaint_providers.dart';

import '../../support/l10n_test_app.dart';

/// The two decision buttons on Client "Kaam ki tafseel".
///
/// Both are FILLED, never outlined: cancelling is the one destructive thing
/// the client can do here and must read red at a glance, and the inspection
/// report is the main thing to do next on an inspection booking, so it
/// carries teal primary weight. Every colour asserted here is read back out
/// of [AppSemanticColors] — a literal creeping into either button fails this
/// test rather than shipping.

const _bookingId = 'booking-1';

BookingEntity _booking({
  BookingLane lane = BookingLane.inspection,
  BookingStatus status = BookingStatus.pending,
}) => BookingEntity(
  id: _bookingId,
  referenceId: '#ER-123456',
  serviceCategory: 'AC Technician',
  serviceEmoji: '❄️',
  status: status,
  urgency: BookingUrgency.normal,
  timeSlot: TimeSlot.afternoon,
  scheduledDate: DateTime(2026, 8, 17),
  createdAt: DateTime(2026, 8, 1),
  address: 'House 12, Street 4',
  city: 'Lahore',
  lane: lane,
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

class _StubComplaintNotifier extends BookingComplaintNotifier {
  @override
  Future<ComplaintEntity?> build(String bookingId) async => null;
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

class _StubAuthNotifier extends AuthStateNotifier {
  @override
  Future<UserEntity?> build() async => UserEntity(
    id: 'user-1',
    phone: '+923000000000',
    role: 'CLIENT',
    firstName: 'Sara',
    lastName: 'Client',
  );
}

Future<void> _pumpDetail(
  WidgetTester tester,
  BookingEntity booking, {
  AppLocale locale = AppLocale.english,
  ThemeData? theme,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const SizedBox.shrink());

  final router = GoRouter(
    initialLocation: '/client/booking/$_bookingId',
    routes: [
      GoRoute(
        path: '/client/booking/:id',
        builder: (_, state) =>
            BookingDetailPage(bookingId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/client/jobs', builder: (_, _) => const SizedBox()),
      GoRoute(
        path: '/client/booking/:id/inspection-report',
        builder: (_, _) => const Scaffold(body: Text('report-page')),
      ),
      GoRoute(path: '/client/post-job', builder: (_, _) => const SizedBox()),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bookingDetailProvider.overrideWith(() => _StubDetailNotifier(booking)),
        cashPaymentPromptControllerProvider.overrideWithValue(
          _NoopCashPaymentPromptController(),
        ),
        bookingComplaintProvider.overrideWith(_StubComplaintNotifier.new),
        inspectionReportProvider(_bookingId).overrideWith((_) async => _report),
        authStateProvider.overrideWith(_StubAuthNotifier.new),
      ],
      child: localizedRouterApp(
        router,
        locale: locale,
        theme: theme ?? AppTheme.lightTheme,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The resolved background/foreground of the [FilledButton] under [key].
///
/// Throws outright if that key resolves to anything but a [FilledButton] — an
/// outlined button has no background to read, which is precisely the
/// regression being guarded.
/// `FilledButton.icon` builds a private subclass, and `find.byType` matches
/// the exact runtime type only — hence the predicate finders here.
final _anyFilledButton = find.byWidgetPredicate((w) => w is FilledButton);
final _anyOutlinedButton = find.byWidgetPredicate((w) => w is OutlinedButton);

({Color? background, Color? foreground}) _fillOf(
  WidgetTester tester,
  Key key,
) {
  final button = tester.widget<FilledButton>(
    find.descendant(of: find.byKey(key), matching: _anyFilledButton),
  );
  final style = button.style!;
  const states = <WidgetState>{};
  return (
    background: style.backgroundColor?.resolve(states),
    foreground: style.foregroundColor?.resolve(states),
  );
}

AppSemanticColors _colorsOf(WidgetTester tester) =>
    tester.element(find.byType(BookingDetailPage)).semanticColors;

void main() {
  group('the cancel button is a filled RED button', () {
    testWidgets('renders on error / onPrimary, never as an outline', (
      tester,
    ) async {
      await _pumpDetail(tester, _booking(status: BookingStatus.pending));

      const key = Key('cancel-booking-button');
      expect(find.byKey(key), findsOneWidget);

      final colors = _colorsOf(tester);
      final fill = _fillOf(tester, key);

      expect(fill.background, colors.error);
      expect(fill.foreground, colors.onPrimary);
      expect(
        find.descendant(of: find.byKey(key), matching: _anyOutlinedButton),
        findsNothing,
        reason: 'cancel must be fully filled, not outlined',
      );
    });

    testWidgets('stays tappable on an ACCEPTED booking — eligibility and the '
        'action are unchanged', (tester) async {
      await _pumpDetail(tester, _booking(status: BookingStatus.accepted));

      const key = Key('cancel-booking-button');
      final button = tester.widget<FilledButton>(
        find.descendant(of: find.byKey(key), matching: _anyFilledButton),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('resolves from the dark palette too — no baked-in literal', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        _booking(status: BookingStatus.pending),
        theme: AppTheme.darkTheme,
      );

      final colors = _colorsOf(tester);
      final fill = _fillOf(tester, const Key('cancel-booking-button'));

      expect(fill.background, colors.error);
      expect(fill.foreground, colors.onPrimary);
    });
  });

  group('the inspection-report button is a filled TEAL button', () {
    testWidgets('renders on primary / onPrimary on the client detail page', (
      tester,
    ) async {
      await _pumpDetail(tester, _booking(status: BookingStatus.completed));

      const key = Key('view-inspection-report-button');
      expect(find.byKey(key), findsOneWidget);

      final colors = _colorsOf(tester);
      final fill = _fillOf(tester, key);

      expect(fill.background, colors.primary);
      expect(fill.foreground, colors.onPrimary);
      expect(
        find.descendant(of: find.byKey(key), matching: _anyOutlinedButton),
        findsNothing,
        reason: 'the report CTA must be fully filled, not outlined',
      );
    });

    testWidgets('still navigates to the report page', (tester) async {
      await _pumpDetail(tester, _booking(status: BookingStatus.completed));

      await tester.tap(find.byKey(const Key('view-inspection-report-button')));
      await tester.pumpAndSettle();

      expect(find.text('report-page'), findsOneWidget);
    });
  });

  group('locked Roman Urdu copy', () {
    testWidgets('the detail page never says "Muntakhab"', (tester) async {
      await _pumpDetail(
        tester,
        _booking(lane: BookingLane.standard, status: BookingStatus.pending),
        locale: AppLocale.romanUrdu,
      );

      expect(find.textContaining('Muntakhab'), findsNothing);
      expect(find.textContaining('muntakhab'), findsNothing);
    });
  });
}
