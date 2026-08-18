import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_service.dart';

/// The ONE "the device just came back online" signal.
///
/// [isOnlineProvider] reports the current connectivity *state* and is what
/// the offline banner watches. This provider reports the *transition*
/// OFFLINE → ONLINE only, which is the thing worth reacting to: it fires once
/// per reconnection, never on app start, and never when connectivity merely
/// changes shape (Wi-Fi → cellular is still online, so it emits nothing).
///
/// ## What this is deliberately NOT
///
/// It is not wired into the router, `authStateProvider`, or any redirect. A
/// previous HandyGo bug sent users from a nested page to splash and then Home
/// when an auth/provider refresh fired; the fix is that a reconnect must never
/// be able to influence navigation at all. Refreshing data providers cannot
/// move the user — GoRouter's `redirect` only reads `authStateProvider` — and
/// nothing here touches that.
///
/// It is also not a global `ref.invalidate(everything)`. Blanket invalidation
/// on reconnect produces a request storm, loading flashes on screens the user
/// is not even looking at, and duplicated work. Refresh is opt-in per screen
/// via [refreshOnReconnect], so only what is actually mounted refetches.
final reconnectSignalProvider = StreamProvider<int>((ref) {
  final controller = StreamController<int>.broadcast();
  var reconnectCount = 0;
  var wasOnline = ConnectivityService.instance.isOnlineNow;

  final sub = ConnectivityService.instance.onStatusChanged.listen((isOnline) {
    // Only the offline → online edge. Going offline changes nothing that
    // needs refetching, and staying online emits no event at all.
    if (isOnline && !wasOnline) {
      controller.add(++reconnectCount);
    }
    wasOnline = isOnline;
  });

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Refreshes THIS screen's data when the device reconnects.
///
/// Call from a `ConsumerState.build` (or a `ConsumerWidget.build`) of a page
/// that shows cached/network data:
///
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   refreshOnReconnect(ref, () => ref.invalidate(bookingDetailProvider(id)));
///   …
/// }
/// ```
///
/// Because the listener lives with the widget, an unmounted screen refetches
/// nothing — which is what keeps a reconnect from fanning out into dozens of
/// simultaneous requests. The current route is untouched: this only
/// invalidates data providers, and the page stays exactly where it is while
/// its content updates in place (Riverpod keeps the previous value visible
/// during the refetch, so there is no spinner flash).
void refreshOnReconnect(WidgetRef ref, VoidCallback onReconnect) {
  ref.listen<AsyncValue<int>>(reconnectSignalProvider, (previous, next) {
    // Only a genuine new emission counts. Guarding on the payload rather than
    // just `next.hasValue` means a rebuild that replays the same value cannot
    // trigger a second refresh.
    final before = previous?.valueOrNull;
    final now = next.valueOrNull;
    if (now == null || now == before) return;
    onReconnect();
  });
}
