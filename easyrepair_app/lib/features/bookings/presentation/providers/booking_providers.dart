import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/booking_remote_datasource.dart';
import '../../data/repositories/booking_repository_impl.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/create_booking_request.dart';
import '../../domain/entities/inspection_report_entity.dart';
import '../../domain/entities/nearby_worker_entity.dart';
import '../../domain/entities/update_booking_request.dart';
import '../../domain/repositories/booking_repository.dart';
import '../../domain/usecases/cancel_booking_usecase.dart';
import '../../domain/usecases/create_booking_usecase.dart';
import '../../domain/usecases/get_client_bookings_usecase.dart';
import '../../../worker/presentation/providers/worker_job_providers.dart';

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

  /// Background/pull-to-refresh reload. Uses ref.invalidateSelf() rather than
  /// a manual `state = AsyncLoading()` reset — Riverpod's own
  /// isRefreshing/copyWithPrevious mechanism then keeps the previous list
  /// visible (AsyncValue.when's default skipLoadingOnRefresh:true skips the
  /// loading branch) instead of flashing the whole tab to a skeleton.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // Swallowed — state already reflects the outcome safely; a background
      // failure with existing cached data keeps showing that data (see the
      // skipError:true call sites that watch this provider).
    }
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
  /// [reason] is required — the backend rejects an empty reason.
  Future<void> cancelBooking(String bookingId, String reason) async {
    final result =
        await ref.read(cancelBookingUseCaseProvider).call(bookingId, reason);
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

  /// Manual "Refresh" — re-runs expansion from the first radius immediately,
  /// bypassing the recheck timer's wait. Mirrors
  /// StandardNearbyWorkersNotifier.refresh(). No-ops if expansion is already
  /// in flight (same guard _startExpansion already uses internally).
  Future<void> refresh() async {
    _recheckTimer?.cancel();
    _poolMap.clear();
    await _startExpansion(arg, fromIndex: 0);
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
      if (a.recommended != b.recommended) {
        return a.recommended ? -1 : 1;
      }
      final dc = a.distanceKm.compareTo(b.distanceKm);
      return dc != 0 ? dc : b.rating.compareTo(a.rating);
    });
  }
}

final nearbyWorkersNotifierProvider = NotifierProvider.autoDispose
    .family<NearbyWorkersNotifier, NearbyWorkersState, String>(
      NearbyWorkersNotifier.new,
    );

// ── STANDARD-lane nearby workers (controlled, capped radius) ─────────────────

