import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/domain/entities/cash_payment_confirmation_entity.dart';
import 'package:handygo_app/features/bookings/domain/repositories/booking_repository.dart';
import 'package:handygo_app/features/bookings/presentation/providers/booking_providers.dart';
import 'package:handygo_app/features/bookings/presentation/widgets/cash_payment_confirmation_card.dart';
import 'package:handygo_app/features/bookings/presentation/widgets/review_modal.dart';

import '../../support/l10n_test_app.dart';

const _bookingId = 'booking-1';

BookingEntity _booking({double? receivedAmount}) => BookingEntity(
  id: _bookingId,
  referenceId: '#ER-123456',
  serviceCategory: 'AC Technician',
  serviceEmoji: 'AC',
  status: BookingStatus.completed,
  urgency: BookingUrgency.normal,
  createdAt: DateTime(2026, 8, 20),
  lane: BookingLane.standard,
  finalPrice: 2500,
  receivedAmount: receivedAmount,
  expectedAmount: receivedAmount == null ? null : 2500,
  remainingAmount: receivedAmount == null ? null : 0,
  assignedWorker: const AssignedWorkerEntity(
    id: 'worker-1',
    firstName: 'Ali',
    lastName: 'Khan',
  ),
);

class _CashRepository implements BookingRepository {
  final List<int> submittedAmounts = <int>[];

  @override
  Future<Either<Failure, CashPaymentConfirmationEntity>> confirmCashPayment(
    String bookingId,
    int receivedCashTotal,
  ) async {
    submittedAmounts.add(receivedCashTotal);
    return Right(
      CashPaymentConfirmationEntity(
        settlementId: 'settlement-1',
        bookingId: bookingId,
        receivedCashTotal: receivedCashTotal,
        expectedTotal: 2500,
        shortfall: 0,
        recordedAt: DateTime.utc(2026, 8, 29),
        confirmationStatus: 'CONFIRMED',
        isCurrent: true,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PromptHarness extends ConsumerStatefulWidget {
  const _PromptHarness({super.key, required this.booking});

  final BookingEntity booking;

  @override
  ConsumerState<_PromptHarness> createState() => _PromptHarnessState();
}

class _PromptHarnessState extends ConsumerState<_PromptHarness> {
  void rebuildFromProviderEvent() => setState(() {});

  @override
  Widget build(BuildContext context) {
    scheduleAutomaticCashPaymentPrompt(context, ref, widget.booking);
    return const Scaffold(body: Center(child: Text('BOOKING SURFACE')));
  }
}

Future<_CashRepository> _pumpHarness(
  WidgetTester tester,
  BookingEntity booking, {
  GlobalKey<_PromptHarnessState>? key,
}) async {
  final repository = _CashRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [bookingRepositoryProvider.overrideWithValue(repository)],
      child: localizedApp(_PromptHarness(key: key, booking: booking)),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets(
    'COMPLETED outstanding auto-opens once across repeated rebuilds',
    (tester) async {
      final key = GlobalKey<_PromptHarnessState>();
      await _pumpHarness(tester, _booking(), key: key);

      expect(find.byType(CashPaymentConfirmationCard), findsOneWidget);
      key.currentState!.rebuildFromProviderEvent();
      key.currentState!.rebuildFromProviderEvent();
      await tester.pumpAndSettle();

      expect(find.byType(CashPaymentConfirmationCard), findsOneWidget);
    },
  );

  testWidgets('authoritatively settled booking never auto-opens', (
    tester,
  ) async {
    await _pumpHarness(tester, _booking(receivedAmount: 2500));

    expect(find.byType(CashPaymentConfirmationCard), findsNothing);
  });

  testWidgets(
    'shared modal submits existing provider and never overlaps review',
    (tester) async {
      final repository = await _pumpHarness(tester, _booking());

      expect(find.byType(ReviewModal), findsNothing);
      await tester.enterText(find.byType(TextFormField), '2500');
      await tester.tap(find.byKey(const Key('cash-payment-submit-button')));
      await tester.pumpAndSettle();

      expect(repository.submittedAmounts, [2500]);
      expect(find.text('Cash payment confirmed'), findsOneWidget);
      expect(find.byType(ReviewModal), findsNothing);

      await tester.tap(find.text('Continue to review'));
      await tester.pumpAndSettle();
      expect(find.byType(CashPaymentConfirmationCard), findsNothing);
    },
  );

  testWidgets('"Later" closes the prompt and it stays closed', (tester) async {
    // A customer with several unsettled bookings used to be locked out of the
    // app: the prompt refused the back button and the barrier, so the only way
    // forward was to pay every one of them. Closing it must be allowed, and
    // must not immediately reopen on the next provider rebuild.
    final key = GlobalKey<_PromptHarnessState>();
    await _pumpHarness(tester, _booking(), key: key);
    expect(find.byType(CashPaymentConfirmationCard), findsOneWidget);

    await tester.tap(find.byKey(const Key('cash-payment-later-button')));
    await tester.pumpAndSettle();
    expect(find.byType(CashPaymentConfirmationCard), findsNothing);

    key.currentState!.rebuildFromProviderEvent();
    key.currentState!.rebuildFromProviderEvent();
    await tester.pumpAndSettle();
    expect(find.byType(CashPaymentConfirmationCard), findsNothing);
  });
}
