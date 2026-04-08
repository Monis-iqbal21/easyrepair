import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/datasources/booking_remote_datasource.dart';
import '../../data/repositories/booking_repository_impl.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/create_booking_request.dart';
import '../../domain/entities/nearby_worker_entity.dart';
import '../../domain/entities/update_booking_request.dart';
import '../../domain/repositories/booking_repository.dart';
import '../../domain/usecases/cancel_booking_usecase.dart';
import '../../domain/usecases/create_booking_usecase.dart';
import '../../domain/usecases/get_client_bookings_usecase.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final bookingRemoteDataSourceProvider = Provider<BookingRemoteDataSource>((
  ref,
) {
  return BookingRemoteDataSourceImpl(ref.watch(dioProvider));
});

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepositoryImpl(ref.watch(bookingRemoteDataSourceProvider));
});

// ── Use cases ─────────────────────────────────────────────────────────────────

final createBookingUseCaseProvider = Provider<CreateBookingUseCase>((ref) {
  return CreateBookingUseCase(ref.watch(bookingRepositoryProvider));
});

final getClientBookingsUseCaseProvider = Provider<GetClientBookingsUseCase>((
  ref,
) {
  return GetClientBookingsUseCase(ref.watch(bookingRepositoryProvider));
});

final cancelBookingUseCaseProvider = Provider<CancelBookingUseCase>((ref) {
  return CancelBookingUseCase(ref.watch(bookingRepositoryProvider));
});

// ── Bookings list notifier ────────────────────────────────────────────────────

class BookingsNotifier extends AsyncNotifier<List<BookingEntity>> {
  @override
  Future<List<BookingEntity>> build() => _fetch();

  Future<List<BookingEntity>> _fetch() async {
    final result = await ref.read(getClientBookingsUseCaseProvider).call();
    return result.fold((failure) => throw failure, (bookings) => bookings);
  }

  /// Full network reload — only call when truly needed (e.g. first load / pull-
  /// to-refresh). Sets AsyncLoading which resets scroll position.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Replace a single booking in the list without touching AsyncLoading.
  /// Scroll position is preserved because the list widget is not rebuilt from
  /// scratch — only the changed item re-renders.
  void patchBooking(BookingEntity updated) {
    final current = state.valueOrNull;
    if (current == null) return;
    final idx = current.indexWhere((b) => b.id == updated.id);
    if (idx == -1) return; // not in list yet — ignore (create flow handles this)
    final next = List<BookingEntity>.from(current);
    next[idx] = updated;
    state = AsyncData(next);
  }

  /// Prepend a newly created booking to the front of the list without a reload.
  void prependBooking(BookingEntity booking) {
    final current = state.valueOrNull ?? [];
    state = AsyncData([booking, ...current]);
  }

  /// Cancel a booking: patches the list item and syncs the detail provider.
  Future<void> cancelBooking(String bookingId) async {
    final result = await ref.read(cancelBookingUseCaseProvider).call(bookingId);
    result.fold((failure) => throw failure, (updated) {
      patchBooking(updated);
      // Sync detail page if it is alive.
      ref.read(bookingDetailProvider(bookingId).notifier).push(updated);
    });
  }
}

final bookingsNotifierProvider =
    AsyncNotifierProvider<BookingsNotifier, List<BookingEntity>>(
      BookingsNotifier.new,
    );

// ── Booking detail notifier ───────────────────────────────────────────────────
//
// Converted from FutureProvider.family → AsyncNotifierProvider.family so that
// mutation notifiers can call push() to update the cached state in-place
// without a network round-trip or a loading-spinner flash.
//
// NOT autoDispose: keeps the cache alive so push() from a mutation notifier
// always finds the provider ready, and navigating back to the same detail page
// is instant.

