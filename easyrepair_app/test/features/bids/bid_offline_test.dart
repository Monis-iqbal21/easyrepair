import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/network/connectivity_service.dart';
import 'package:handygo_app/features/bids/domain/entities/bid_entity.dart';
import 'package:handygo_app/features/bids/domain/repositories/bid_repository.dart';
import 'package:handygo_app/features/bids/presentation/providers/bid_providers.dart';

/// New Jobs marketplace browsing is allowed offline (cached list), but
/// submitting a bid always requires a live connection — Flutter must never
/// pretend a bid succeeded while offline, and must never let a doomed
/// request reach the network in the first place.
class _FakeBidRepository implements BidRepository {
  int submitCalls = 0;

  @override
  Future<Either<Failure, BidEntity>> submitBid({
    required String bookingId,
    required double amount,
    String? message,
  }) async {
    submitCalls++;
    return Right(
      BidEntity(
        id: 'bid-1',
        bookingId: bookingId,
        workerProfileId: 'worker-1',
        amount: amount,
        status: BidStatus.pending,
        editCount: 0,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

void main() {
  tearDown(() => ConnectivityService.instance.debugIsOnline = true);

  test('submitting a bid while offline is blocked before ever reaching the '
      'repository — it never pretends success', () async {
    ConnectivityService.instance.debugIsOnline = false;
    final repo = _FakeBidRepository();
    final container = ProviderContainer(
      overrides: [bidRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    // Ensure the notifier's own async build() has settled before driving
    // it, so the error state submit() sets can't be raced/overwritten by
    // build()'s AsyncData(null) resolving afterwards.
    await container.read(submitBidProvider.future);

    await expectLater(
      container.read(submitBidProvider.notifier).submit(
            bookingId: 'booking-1',
            amount: 1500,
          ),
      throwsA(isA<OfflineActionBlockedFailure>()),
    );
    expect(repo.submitCalls, 0);
    expect(
      container.read(submitBidProvider).error,
      isA<OfflineActionBlockedFailure>(),
    );
  });

  test('once connectivity returns, submitting the same bid reaches the repository',
      () async {
    ConnectivityService.instance.debugIsOnline = false;
    final repo = _FakeBidRepository();
    final container = ProviderContainer(
      overrides: [bidRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await container.read(submitBidProvider.future);

    await expectLater(
      container
          .read(submitBidProvider.notifier)
          .submit(bookingId: 'booking-1', amount: 1500),
      throwsA(isA<OfflineActionBlockedFailure>()),
    );
    expect(repo.submitCalls, 0);

    ConnectivityService.instance.debugIsOnline = true;
    final bid = await container
        .read(submitBidProvider.notifier)
        .submit(bookingId: 'booking-1', amount: 1500);

    expect(repo.submitCalls, 1);
    expect(bid.bookingId, 'booking-1');
  });
}
