import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/bid_remote_datasource.dart';
import '../../data/repositories/bid_repository_impl.dart';
import '../../domain/entities/bid_entity.dart';
import '../../domain/repositories/bid_repository.dart';

// ── Infrastructure ─────────────────────────────────────────────────────────────

final bidRepositoryProvider = Provider<BidRepository>((ref) {
  return BidRepositoryImpl(ref.watch(bidRemoteDataSourceProvider));
});

// ── Worker: fetch own bid for a booking ───────────────────────────────────────

final myBidProvider = FutureProvider.autoDispose
    .family<BidEntity?, String>((ref, bookingId) async {
  final result = await ref.read(bidRepositoryProvider).getMyBid(bookingId);
  return result.fold((f) => throw f, (bid) => bid);
});

// ── Worker: submit bid ────────────────────────────────────────────────────────

class SubmitBidNotifier extends AsyncNotifier<BidEntity?> {
  @override
  Future<BidEntity?> build() async => null;

  Future<BidEntity> submit({
    required String bookingId,
    required double amount,
    String? message,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(bidRepositoryProvider).submitBid(
          bookingId: bookingId,
          amount: amount,
          message: message,
        );
    return result.fold(
      (f) {
        state = AsyncError(f, StackTrace.current);
        throw f;
      },
      (bid) {
        state = AsyncData(bid);
        // Refresh own-bid and live feed.
        ref.invalidate(myBidProvider(bookingId));
        ref.invalidate(jobBidsFeedProvider(bookingId));
        return bid;
      },
    );
  }
}

final submitBidProvider =
    AsyncNotifierProvider<SubmitBidNotifier, BidEntity?>(SubmitBidNotifier.new);

// ── Worker: edit bid ──────────────────────────────────────────────────────────

class EditBidNotifier extends AsyncNotifier<BidEntity?> {
  @override
  Future<BidEntity?> build() async => null;

  Future<BidEntity> edit({
    required String bidId,
    required String bookingId,
    required double amount,
    String? message,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(bidRepositoryProvider).editBid(
          bidId: bidId,
          amount: amount,
          message: message,
        );
    return result.fold(
      (f) {
        state = AsyncError(f, StackTrace.current);
        throw f;
      },
      (bid) {
        state = AsyncData(bid);
        ref.invalidate(myBidProvider(bookingId));
        return bid;
      },
    );
  }
}

final editBidProvider =
    AsyncNotifierProvider<EditBidNotifier, BidEntity?>(EditBidNotifier.new);

// ── Client: fetch all bids for a booking ──────────────────────────────────────

final bookingBidsProvider = FutureProvider.autoDispose
    .family<List<BidWithWorkerEntity>, String>((ref, bookingId) async {
  final result =
      await ref.read(bidRepositoryProvider).getBidsForBooking(bookingId);
  return result.fold((f) => throw f, (bids) => bids);
});

// ── Worker: live bid feed for an available job ────────────────────────────────
// Not autoDispose — prevents repeated re-fetch loops on error.

final jobBidsFeedProvider = FutureProvider
    .family<List<BidWithWorkerEntity>, String>((ref, bookingId) async {
  final result =
      await ref.read(bidRepositoryProvider).getBidsForBooking(bookingId);
  return result.fold((f) => throw f, (bids) => bids);
});

// ── Client: accept a bid ──────────────────────────────────────────────────────

class AcceptBidNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> accept({
    required String bidId,
    required String bookingId,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(bidRepositoryProvider).acceptBid(bidId);
    result.fold(
      (f) {
        state = AsyncError(f, StackTrace.current);
        throw f;
      },
      (_) {
        state = const AsyncData(null);
        // Refresh bids list so accepted state reflects immediately.
        ref.invalidate(bookingBidsProvider(bookingId));
      },
    );
  }
}

final acceptBidProvider =
    AsyncNotifierProvider<AcceptBidNotifier, void>(AcceptBidNotifier.new);