class BookingDetailNotifier
    extends FamilyAsyncNotifier<BookingEntity, String> {
  @override
  Future<BookingEntity> build(String arg) async {
    final result =
        await ref.read(bookingRepositoryProvider).getBookingById(arg);
    return result.fold((f) => throw f, (b) => b);
  }

  /// Push a fresh booking directly into state.
  /// Called by mutation notifiers after a successful API call so the detail
  /// page reflects the new status immediately — no extra network call needed.
  void push(BookingEntity updated) {
    state = AsyncData(updated);
  }
}

final bookingDetailProvider =
    AsyncNotifierProvider.family<BookingDetailNotifier, BookingEntity, String>(
  BookingDetailNotifier.new,
);

// ── Create booking notifier ───────────────────────────────────────────────────

class CreateBookingNotifier extends AsyncNotifier<BookingEntity?> {
  @override
  Future<BookingEntity?> build() async => null;

  Future<BookingEntity> submit(CreateBookingRequest request) async {
    state = const AsyncLoading();
    final result = await ref.read(createBookingUseCaseProvider).call(request);

    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        throw failure;
      },
      (booking) {
        state = AsyncData(booking);
        // Prepend the new booking to the list without a full reload.
        ref.read(bookingsNotifierProvider.notifier).prependBooking(booking);
        return booking;
      },
    );
  }
}

final createBookingNotifierProvider =
    AsyncNotifierProvider<CreateBookingNotifier, BookingEntity?>(
      CreateBookingNotifier.new,
    );

// ── Filter state ──────────────────────────────────────────────────────────────

enum SortOrder { newest, oldest }

class BookingFilter {
  final BookingTab activeTab;
  final BookingUrgency? urgency;
  final SortOrder sortOrder;
  final bool? hasWorker;
  final String searchQuery;

  const BookingFilter({
    this.activeTab = BookingTab.all,
    this.urgency,
    this.sortOrder = SortOrder.newest,
    this.hasWorker,
    this.searchQuery = '',
  });

  BookingFilter copyWith({
    BookingTab? activeTab,
    Object? urgency = _sentinel,
    SortOrder? sortOrder,
    Object? hasWorker = _sentinel,
    String? searchQuery,
  }) {
    return BookingFilter(
      activeTab: activeTab ?? this.activeTab,
      urgency: urgency == _sentinel ? this.urgency : urgency as BookingUrgency?,
      sortOrder: sortOrder ?? this.sortOrder,
      hasWorker: hasWorker == _sentinel ? this.hasWorker : hasWorker as bool?,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  bool get hasActiveFilters =>
      urgency != null || hasWorker != null || sortOrder != SortOrder.newest;
}

const _sentinel = Object();

class BookingFilterNotifier extends Notifier<BookingFilter> {
  @override
  BookingFilter build() => const BookingFilter();

  void setTab(BookingTab tab) => state = state.copyWith(activeTab: tab);

  void setSearchQuery(String query) =>
      state = state.copyWith(searchQuery: query);

  void applyFilters({
    BookingUrgency? urgency,
    SortOrder? sortOrder,
    bool? hasWorker,
  }) {
    state = state.copyWith(
      urgency: urgency,
      sortOrder: sortOrder ?? state.sortOrder,
      hasWorker: hasWorker,
    );
  }

  void resetFilters() {
    state = state.copyWith(
      urgency: null,
      sortOrder: SortOrder.newest,
      hasWorker: null,
    );
  }
}

final bookingFilterProvider =
    NotifierProvider<BookingFilterNotifier, BookingFilter>(
      BookingFilterNotifier.new,
    );

// ── Update booking notifier ───────────────────────────────────────────────────

class UpdateBookingNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<BookingEntity> submitUpdate(UpdateBookingRequest request) async {
    state = const AsyncLoading();
    final result = await ref
        .read(bookingRepositoryProvider)
        .updateBooking(request);
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        throw failure;
      },
      (updated) {
        state = const AsyncData(null);
        // Patch the list item in-place (no scroll jump) and sync the detail.
        ref.read(bookingsNotifierProvider.notifier).patchBooking(updated);
        ref
            .read(bookingDetailProvider(request.bookingId).notifier)
            .push(updated);
        return updated;
      },
    );
  }
}

