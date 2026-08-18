import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/network/connectivity_service.dart';
import 'package:handygo_app/core/network/reconnect_refresh.dart';

/// The reconnect signal is deliberately an EDGE (offline → online), not a
/// state. Getting that wrong is what produces request storms: a state-based
/// listener re-fires on every rebuild and on every connectivity event,
/// including going offline and switching Wi-Fi → cellular.
void main() {
  setUp(() => ConnectivityService.instance.debugIsOnline = true);
  tearDown(() => ConnectivityService.instance.debugIsOnline = true);

  group('reconnectSignalProvider', () {
    test('emits nothing while the device simply stays online', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final emissions = <int>[];
      container.listen(
        reconnectSignalProvider,
        (_, next) {
          final value = next.valueOrNull;
          if (value != null) emissions.add(value);
        },
        fireImmediately: true,
      );
      await Future<void>.delayed(Duration.zero);

      expect(emissions, isEmpty,
          reason: 'app start is not a reconnection');
    });

    test('emits nothing when the device goes OFFLINE', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final emissions = <int>[];
      container.listen(reconnectSignalProvider, (_, next) {
        final value = next.valueOrNull;
        if (value != null) emissions.add(value);
      });
      await Future<void>.delayed(Duration.zero);

      ConnectivityService.instance.debugIsOnline = false;
      await Future<void>.delayed(Duration.zero);

      expect(emissions, isEmpty,
          reason: 'losing connectivity has nothing to refetch');
    });

    test('emits exactly once on the offline → online edge', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final emissions = <int>[];
      container.listen(reconnectSignalProvider, (_, next) {
        final value = next.valueOrNull;
        if (value != null) emissions.add(value);
      });
      await Future<void>.delayed(Duration.zero);

      ConnectivityService.instance.debugIsOnline = false;
      await Future<void>.delayed(Duration.zero);
      ConnectivityService.instance.debugIsOnline = true;
      await Future<void>.delayed(Duration.zero);

      expect(emissions, [1]);
    });

    test('counts each reconnection separately across flapping connectivity',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final emissions = <int>[];
      container.listen(reconnectSignalProvider, (_, next) {
        final value = next.valueOrNull;
        if (value != null) emissions.add(value);
      });
      await Future<void>.delayed(Duration.zero);

      for (var i = 0; i < 3; i++) {
        ConnectivityService.instance.debugIsOnline = false;
        await Future<void>.delayed(Duration.zero);
        ConnectivityService.instance.debugIsOnline = true;
        await Future<void>.delayed(Duration.zero);
      }

      expect(emissions, [1, 2, 3]);
    });
  });

  group('refreshOnReconnect', () {
    testWidgets('fires the screen\'s refresh exactly once per reconnection',
        (tester) async {
      var refreshes = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                refreshOnReconnect(ref, () => refreshes++);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pump();

      ConnectivityService.instance.debugIsOnline = false;
      await tester.pump();
      ConnectivityService.instance.debugIsOnline = true;
      await tester.pump();
      await tester.pump();

      expect(refreshes, 1);
    });

    testWidgets('a plain rebuild does not re-trigger a refresh — this is what '
        'keeps a reconnect from turning into a request storm', (tester) async {
      var refreshes = 0;
      final rebuild = ValueNotifier<int>(0);
      addTearDown(rebuild.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ValueListenableBuilder<int>(
              valueListenable: rebuild,
              builder: (context, _, _) => Consumer(
                builder: (context, ref, _) {
                  refreshOnReconnect(ref, () => refreshes++);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      ConnectivityService.instance.debugIsOnline = false;
      await tester.pump();
      ConnectivityService.instance.debugIsOnline = true;
      await tester.pump();
      await tester.pump();
      expect(refreshes, 1);

      // Several unrelated rebuilds of the same screen.
      for (var i = 1; i <= 5; i++) {
        rebuild.value = i;
        await tester.pump();
      }

      expect(refreshes, 1);
    });

    testWidgets('an unmounted screen refreshes nothing', (tester) async {
      var refreshes = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                refreshOnReconnect(ref, () => refreshes++);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Navigate away / dispose the screen.
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: SizedBox.shrink()),
        ),
      );
      await tester.pump();

      ConnectivityService.instance.debugIsOnline = false;
      await tester.pump();
      ConnectivityService.instance.debugIsOnline = true;
      await tester.pump();
      await tester.pump();

      expect(refreshes, 0,
          reason: 'only mounted screens refetch — that is the whole '
              'request-storm defence');
    });
  });
}
