import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/repositories/worker_repository_impl.dart';
import '../../domain/entities/worker_profile_entity.dart';
import '../../domain/entities/worker_skill_entity.dart';
import '../../domain/entities/category_entity.dart';

// ── Worker Profile ────────────────────────────────────────────────────────────

class WorkerProfileNotifier extends AsyncNotifier<WorkerProfileEntity> {
  @override
  Future<WorkerProfileEntity> build() async {
    final result = await ref.watch(workerRepositoryProvider).getProfile();
    return result.fold(
      (failure) => throw failure,
      (profile) => profile,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await ref.read(workerRepositoryProvider).getProfile();
      return result.fold((f) => throw f, (p) => p);
    });
  }

  /// Fetches fresh profile data and updates state without showing a loading
  /// spinner.  Used after background operations (e.g. skill save) to sync the
  /// dashboard with real DB values without disrupting the current UI.
  Future<void> silentRefresh() async {
    final result = await ref.read(workerRepositoryProvider).getProfile();
    result.fold(
      (_) {}, // ignore transient errors; dashboard keeps showing current data
      (profile) => state = AsyncData(profile),
    );
  }
}

final workerProfileProvider =
    AsyncNotifierProvider<WorkerProfileNotifier, WorkerProfileEntity>(
  WorkerProfileNotifier.new,
);

// ── Location Tracking State ───────────────────────────────────────────────────

class LocationTrackingState {
  final bool isTracking;
  final double? lastSyncedLat;
  final double? lastSyncedLng;
  final DateTime? lastSyncedAt;

  const LocationTrackingState({
    this.isTracking = false,
    this.lastSyncedLat,
    this.lastSyncedLng,
    this.lastSyncedAt,
  });

