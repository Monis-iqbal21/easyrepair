import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/l10n/locale_provider.dart';
import '../../data/repositories/worker_repository_impl.dart';
import '../../domain/entities/worker_profile_entity.dart';
import '../../domain/entities/worker_skill_entity.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/agreement_template_entity.dart';
import '../../domain/repositories/worker_repository.dart';

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

  /// Delegates to silentRefresh() — keeps the dashboard visible instead of
  /// flashing to a loading spinner (RefreshIndicator's own pull animation
  /// already gives the user feedback that a refresh is happening).
  Future<void> refresh() async {
    await silentRefresh();
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
  /// 1. Uses the fastest available location (cached last-known fix first, so
  ///    the request never sits waiting on a fresh GPS reading; only falls
  ///    back to a bounded fresh fetch when nothing is cached yet).
  /// 2. Sends immediate server update (ONLINE + lat/lng).
  /// 3. Records the sync in state.
  /// 4. Starts the periodic timer.
  /// 5. Refines the location with a fresh GPS fix in the background,
  ///    without blocking the user-visible "Go Online" action.
  ///
  /// Returns the actual [AvailabilityStatus] returned by the server,
  /// or throws if the server update failed.
  Future<AvailabilityStatus> startTracking() async {
    debugPrint('[LocationTracker] ── START TRACKING ──────────────────────');

    final hasPermission = await _ensureLocationPermission();
    final position = hasPermission ? await _getLocationFastPath() : null;
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

    // Fire-and-forget: refine with a fresh GPS fix shortly after going
    // online. Never awaited here — must not delay the "Go Online" result.
    if (hasPermission) {
      _refineLocationInBackground();
    }

    return newStatus;
  }

  /// Refines the just-synced location with a fresh GPS fix, in the
  /// background. Never blocks/throws into the caller — best-effort only.
  Future<void> _refineLocationInBackground() async {
    final fresh = await _getFreshLocationBounded();
    if (fresh == null || !state.isTracking) return;
    try {
      await _pushLocationOnly(
        lat: fresh.latitude,
        lng: fresh.longitude,
        reason: 'post_online_refresh',
      );
      state = state.copyWith(
        lastSyncedLat: fresh.latitude,
        lastSyncedLng: fresh.longitude,
        lastSyncedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[LocationTracker] Background refresh FAILED: $e');
    }
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

    // Try the fastest available fix; fall back to last synced. Bounded —
    // going offline must never hang waiting on GPS.
    final position = await _getLocationFastPath();
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
      await _pushLocationOnly(lat: lat, lng: lng, reason: syncReason);
      state = state.copyWith(
        lastSyncedLat: lat,
        lastSyncedLng: lng,
        lastSyncedAt: now,
      );
    } catch (e) {
      debugPrint('[LocationTracker] Location ping FAILED ($syncReason): $e');
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

  /// Periodic location-only ping — uses the dedicated /workers/location
  /// endpoint that never changes availabilityStatus on the server.
  /// Silently skips if coordinates are unavailable.
  Future<void> _pushLocationOnly({
    double? lat,
    double? lng,
    required String reason,
  }) async {
    if (lat == null || lng == null) {
      debugPrint(
          '[LocationTracker] No coords — skipping location ping ($reason)');
      return;
    }
    final result = await ref.read(workerRepositoryProvider).updateLocationOnly(
          lat: lat,
          lng: lng,
        );
    result.fold(
      (failure) {
        debugPrint(
            '[LocationTracker] Location ping FAILED ($reason): ${failure.message}');
        throw failure;
      },
      (_) => debugPrint('[LocationTracker] Location ping OK ($reason)'),
    );
  }

  /// Checks/requests location permission. `checkPermission` is a cheap read
  /// (bounded defensively); `requestPermission` shows a native OS dialog and
  /// is deliberately left unbounded — it resolves as soon as the user
  /// responds and must not be raced against an arbitrary timer.
  Future<bool> _ensureLocationPermission() async {
    try {
      LocationPermission permission =
          await Geolocator.checkPermission().timeout(const Duration(seconds: 3));
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever;
    } catch (_) {
      return false;
    }
  }

  /// Cached last-known fix — reads the device's location cache, which
  /// should be near-instant. Bounded regardless, since some Android/OEM
  /// location stacks are known to occasionally hang on this call; never
  /// throws.
  Future<Position?> _getCachedLocation() async {
    try {
      return await Geolocator.getLastKnownPosition()
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      return null;
    }
  }

  /// Fresh GPS fix, bounded on top of the plugin's own `timeLimit` as a
  /// backstop in case the platform channel doesn't honor it. Never throws.
  Future<Position?> _getFreshLocationBounded() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      ).timeout(const Duration(seconds: 7));
    } catch (_) {
      return null;
    }
  }

  /// Used by "Go Online" / "Go Offline" — favors the cached last-known fix
  /// so the action completes promptly; only attempts a bounded fresh GPS
  /// fetch when nothing is cached yet (e.g. first launch this session).
  /// Assumes permission has already been confirmed by the caller.
  Future<Position?> _getLocationFastPath() async {
    final cached = await _getCachedLocation();
    if (cached != null) return cached;
    return _getFreshLocationBounded();
  }

  /// Used by the periodic tracker tick — favors a fresh fix (to detect real
  /// movement), falling back to the cached fix if the fresh attempt fails.
  /// Both legs are bounded; never throws.
  Future<Position?> _getLocation() async {
    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) return null;
    final fresh = await _getFreshLocationBounded();
    if (fresh != null) return fresh;
    debugPrint(
        '[LocationTracker] getCurrentPosition failed — falling back to last known position.');
    return _getCachedLocation();
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