/// STANDARD-lane nearby-workers notifier used by [ChooseUstaadPage].
///
/// Unlike [NearbyWorkersNotifier] (shared by INSPECTION/legacy call sites,
/// which walks a wide 3→20km ladder with an aggressive 3-second recheck),
/// STANDARD lane's radius is capped by product spec at 5km → 7km — matching
/// the backend's own STANDARD radius ladder (see
/// BookingsRepository._findNearbyWorkersPostgis/Haversine) — and polling is
/// deliberately gentle:
///  1. On load: search 5km; if nobody is found, try 7km. Never expands past
///     7km (per product decision — do not widen without explicit sign-off).
///  2. Workers found → stop actively polling; a slow 2-minute background
///     recheck just keeps the list from going stale, without adding real load.
///  3. No workers found at all → auto-retry every 45 seconds until someone
///     appears, [stop] is called, or the provider is disposed.
///  4. A tick is skipped entirely if a previous request from this notifier
///     is still in flight — never overlapping requests.
class StandardNearbyWorkersNotifier
    extends AutoDisposeFamilyNotifier<NearbyWorkersState, String> {
  static const _radii = [5.0, 7.0];
  static const _emptyRecheckInterval = Duration(seconds: 45);
  static const _foundRecheckInterval = Duration(minutes: 2);

  Timer? _recheckTimer;
  bool _requestInProgress = false;
  bool _disposed = false;
  bool _stopped = false;

  @override
  NearbyWorkersState build(String arg) {
    _disposed = false;
    _stopped = false;
    ref.onDispose(() {
      _disposed = true;
      _recheckTimer?.cancel();
    });
    _search(arg, radiusIndex: 0);
    return const NearbyWorkersState();
  }

  /// Stops all polling — call when the booking is no longer eligible for
  /// worker selection (assigned/hired, cancelled, expired, completed) while
  /// this notifier might still be alive.
  void stop() {
    _stopped = true;
    _recheckTimer?.cancel();
  }

  /// Manual "Refresh" — re-runs the capped 5km→7km search immediately,
  /// bypassing the recheck timer's wait. No-ops if a request is in flight.
  Future<void> refresh() async {
    _recheckTimer?.cancel();
    await _search(arg, radiusIndex: 0);
  }

  Future<void> _search(String bookingId, {required int radiusIndex}) async {
    if (_disposed || _stopped || _requestInProgress) return;
    _requestInProgress = true;

    final radiusKm = _radii[radiusIndex];
    final result = await ref
        .read(bookingRepositoryProvider)
        .getNearbyWorkers(bookingId, radiusKm: radiusKm);
    _requestInProgress = false;

    if (_disposed || _stopped) return;

    result.fold(
      (failure) {
        state = state.workers.isEmpty
            ? NearbyWorkersState(
                isExpanding: false,
                searchedRadiusKm: radiusKm,
                error: failure,
              )
            : state.copyWith(isExpanding: false, searchedRadiusKm: radiusKm);
        _scheduleRecheck(bookingId, found: state.workers.isNotEmpty);
      },
      (res) {
        final foundNothingYet = res.workers.isEmpty;
        final canTryNextRadius = radiusIndex < _radii.length - 1;

        if (foundNothingYet && canTryNextRadius) {
          // Nobody within 5km — try 7km right away. Still within the capped
          // ladder, so this is a same-search follow-up, not "polling".
          state = NearbyWorkersState(
            isExpanding: true,
            searchedRadiusKm: radiusKm,
          );
          _search(bookingId, radiusIndex: radiusIndex + 1);
          return;
        }

        state = NearbyWorkersState(
          workers: _sorted(res.workers),
          isExpanding: false,
          searchedRadiusKm: radiusKm,
          searchCompleted: res.workers.isNotEmpty,
        );
        _scheduleRecheck(bookingId, found: res.workers.isNotEmpty);
      },
    );
  }

  void _scheduleRecheck(String bookingId, {required bool found}) {
    if (_disposed || _stopped) return;
    _recheckTimer?.cancel();
    _recheckTimer = Timer(
      found ? _foundRecheckInterval : _emptyRecheckInterval,
      () => _search(bookingId, radiusIndex: 0),
    );
  }

  List<NearbyWorkerEntity> _sorted(List<NearbyWorkerEntity> workers) {
    return List<NearbyWorkerEntity>.from(workers)..sort((a, b) {
      if (a.recommended != b.recommended) {
        return a.recommended ? -1 : 1;
      }
      final dc = a.distanceKm.compareTo(b.distanceKm);
      return dc != 0 ? dc : b.rating.compareTo(a.rating);
    });
  }
}

final standardNearbyWorkersNotifierProvider = NotifierProvider.autoDispose
    .family<StandardNearbyWorkersNotifier, NearbyWorkersState, String>(
      StandardNearbyWorkersNotifier.new,
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
        // The nearby-workers sheet is no longer valid after assignment —
        // stop whichever notifier backed it (legacy ladder or STANDARD).
        ref.invalidate(nearbyWorkersNotifierProvider(bookingId));
        ref.invalidate(standardNearbyWorkersNotifierProvider(bookingId));
      },
    );
  }
}

final assignWorkerNotifierProvider =
    AsyncNotifierProvider<AssignWorkerNotifier, void>(AssignWorkerNotifier.new);