  LocationTrackingState copyWith({
    bool? isTracking,
    double? lastSyncedLat,
    double? lastSyncedLng,
    DateTime? lastSyncedAt,
  }) {
    return LocationTrackingState(
      isTracking: isTracking ?? this.isTracking,
      lastSyncedLat: lastSyncedLat ?? this.lastSyncedLat,
      lastSyncedLng: lastSyncedLng ?? this.lastSyncedLng,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

// ── Location Tracker Notifier ─────────────────────────────────────────────────

/// Owns all periodic location tracking logic.
/// The [Timer] lives here as an instance field — not in state — so Riverpod
/// state stays serialisable while the timer lifecycle is managed directly.
class LocationTrackerNotifier extends Notifier<LocationTrackingState> {
  static const _intervalSeconds = 3;
  static const _distanceThresholdMeters = 40.0;
  static const _heartbeatSeconds = 60;
  static const _forcedBackupSeconds = 300; // 5-minute safety net

  Timer? _timer;

  @override
  LocationTrackingState build() {
    // Cancel any running timer if the notifier is disposed (e.g. on logout).
    ref.onDispose(() {
      _timer?.cancel();
      debugPrint('[LocationTracker] Notifier disposed — timer cancelled.');
    });
    return const LocationTrackingState();
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Called when worker goes online.
  /// 1. Gets current location (with permission gate).
  /// 2. Sends immediate server update (ONLINE + lat/lng).
  /// 3. Records the sync in state.
  /// 4. Starts the periodic timer.
  ///
  /// Returns the actual [AvailabilityStatus] returned by the server,
  /// or throws if the server update failed.
  Future<AvailabilityStatus> startTracking() async {
    debugPrint('[LocationTracker] ── START TRACKING ──────────────────────');

    final position = await _getLocation();
    if (position != null) {
      debugPrint('[LocationTracker] Initial location: '
          'lat=${position.latitude.toStringAsFixed(6)}, '
          'lng=${position.longitude.toStringAsFixed(6)}');
    } else {
      debugPrint('[LocationTracker] Initial location unavailable — '
          'server will reject the online request (location required).');
    }

    // Immediate server update
    final newStatus = await _pushToServer(
      status: AvailabilityStatus.online,
      lat: position?.latitude,
      lng: position?.longitude,
      reason: 'initial online sync',
    );

    // Record sync state
    state = LocationTrackingState(
      isTracking: true,
      lastSyncedLat: position?.latitude,
      lastSyncedLng: position?.longitude,
      lastSyncedAt: DateTime.now(),
    );

    _startTimer();
    debugPrint('[LocationTracker] Periodic tracking started '
        '(every $_intervalSeconds s).');

    return newStatus;
  }

  /// Called when worker goes offline.
  /// 1. Attempts a final location fetch.
  /// 2. Sends final OFFLINE update with best-available coords.
  /// 3. Stops the timer and resets state.
  Future<void> stopTracking() async {
    debugPrint('[LocationTracker] ── STOP TRACKING (final offline sync) ──');

    // Cancel timer first so no tick fires during the final sync.
    _timer?.cancel();
    _timer = null;

    // Try to get a fresh location; fall back to last synced.
    final position = await _getLocation();
    final lat = position?.latitude ?? state.lastSyncedLat;
    final lng = position?.longitude ?? state.lastSyncedLng;

    if (position != null) {
      debugPrint('[LocationTracker] Final location: '
          'lat=${lat?.toStringAsFixed(6)}, '
          'lng=${lng?.toStringAsFixed(6)}');
    } else {
      debugPrint('[LocationTracker] Final location unavailable — '
          'using last known: lat=$lat, lng=$lng');
    }

    debugPrint('[LocationTracker] Sending final offline sync...');
    try {
      await _pushToServer(
        status: AvailabilityStatus.offline,
        lat: lat,
        lng: lng,
        reason: 'final offline sync',
      );
      debugPrint('[LocationTracker] Final offline sync succeeded.');
    } catch (e) {
      // Non-fatal: we still stop tracking even if this fails.
      debugPrint('[LocationTracker] Final offline sync FAILED: $e');
    }

    state = const LocationTrackingState();
    debugPrint('[LocationTracker] Tracking stopped.');
  }

  /// Called when the app returns to the foreground while tracking is active.
  /// Forces an immediate tick so the server location is refreshed right away.
  Future<void> onAppResumed() async {
    if (!state.isTracking) return;
    debugPrint('[LocationTracker] App resumed — forcing immediate sync.');
    await _forcedTick();
  }

  // ── Timer ───────────────────────────────────────────────────────────────────

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: _intervalSeconds),
      (_) => _tick(),
    );
  }

  Future<void> _tick() async {
    if (!state.isTracking) {
      _timer?.cancel();
      return;
    }
    await _doTick(forcedReason: null);
  }

  /// Runs the full location-check-and-sync logic.
  /// [forcedReason] — when non-null the server update is sent unconditionally
  /// (skipping distance/heartbeat checks) and the string is used as the log reason.
  Future<void> _forcedTick() async {
    await _doTick(forcedReason: 'app_resumed');
  }

  Future<void> _doTick({required String? forcedReason}) async {
    final position = await _getLocation();
    final now = DateTime.now();
    final secondsSinceSync = state.lastSyncedAt != null
        ? now.difference(state.lastSyncedAt!).inSeconds
        : _heartbeatSeconds; // treat as "long ago" if no prior sync

    // ── Distance calculation ─────────────────────────────────────────────────
    double? distanceMeters;
    if (position != null &&
        state.lastSyncedLat != null &&
        state.lastSyncedLng != null) {
      distanceMeters = Geolocator.distanceBetween(
        state.lastSyncedLat!,
        state.lastSyncedLng!,
        position.latitude,
        position.longitude,
      );
    }

    // ── Decision logic ───────────────────────────────────────────────────────
    final movedEnough =
        distanceMeters != null && distanceMeters >= _distanceThresholdMeters;
    final heartbeatDue = secondsSinceSync >= _heartbeatSeconds;
    final backupDue = secondsSinceSync >= _forcedBackupSeconds;
    final forced = forcedReason != null;
    final shouldUpdate = forced || movedEnough || heartbeatDue || backupDue;

    // ── Debug log ────────────────────────────────────────────────────────────
    debugPrint('[LocationTracker] ── tick ─────────────────────────────────');
    if (position != null) {
      debugPrint('[LocationTracker]   current_lat        = '
          '${position.latitude.toStringAsFixed(6)}');
      debugPrint('[LocationTracker]   current_lng        = '
          '${position.longitude.toStringAsFixed(6)}');
    } else {
      debugPrint('[LocationTracker]   current_lat        = unavailable');
      debugPrint('[LocationTracker]   current_lng        = unavailable');
    }
    debugPrint('[LocationTracker]   last_synced_lat    = '
        '${state.lastSyncedLat?.toStringAsFixed(6) ?? 'null'}');
    debugPrint('[LocationTracker]   last_synced_lng    = '
        '${state.lastSyncedLng?.toStringAsFixed(6) ?? 'null'}');
    debugPrint('[LocationTracker]   distance_meters    = '
        '${distanceMeters?.toStringAsFixed(1) ?? 'n/a'}');
    debugPrint('[LocationTracker]   seconds_since_sync = $secondsSinceSync');
    debugPrint('[LocationTracker]   update_server      = $shouldUpdate'
        '${forced ? ' ($forcedReason)' : ''}'
        '${!forced && movedEnough ? ' (moved ${distanceMeters!.toStringAsFixed(1)}m)' : ''}'
        '${!forced && !movedEnough && heartbeatDue ? ' (heartbeat)' : ''}'
        '${!forced && !movedEnough && !heartbeatDue && backupDue ? ' (backup_5m)' : ''}');

    if (!shouldUpdate) return;

    // ── Server update ────────────────────────────────────────────────────────
    final lat = position?.latitude ?? state.lastSyncedLat;
    final lng = position?.longitude ?? state.lastSyncedLng;

    final syncReason = forcedReason ??
        (movedEnough
            ? 'moved ${distanceMeters!.toStringAsFixed(1)}m'
            : backupDue
                ? 'backup_5m'
                : 'heartbeat');

    try {
      await _pushToServer(
        status: AvailabilityStatus.online,
        lat: lat,
        lng: lng,
        reason: syncReason,
      );
      state = state.copyWith(
        lastSyncedLat: lat,
        lastSyncedLng: lng,
        lastSyncedAt: now,
      );
    } catch (e) {
      debugPrint('[LocationTracker] Server update FAILED ($syncReason): $e');
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Sends an availability + location update to the server.
  /// Returns the [AvailabilityStatus] echoed back by the API.
  Future<AvailabilityStatus> _pushToServer({
    required AvailabilityStatus status,
    double? lat,
    double? lng,
    required String reason,
  }) async {
    final result = await ref.read(workerRepositoryProvider).updateAvailability(
          status: status,
          lat: lat,
          lng: lng,
        );

    return result.fold(
      (failure) {
        debugPrint('[LocationTracker] Server update FAILED ($reason): '
            '${failure.message}');
        throw failure;
      },
      (newStatus) {
        debugPrint('[LocationTracker] Server update OK ($reason) → '
            'status=${newStatus.raw}');
        return newStatus;
      },
    );
  }

  /// Permission-aware location fetch. Returns null (never throws) if
  /// permission is denied or if the device returns an error.
  Future<Position?> _getLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        // getCurrentPosition timed out or failed (e.g. GPS cold start).
        // Fall back to the last known fix so the worker can still go online.
        debugPrint('[LocationTracker] getCurrentPosition failed — '
            'falling back to last known position.');
        return await Geolocator.getLastKnownPosition();
      }
    } catch (_) {
      return null;
    }
  }
}