/// The three agreements the Ustaad must read, in the app's current language.
///
/// Re-fetched whenever the profile changes (picking a different main skill
/// must load that trade's schedule, never keep the previous one) and whenever
/// the app language changes (the language notice depends on it).
final agreementTemplatesProvider =
    FutureProvider<List<AgreementTemplateEntity>>((ref) async {
  ref.watch(workerProfileProvider);
  final locale = ref.watch(localeProvider);
  final result = await ref
      .read(workerRepositoryProvider)
      .getAgreementTemplates(appLocale: locale.storageValue);
  return result.fold((f) => throw f, (templates) => templates);
});

/// The Ustaad's own sealed acceptance records — the Legal section on the
/// Worker Profile page. Immutable history: changing the app language never
/// rewrites what is in here.
final myAgreementsProvider =
    FutureProvider<List<AcceptedAgreementEntity>>((ref) async {
  final result = await ref.read(workerRepositoryProvider).getMyAgreements();
  return result.fold((f) => throw f, (records) => records);
});

// ── Selected skill ids for the skills sheet ───────────────────────────────────

final selectedCategoryIdsProvider =
    StateProvider<Set<String>>((ref) => const {});

// ── Profile completion (Ustaad onboarding) ──────────────────────────────────

/// Whether the "complete your profile" modal has already been shown once in
/// this app session — reset on logout. Prevents it from reappearing on every
/// resume/navigation once the worker has seen and dismissed it; the worker
/// can still reach the page anytime via the persistent Home banner.
final onboardingModalShownProvider = StateProvider<bool>((ref) => false);

class ProfileCompletionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Saves the given fields, then silently refreshes workerProfileProvider
  /// so every screen reading it (Home, Profile, this page) sees the update.
  /// Returns false (and leaves the Failure in state.error) on failure.
  Future<bool> save({
    String? fullLegalName,
    String? residentialAddress,
    String? cnicNumber,
    String? fatherName,
    String? dateOfBirth,
    String? emergencyContact,
    int? experienceYears,
    bool? legalNameConfirmed,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(workerRepositoryProvider).updateProfileCompletion(
          fullLegalName: fullLegalName,
          residentialAddress: residentialAddress,
          cnicNumber: cnicNumber,
          fatherName: fatherName,
          dateOfBirth: dateOfBirth,
          emergencyContact: emergencyContact,
          experienceYears: experienceYears,
          legalNameConfirmed: legalNameConfirmed,
        );
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (_) async {
        state = const AsyncData(null);
        await ref.read(workerProfileProvider.notifier).silentRefresh();
        return true;
      },
    );
  }

  Future<String?> uploadCnicFront(File file) => _upload(
        (repo) => repo.uploadCnicFront(file),
      );

  Future<String?> uploadCnicBack(File file) => _upload(
        (repo) => repo.uploadCnicBack(file),
      );

  Future<String?> uploadLiveSelfie(File file) => _upload(
        (repo) => repo.uploadLiveSelfie(file),
      );

  Future<String?> _upload(
    Future<Either<Failure, String>> Function(WorkerRepository repo) call,
  ) async {
    state = const AsyncLoading();
    final result = await call(ref.read(workerRepositoryProvider));
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return null;
      },
      (url) {
        state = const AsyncData(null);
        // Fire-and-forget — the uploaded URL is already known locally for
        // instant UI feedback; the silent refresh syncs everything else.
        ref.read(workerProfileProvider.notifier).silentRefresh();
        return url;
      },
    );
  }

  /// Seals the three acceptance records and moves the profile to
  /// SUBMITTED_FOR_REVIEW.
  ///
  /// [submissionAttemptId] is generated once per attempt, so a retry after a
  /// timeout returns the SAME three records instead of creating a second set.
  /// Returns null (leaving the Failure in state.error) when the backend
  /// rejected the submission.
  Future<List<AcceptedAgreementEntity>?> submit({
    required String submissionAttemptId,
    required List<AgreementEvidence> agreements,
  }) async {
    state = const AsyncLoading();
    final result =
        await ref.read(workerRepositoryProvider).submitProfileForReview(
              submissionAttemptId: submissionAttemptId,
              agreements: agreements,
            );
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return null;
      },
      (accepted) {
        state = const AsyncData(null);
        // Fire-and-forget: the caller navigates on the returned summaries, and
        // the Legal section reloads behind it.
        ref.read(workerProfileProvider.notifier).silentRefresh();
        ref.invalidate(myAgreementsProvider);
        return accepted;
      },
    );
  }

  /// Fetches one of the worker's own accepted PDFs through the authenticated
  /// endpoint. Returns null (Failure in state.error) if it could not be read.
  Future<List<int>?> downloadAgreement(String acceptanceId) async {
    final result = await ref
        .read(workerRepositoryProvider)
        .downloadAgreementPdf(acceptanceId);
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return null;
      },
      (bytes) => bytes,
    );
  }
}

final profileCompletionNotifierProvider =
    AsyncNotifierProvider<ProfileCompletionNotifier, void>(
  ProfileCompletionNotifier.new,
);
