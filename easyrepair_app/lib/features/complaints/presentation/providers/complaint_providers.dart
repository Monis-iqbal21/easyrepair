import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../data/datasources/complaint_remote_datasource.dart';
import '../../data/repositories/complaint_repository_impl.dart';
import '../../domain/entities/complaint_entity.dart';
import '../../domain/repositories/complaint_repository.dart';

final complaintRemoteDataSourceProvider = Provider<ComplaintRemoteDataSource>(
  (ref) => ComplaintRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final complaintRepositoryProvider = Provider<ComplaintRepository>(
  (ref) => ComplaintRepositoryImpl(
    ref.watch(complaintRemoteDataSourceProvider),
  ),
);

/// The client's report for ONE booking.
///
/// `autoDispose` — matching [inspectionReportProvider], the other async
/// per-booking provider Booking Detail watches — because complaint status is
/// changed by Admin, not by this app: a keep-alive cache would pin whatever
/// status was fetched the first time the page was opened and never let go,
/// which is exactly how "Your report" stayed on *Pending* for the rest of the
/// session after Admin resolved or closed it. Disposing when Booking Detail
/// (and Report Problem) are both off-screen means reopening either one always
/// refetches the authoritative server state — so correctness never depends on
/// a push actually being delivered.
class BookingComplaintNotifier
    extends AutoDisposeFamilyAsyncNotifier<ComplaintEntity?, String> {
  @override
  Future<ComplaintEntity?> build(String bookingId) async {
    final result = await ref.read(complaintRepositoryProvider).getForBooking(
          bookingId,
        );
    return result.fold((failure) => throw failure, (complaint) => complaint);
  }

  Future<ComplaintEntity> submit({
    required Set<ComplaintIssueType> issueTypes,
    String? otherText,
  }) async {
    final existing = state.valueOrNull;
    if (existing != null) return existing;

    final offline = offlineActionGuard();
    if (offline != null) throw offline;

    state = const AsyncLoading();
    final result = await ref.read(complaintRepositoryProvider).createForBooking(
          bookingId: arg,
          issueTypes: issueTypes,
          otherText: otherText,
        );

    return result.fold((failure) async {
      if (failure is ConflictFailure) {
        final lookup = await ref
            .read(complaintRepositoryProvider)
            .getForBooking(arg);
        return lookup.fold((lookupFailure) {
          state = AsyncError(lookupFailure, StackTrace.current);
          throw lookupFailure;
        }, (complaint) {
          if (complaint == null) {
            state = AsyncError(failure, StackTrace.current);
            throw failure;
          }
          state = AsyncData(complaint);
          return complaint;
        });
      }
      state = AsyncError(failure, StackTrace.current);
      throw failure;
    }, (complaint) {
      state = AsyncData(complaint);
      return complaint;
    });
  }

  Future<ComplaintEntity> requestHuman() async {
    final complaint = state.valueOrNull;
    if (complaint == null) {
      throw const ValidationFailure('');
    }
    if (complaint.humanRequested) return complaint;

    final offline = offlineActionGuard();
    if (offline != null) throw offline;

    final result = await ref
        .read(complaintRepositoryProvider)
        .requestHuman(complaint.id);
    return result.fold((failure) => throw failure, (updated) {
      state = AsyncData(updated);
      return updated;
    });
  }
}

final bookingComplaintProvider = AsyncNotifierProvider.autoDispose
    .family<BookingComplaintNotifier, ComplaintEntity?, String>(
  BookingComplaintNotifier.new,
);