final locationTrackerProvider =
    NotifierProvider<LocationTrackerNotifier, LocationTrackingState>(
  LocationTrackerNotifier.new,
);

// ── Availability ──────────────────────────────────────────────────────────────

/// Possible outcomes when attempting to toggle availability.
enum AvailabilityToggleResult { success, needsSkills }

/// Thin action notifier — only responsible for the "go online / go offline"
/// user action. All tracking lifecycle is delegated to [locationTrackerProvider].
class AvailabilityNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Attempts to take the worker online.
  ///
  /// Returns [AvailabilityToggleResult.needsSkills] if the worker has no
  /// skills configured (caller should show the skills sheet first).
  Future<AvailabilityToggleResult> goOnline() async {
    final profile = ref.read(workerProfileProvider).valueOrNull;
    if (profile != null && profile.skills.isEmpty) {
      return AvailabilityToggleResult.needsSkills;
    }

    state = const AsyncLoading();
    try {
      final newStatus = await ref
          .read(locationTrackerProvider.notifier)
          .startTracking();

      // Reflect the new status in the profile provider.
      final current = ref.read(workerProfileProvider).valueOrNull;
      if (current != null) {
        ref.read(workerProfileProvider.notifier).state =
            AsyncData(current.copyWith(availabilityStatus: newStatus));
      }
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }

    return AvailabilityToggleResult.success;
  }

  /// Takes the worker offline. The tracker fires a final location sync before
  /// stopping.
  Future<void> goOffline() async {
    state = const AsyncLoading();
    try {
      await ref.read(locationTrackerProvider.notifier).stopTracking();

      final current = ref.read(workerProfileProvider).valueOrNull;
      if (current != null) {
        ref.read(workerProfileProvider.notifier).state = AsyncData(
          current.copyWith(availabilityStatus: AvailabilityStatus.offline),
        );
      }
      state = const AsyncData(null);
    } catch (e, st) {
      // Even if stopTracking threw, we still mark as offline locally.
      final current = ref.read(workerProfileProvider).valueOrNull;
      if (current != null) {
        ref.read(workerProfileProvider.notifier).state = AsyncData(
          current.copyWith(availabilityStatus: AvailabilityStatus.offline),
        );
      }
      state = AsyncError(e, st);
    }
  }
}

