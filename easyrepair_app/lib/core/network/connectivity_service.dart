import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/failures.dart';

/// Device-level network reachability (Wi-Fi/cellular radio present) — NOT
/// proof the HandyGo backend is reachable. Used only for fast, friendly UX:
/// the offline banner and blocking write actions before a doomed request.
/// The actual API result (via [dioExceptionToFailure]) remains the source of
/// truth for whether a request actually succeeded.
///
/// A manual singleton (not GetIt) to match [ChatSocketService]'s existing
/// pattern for app-wide services in this codebase.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _statusCtrl =
      StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  // Optimistic default: assume online until the first platform check
  // resolves, so a cold start never flashes an offline banner it can't yet
  // back up with a real reading.
  bool _isOnline = true;

  bool get isOnlineNow => _isOnline;
  Stream<bool> get onStatusChanged => _statusCtrl.stream;

  /// Call once at app startup, before the first frame.
  Future<void> init() async {
    try {
      final initial = await _connectivity.checkConnectivity();
      _isOnline = _toIsOnline(initial);
    } catch (_) {
      // Platform channel failure — keep the optimistic default; the next
      // real API call still surfaces the correct failure either way.
    }
    _sub?.cancel();
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final next = _toIsOnline(results);
      if (next != _isOnline) {
        _isOnline = next;
        _statusCtrl.add(next);
      }
    });
  }

  bool _toIsOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  /// Test-only seam — flips the in-memory reading directly instead of
  /// going through the real platform channel (which [init] and the OS-level
  /// stream depend on and tests cannot reliably drive). Mirrors
  /// `AuthInterceptor.refreshDio`'s existing `@visibleForTesting` pattern.
  @visibleForTesting
  set debugIsOnline(bool value) {
    if (value == _isOnline) return;
    _isOnline = value;
    _statusCtrl.add(value);
  }
}

/// Reactive device connectivity — drives the offline banner.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  yield ConnectivityService.instance.isOnlineNow;
  yield* ConnectivityService.instance.onStatusChanged;
});

/// Synchronous snapshot for guard checks inside notifiers/repositories,
/// where reading a Riverpod stream provider is awkward.
bool isDeviceOnline() => ConnectivityService.instance.isOnlineNow;

/// Call at the very top of a server-changing action's notifier method
/// (create/cancel booking, send message, accept job, submit review, …) —
/// never for read fetches, which fall back to cache instead. Returns the
/// failure to surface when the device has no network, so the caller
/// blocks the action before ever attempting it; returns `null` when online,
/// meaning the caller should proceed exactly as before.
Failure? offlineActionGuard() =>
    isDeviceOnline() ? null : const OfflineActionBlockedFailure();