// ── Relist (Make Live Again) notifier ────────────────────────────────────────

class RelistBookingNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> relist(String bookingId) async {
    state = const AsyncLoading();
    final result =
        await ref.read(bookingRepositoryProvider).relistBooking(bookingId);
    result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        throw failure;
      },
      (updated) {
        state = const AsyncData(null);
        ref.read(bookingsNotifierProvider.notifier).patchBooking(updated);
        ref.read(bookingDetailProvider(bookingId).notifier).push(updated);
      },
    );
  }
}

final relistBookingNotifierProvider =
    AsyncNotifierProvider<RelistBookingNotifier, void>(
      RelistBookingNotifier.new,
    );

// ── Worker lifecycle notifier (on-my-way / arrived / start / complete / cancel) ─

class WorkerLifecycleNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> _run(
    String bookingId,
    Future<Either<Failure, BookingEntity>> Function() call,
  ) async {
    state = const AsyncLoading();
    final result = await call();
    result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        throw failure;
      },
      (updated) {
        state = const AsyncData(null);
        // Client-side cache — harmless no-op when this runs inside the
        // worker app process (client and worker are separate app installs),
        // kept for any shared-process/testing scenarios.
        ref.read(bookingDetailProvider(bookingId).notifier).push(updated);
        // Worker-side state — the ACTUAL source of truth for
        // worker_jobs_page.dart and worker_job_detail_page.dart. Without
        // this, both kept showing the pre-action button until the app was
        // backgrounded/resumed or the page was reopened.
        ref.invalidate(workerJobDetailProvider(bookingId));
        ref.invalidate(workerJobsProvider);
      },
    );
  }

  Future<void> onMyWay(String bookingId) => _run(
        bookingId,
        () => ref.read(bookingRepositoryProvider).markOnMyWay(bookingId),
      );

  Future<void> arrived(String bookingId) => _run(
        bookingId,
        () => ref.read(bookingRepositoryProvider).markArrived(bookingId),
      );

  Future<void> start(String bookingId) => _run(
        bookingId,
        () => ref.read(bookingRepositoryProvider).startJob(bookingId),
      );

  Future<void> complete(String bookingId) => _run(
        bookingId,
        () =>
            ref.read(bookingRepositoryProvider).completeJobLifecycle(bookingId),
      );

  Future<void> cancel(String bookingId, String reason) => _run(
        bookingId,
        () => ref
            .read(bookingRepositoryProvider)
            .workerCancelBooking(bookingId, reason),
      );
}

final workerLifecycleNotifierProvider =
    AsyncNotifierProvider<WorkerLifecycleNotifier, void>(
      WorkerLifecycleNotifier.new,
    );

/// Dispatches a [WorkerLifecycleAction] to the matching [WorkerLifecycleNotifier]
/// method. The single call site both worker_jobs_page.dart and
/// worker_job_detail_page.dart use, so the two surfaces can never end up
/// calling a different endpoint for the same button.
extension WorkerLifecycleActionDispatchX on WorkerLifecycleAction {
  Future<void> invoke(WidgetRef ref, String bookingId) {
    final notifier = ref.read(workerLifecycleNotifierProvider.notifier);
    return switch (this) {
      WorkerLifecycleAction.onMyWay => notifier.onMyWay(bookingId),
      WorkerLifecycleAction.arrived => notifier.arrived(bookingId),
      WorkerLifecycleAction.start => notifier.start(bookingId),
      WorkerLifecycleAction.complete => notifier.complete(bookingId),
    };
  }
}