final availabilityNotifierProvider =
    AsyncNotifierProvider<AvailabilityNotifier, void>(AvailabilityNotifier.new);

// ── Skills ────────────────────────────────────────────────────────────────────

class SkillsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> saveSkills(List<String> categoryIds) async {
    state = const AsyncLoading();
    final result =
        await ref.read(workerRepositoryProvider).updateSkills(categoryIds);
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (updatedSkills) {
        // Optimistically update local state with the skills returned by the server
        // (these come directly from the DB transaction so they are the real values).
        final current = ref.read(workerProfileProvider).valueOrNull;
        if (current != null) {
          ref.read(workerProfileProvider.notifier).state =
              AsyncData(current.copyWith(skills: updatedSkills));
        }
        state = const AsyncData(null);
        // Silent background re-fetch syncs dashboard with real DB values
        // without triggering a loading spinner that would disrupt the UI.
        ref.read(workerProfileProvider.notifier).silentRefresh();
        return true;
      },
    );
  }
}

final skillsNotifierProvider =
    AsyncNotifierProvider<SkillsNotifier, void>(SkillsNotifier.new);

// ── Categories ────────────────────────────────────────────────────────────────

final categoriesProvider = FutureProvider<List<CategoryEntity>>((ref) async {
  final result = await ref.read(workerRepositoryProvider).getCategories();
  return result.fold((f) => throw f, (categories) => categories);
});

// ── Selected skill ids for the skills sheet ───────────────────────────────────

final selectedCategoryIdsProvider =
    StateProvider<Set<String>>((ref) => const {});