final updateBookingNotifierProvider =
    AsyncNotifierProvider<UpdateBookingNotifier, void>(
      UpdateBookingNotifier.new,
    );

// ── Attachment upload notifier ────────────────────────────────────────────────

class AttachmentUploadNotifier extends AsyncNotifier<BookingAttachmentEntity?> {
  @override
  Future<BookingAttachmentEntity?> build() async => null;

  Future<BookingAttachmentEntity> upload(
    String bookingId,
    File file,
    String mimeType,
  ) async {
    state = const AsyncLoading();
    final result = await ref
        .read(bookingRepositoryProvider)
        .uploadAttachment(bookingId, file, mimeType);
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        throw failure;
      },
      (attachment) {
        state = AsyncData(attachment);
        return attachment;
      },
    );
  }
}

final attachmentUploadNotifierProvider =
    AsyncNotifierProvider<AttachmentUploadNotifier, BookingAttachmentEntity?>(
      AttachmentUploadNotifier.new,
    );

// ── Review notifier ───────────────────────────────────────────────────────────

class ReviewNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<BookingEntity> submit(ReviewRequest request) async {
    state = const AsyncLoading();
    final result = await ref
        .read(bookingRepositoryProvider)
        .submitReview(request);
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        throw failure;
      },
      (updated) {
        state = const AsyncData(null);
        ref.read(bookingsNotifierProvider.notifier).patchBooking(updated);
        ref
            .read(bookingDetailProvider(request.bookingId).notifier)
            .push(updated);
        return updated;
      },
    );
  }
}

final reviewNotifierProvider = AsyncNotifierProvider<ReviewNotifier, void>(
  ReviewNotifier.new,
);

// ── Filtered + searched bookings ─────────────────────────────────────────────

final filteredBookingsProvider = Provider<List<BookingEntity>>((ref) {
  final bookingsAsync = ref.watch(bookingsNotifierProvider);
  final filter = ref.watch(bookingFilterProvider);

  final all = bookingsAsync.valueOrNull ?? [];

  var result = all.where((b) {
    if (filter.activeTab != BookingTab.all &&
        b.status.tab != filter.activeTab) {
      return false;
    }
    if (filter.urgency != null && b.urgency != filter.urgency) return false;
    if (filter.hasWorker == true && b.assignedWorker == null) return false;
    if (filter.hasWorker == false && b.assignedWorker != null) return false;

    final q = filter.searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      final haystack = [
        b.serviceCategory,
        b.title ?? '',
        b.referenceId,
        b.assignedWorker?.fullName ?? '',
      ].join(' ').toLowerCase();
      if (!haystack.contains(q)) return false;
    }
    return true;
  }).toList();

  result.sort(
    (a, b) => filter.sortOrder == SortOrder.newest
        ? b.createdAt.compareTo(a.createdAt)
        : a.createdAt.compareTo(b.createdAt),
  );

  return result;
});

// ── Nearby workers progressive state ─────────────────────────────────────────

/// Immutable snapshot of the live nearby-workers pool.
class NearbyWorkersState {
  final List<NearbyWorkerEntity> workers;

  /// True while radius expansion is actively in flight.
  final bool isExpanding;

  /// Largest radius successfully searched so far (km).
  final double searchedRadiusKm;

  /// True when the target pool size was reached at the current radius.
  final bool searchCompleted;

  /// Non-null only when the very first request failed (no workers shown yet).
  final Object? error;

  const NearbyWorkersState({
    this.workers = const [],
    this.isExpanding = true,
    this.searchedRadiusKm = 0,
    this.searchCompleted = false,
    this.error,
  });

  bool get hasError => error != null;