/// Dispatches the on-my-way/arrived/complete steps of [InspectionWorkerAction]
/// to the same [WorkerLifecycleNotifier] endpoints STANDARD uses (the
/// underlying API calls are lane-agnostic). [fillReport] navigates to the
/// report form instead of calling an API — callers should check
/// [InspectionWorkerAction.isActionable] and handle that case separately.
extension InspectionWorkerActionDispatchX on InspectionWorkerAction {
  Future<void> invoke(WidgetRef ref, String bookingId) {
    final notifier = ref.read(workerLifecycleNotifierProvider.notifier);
    return switch (this) {
      InspectionWorkerAction.onMyWay => notifier.onMyWay(bookingId),
      InspectionWorkerAction.arrived => notifier.arrived(bookingId),
      InspectionWorkerAction.startInspection => notifier.start(bookingId),
      InspectionWorkerAction.complete => notifier.complete(bookingId),
      InspectionWorkerAction.fillReport ||
      InspectionWorkerAction.waitingForDecision =>
        throw StateError('$this is not an API-dispatchable action.'),
    };
  }
}

// ── Inspection report (INSPECTION lane) ─────────────────────────────────────

/// Fetches the submitted inspection report for a booking. Returns
/// [AsyncError] with a [NotFoundFailure]-like error until a report exists —
/// callers (client report card, worker post-submit confirmation) should
/// treat any error as "no report yet" unless they just submitted one.
final inspectionReportProvider =
    FutureProvider.autoDispose.family<InspectionReportEntity, String>(
  (ref, bookingId) async {
    final result =
        await ref.read(bookingRepositoryProvider).getInspectionReport(bookingId);
    return result.fold((f) => throw f, (r) => r);
  },
);

class InspectionReportSubmitNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit(
    String bookingId, {
    String? issueFound,
    String? recommendedRepair,
    required double labourCost,
    required bool partsNeeded,
    required List<InspectionReportPartDraft> parts,
    String? notes,
    required List<File> photos,
    File? voiceNoteFile,
    double? voiceNoteDurationSeconds,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(bookingRepositoryProvider).submitInspectionReport(
          bookingId,
          issueFound: issueFound,
          recommendedRepair: recommendedRepair,
          labourCost: labourCost,
          partsNeeded: partsNeeded,
          parts: parts,
          notes: notes,
          photos: photos,
          voiceNoteFile: voiceNoteFile,
          voiceNoteDurationSeconds: voiceNoteDurationSeconds,
        );
    result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        throw failure;
      },
      (_) {
        state = const AsyncData(null);
        ref.invalidate(inspectionReportProvider(bookingId));
        ref.invalidate(bookingDetailProvider(bookingId));
        ref.invalidate(workerJobDetailProvider(bookingId));
        ref.invalidate(workerJobsProvider);
      },
    );
  }
}

final inspectionReportSubmitNotifierProvider =
    AsyncNotifierProvider<InspectionReportSubmitNotifier, void>(
  InspectionReportSubmitNotifier.new,
);

/// Client's "Accept Quote & Continue Repair" / "Close After Inspection".
class InspectionDecisionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> _run(
    String bookingId,
    Future<Either<Failure, BookingEntity>> Function() call,
  ) async {
    state = const AsyncLoading();
    final result = await call();
    result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        throw failure;
      },
      (updated) {
        state = const AsyncData(null);
        ref.read(bookingsNotifierProvider.notifier).patchBooking(updated);
        ref.read(bookingDetailProvider(bookingId).notifier).push(updated);
        ref.invalidate(inspectionReportProvider(bookingId));
        ref.invalidate(workerJobDetailProvider(bookingId));
        ref.invalidate(workerJobsProvider);
      },
    );
  }

  Future<void> acceptQuote(String bookingId) => _run(
        bookingId,
        () => ref.read(bookingRepositoryProvider).acceptInspectionQuote(bookingId),
      );

  Future<void> closeAfterInspection(String bookingId) => _run(
        bookingId,
        () => ref.read(bookingRepositoryProvider).closeAfterInspection(bookingId),
      );
}

final inspectionDecisionNotifierProvider =
    AsyncNotifierProvider<InspectionDecisionNotifier, void>(
  InspectionDecisionNotifier.new,
);
