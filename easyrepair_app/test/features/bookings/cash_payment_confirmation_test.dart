import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/features/bookings/data/models/cash_payment_confirmation_model.dart';
import 'package:handygo_app/features/bookings/domain/entities/cash_payment_confirmation_entity.dart';
import 'package:handygo_app/features/bookings/domain/repositories/booking_repository.dart';
import 'package:handygo_app/features/bookings/presentation/providers/booking_providers.dart';

void main() {
  const bookingId = 'booking-1';

  test('parses the complete client-safe settlement response', () {
    final model = CashPaymentConfirmationModel.fromJson({
      'settlementId': 'settlement-1',
      'bookingId': bookingId,
      'receivedCashTotal': 4500,
      'expectedTotal': 5000,
      'shortfall': 500,
      'recordedAt': '2026-08-22T00:00:00.000Z',
      'confirmationStatus': 'CONFIRMED',
      'isCurrent': true,
    });

    expect(model.toEntity().settlementId, 'settlement-1');
    expect(model.toEntity().receivedCashTotal, 4500);
    expect(model.toEntity().shortfall, 500);
    expect(model.toEntity().recordedAt, DateTime.utc(2026, 8, 22));
  });

  for (final amount in [5000, 2500, 0]) {
    test('provider forwards and retains cash amount $amount unchanged', () async {
      final repository = _CashRepository();
      final container = ProviderContainer(overrides: [
        bookingRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);

      final result = await container
          .read(cashPaymentConfirmationProvider(bookingId).notifier)
          .confirm(amount);

      expect(repository.receivedAmounts, [amount]);
      expect(result.receivedCashTotal, amount);
      expect(
        container
            .read(cashPaymentConfirmationProvider(bookingId))
            .valueOrNull
            ?.settlementId,
        'settlement-$amount',
      );
    });
  }

  test('same-amount idempotent response remains a success', () async {
    final repository = _CashRepository();
    final container = ProviderContainer(overrides: [
      bookingRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    final notifier =
        container.read(cashPaymentConfirmationProvider(bookingId).notifier);

    final first = await notifier.confirm(4500);
    final retry = await notifier.confirm(4500);

    expect(first.settlementId, retry.settlementId);
    expect(repository.receivedAmounts, [4500, 4500]);
    expect(container.read(cashPaymentConfirmationProvider(bookingId)).hasError,
        isFalse);
  });

  test('409 remains a controlled conflict failure', () async {
    final repository = _CashRepository(conflict: true);
    final container = ProviderContainer(overrides: [
      bookingRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(cashPaymentConfirmationProvider(bookingId).notifier)
          .confirm(4000),
      throwsA(isA<ConflictFailure>()),
    );
    final error =
        container.read(cashPaymentConfirmationProvider(bookingId)).error;
    expect((error as Failure).code, FailureCode.conflict);
  });
}

class _CashRepository implements BookingRepository {
  _CashRepository({this.conflict = false});

  final bool conflict;
  final List<int> receivedAmounts = [];

  @override
  Future<Either<Failure, CashPaymentConfirmationEntity>> confirmCashPayment(
    String bookingId,
    int receivedCashTotal,
  ) async {
    receivedAmounts.add(receivedCashTotal);
    if (conflict) {
      return const Left(ConflictFailure('already confirmed'));
    }
    return Right(CashPaymentConfirmationEntity(
      settlementId: 'settlement-$receivedCashTotal',
      bookingId: bookingId,
      receivedCashTotal: receivedCashTotal,
      expectedTotal: 5000,
      shortfall: 0,
      recordedAt: DateTime.utc(2026, 8, 22),
      confirmationStatus: 'CONFIRMED',
      isCurrent: true,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