  NearbyWorkersState copyWith({
    List<NearbyWorkerEntity>? workers,
    bool? isExpanding,
    double? searchedRadiusKm,
    bool? searchCompleted,
    Object? error,
  }) {
    return NearbyWorkersState(
      workers: workers ?? this.workers,
      isExpanding: isExpanding ?? this.isExpanding,
      searchedRadiusKm: searchedRadiusKm ?? this.searchedRadiusKm,
      searchCompleted: searchCompleted ?? this.searchCompleted,
      error: error ?? this.error,
    );
  }
}

/// Live nearby-workers pool notifier.
///
/// Algorithm:
/// 1. On build, walk the radius ladder [3, 5, 8, 10, 15, 20] km one step at
///    a time, publishing results immediately after each response.
/// 2. Stop expansion as soon as 4 distinct workers are found.
/// 3. After expansion stops, start a 3-second periodic recheck.
/// 4. On each recheck, fetch workers at the last searched radius (reflects
///    current online/available state).
/// 5. If the fresh count drops below 4 and there is a larger radius to search,
///    resume expansion from that next radius.
/// 6. Workers are deduplicated by id; sorted by distance then rating.
class NearbyWorkersNotifier
    extends AutoDisposeFamilyNotifier<NearbyWorkersState, String> {
  static const _radii = [3.0, 5.0, 8.0, 10.0, 15.0, 20.0];
  static const _targetPool = 4;
  static const _recheckInterval = Duration(seconds: 3);

  Timer? _recheckTimer;
  bool _expansionInProgress = false;
  bool _recheckInProgress = false;
  bool _disposed = false;

  // Tracks the last successfully searched radius.
  double _lastSearchedRadiusKm = 0;

  // Accumulated worker pool (id → entity), used during expansion steps.
  final Map<String, NearbyWorkerEntity> _poolMap = {};

  @override
  NearbyWorkersState build(String arg) {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _recheckTimer?.cancel();
    });
    _startExpansion(arg, fromIndex: 0);
    return const NearbyWorkersState();
  }

  // ── Expansion ────────────────────────────────────────────────────────────────

  /// Walks the radius ladder starting at [fromIndex].
  /// [_poolMap] must already contain any workers carried forward from a recheck.
  Future<void> _startExpansion(
    String bookingId, {
    required int fromIndex,
  }) async {
    if (_expansionInProgress) return;
    _expansionInProgress = true;
    _recheckTimer?.cancel(); // pause recheck while expanding

    for (int i = fromIndex; i < _radii.length; i++) {
      if (_disposed) {
        _expansionInProgress = false;
        return;
      }

      final radiusKm = _radii[i];

      final result = await ref
          .read(bookingRepositoryProvider)
          .getNearbyWorkers(bookingId, radiusKm: radiusKm);

      if (_disposed) {
        _expansionInProgress = false;
        return;
      }

      bool shouldStop = false;

      result.fold(
        (failure) {
          if (_poolMap.isEmpty) {
            state = NearbyWorkersState(
              isExpanding: false,
              searchedRadiusKm: radiusKm,
              error: failure,
            );
          } else {
            state = state.copyWith(
              isExpanding: false,
              searchedRadiusKm: radiusKm,
            );
          }
          shouldStop = true;
        },
        (res) {
          // Merge; never overwrite (distance is invariant for the same worker).
          for (final w in res.workers) {
            _poolMap.putIfAbsent(w.id, () => w);
          }

          _lastSearchedRadiusKm = radiusKm;
          final isLast = i == _radii.length - 1;
          final reachedTarget = _poolMap.length >= _targetPool;

          state = NearbyWorkersState(
            workers: _sortedPool(),
            isExpanding: !reachedTarget && !isLast,
            searchedRadiusKm: radiusKm,
            searchCompleted: reachedTarget,
          );

          if (reachedTarget || isLast) shouldStop = true;
        },
      );

      if (shouldStop) break;
    }

    _expansionInProgress = false;
    _startRecheckTimer(bookingId);
  }

  // ── Recheck ──────────────────────────────────────────────────────────────────

  void _startRecheckTimer(String bookingId) {
    _recheckTimer?.cancel();
    _recheckTimer = Timer.periodic(
      _recheckInterval,
      (_) => _recheck(bookingId),
    );
  }

  Future<void> _recheck(String bookingId) async {
    if (_disposed || _expansionInProgress || _recheckInProgress) return;
    _recheckInProgress = true;

    try {
      final radius = _lastSearchedRadiusKm > 0
          ? _lastSearchedRadiusKm
          : _radii.first;

      final result = await ref
          .read(bookingRepositoryProvider)
          .getNearbyWorkers(bookingId, radiusKm: radius);

      if (_disposed) return;

      result.fold(
        (_) {}, // silently ignore transient recheck errors
        (freshResult) {
          final freshMap = <String, NearbyWorkerEntity>{
            for (final w in freshResult.workers) w.id: w,
          };

          if (freshMap.length < _targetPool) {
            // Pool dropped — try to resume expansion from the next radius.
            final nextIndex = _radii.indexWhere(
              (r) => r > _lastSearchedRadiusKm,
            );

            if (nextIndex != -1) {
              // Replace pool with fresh workers and resume outward search.
              _poolMap
                ..clear()
                ..addAll(freshMap);

              state = NearbyWorkersState(
                workers: _sortedFrom(freshMap),
                isExpanding: true,
                searchedRadiusKm: _lastSearchedRadiusKm,
                searchCompleted: false,
              );

              _startExpansion(bookingId, fromIndex: nextIndex);
            } else {
              // Already at max radius — update with what's available.
              _poolMap
                ..clear()
                ..addAll(freshMap);
              state = NearbyWorkersState(
                workers: _sortedFrom(freshMap),
                isExpanding: false,
                searchedRadiusKm: _lastSearchedRadiusKm,
                searchCompleted: false,
              );
            }
          } else {
            // Pool is healthy — refresh the list with live data.
            _poolMap
              ..clear()
              ..addAll(freshMap);
            state = NearbyWorkersState(
              workers: _sortedFrom(freshMap),
              isExpanding: false,
              searchedRadiusKm: _lastSearchedRadiusKm,
              searchCompleted: true,
            );
          }
        },
      );
    } finally {
      _recheckInProgress = false;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  List<NearbyWorkerEntity> _sortedPool() => _sortedFrom(_poolMap);

  List<NearbyWorkerEntity> _sortedFrom(Map<String, NearbyWorkerEntity> map) {
    return List<NearbyWorkerEntity>.from(map.values)..sort((a, b) {
      final dc = a.distanceKm.compareTo(b.distanceKm);
      return dc != 0 ? dc : b.rating.compareTo(a.rating);
    });
  }
}

final nearbyWorkersNotifierProvider = NotifierProvider.autoDispose
    .family<NearbyWorkersNotifier, NearbyWorkersState, String>(
      NearbyWorkersNotifier.new,
    );

// ── Assign worker notifier ────────────────────────────────────────────────────

class AssignWorkerNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> assign(String bookingId, String workerProfileId) async {
    state = const AsyncLoading();
    final result = await ref
        .read(bookingRepositoryProvider)
        .assignWorker(bookingId, workerProfileId);
    result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        throw failure;
      },
      (updated) {
        state = const AsyncData(null);
        // Patch the list item in-place (no scroll jump).
        ref.read(bookingsNotifierProvider.notifier).patchBooking(updated);
        // Sync the detail page without a network round-trip.
        ref.read(bookingDetailProvider(bookingId).notifier).push(updated);
        // The nearby-workers sheet is no longer valid after assignment.
        ref.invalidate(nearbyWorkersNotifierProvider(bookingId));
      },
    );
  }
}

final assignWorkerNotifierProvider =
    AsyncNotifierProvider<AssignWorkerNotifier, void>(AssignWorkerNotifier.new);
