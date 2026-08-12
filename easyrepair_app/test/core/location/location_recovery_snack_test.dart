import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/location/location_availability.dart';
import 'package:handygo_app/core/location/location_recovery_snack.dart';
import 'package:handygo_app/l10n/app_localizations.dart';

import '../../support/l10n_test_app.dart';

/// Pumps a page with a single button that triggers
/// [showLocationRecoverySnack] for [status], then taps it and settles the
/// resulting SnackBar animation.
Future<void> _pumpAndShow(
  WidgetTester tester,
  LocationAvailability status, {
  VoidCallback? onRetry,
}) async {
  await tester.pumpWidget(
    localizedApp(
      Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () =>
                showLocationRecoverySnack(context, status, onRetry: onRetry),
            child: const Text('trigger'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('trigger'));
  await tester.pumpAndSettle(); // let the SnackBar's enter animation finish
}

void main() {
  group('showLocationRecoverySnack', () {
    testWidgets('available is a no-op — no SnackBar shown', (tester) async {
      await _pumpAndShow(tester, LocationAvailability.available);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('permissionDenied shows the specific message with an '
        '"Allow Location" action that retries', (tester) async {
      var retried = false;
      await _pumpAndShow(
        tester,
        LocationAvailability.permissionDenied,
        onRetry: () => retried = true,
      );

      final context = tester.element(find.byType(Scaffold));
      final l10n = AppLocalizations.of(context);
      expect(find.text(l10n.locationPermissionRequiredMessage), findsOneWidget);
      expect(find.text(l10n.locationAllowAction), findsOneWidget);

      await tester.tap(find.text(l10n.locationAllowAction));
      expect(retried, isTrue);
    });

    testWidgets('permissionPermanentlyDenied shows the Settings-specific '
        'message and action', (tester) async {
      await _pumpAndShow(tester, LocationAvailability.permissionPermanentlyDenied);

      final context = tester.element(find.byType(Scaffold));
      final l10n = AppLocalizations.of(context);
      expect(find.text(l10n.locationPermanentlyDeniedMessage), findsOneWidget);
      expect(find.text(l10n.commonOpenSettings), findsOneWidget);
    });

    testWidgets('serviceDisabled shows the GPS-off message and a "Turn On '
        'Location" action, distinct from the permission-denied wording',
        (tester) async {
      await _pumpAndShow(tester, LocationAvailability.serviceDisabled);

      final context = tester.element(find.byType(Scaffold));
      final l10n = AppLocalizations.of(context);
      expect(find.text(l10n.locationGpsOffMessage), findsOneWidget);
      expect(find.text(l10n.locationTurnOnAction), findsOneWidget);
      expect(l10n.locationGpsOffMessage, isNot(l10n.locationPermissionRequiredMessage));
    });

    testWidgets('unavailable shows the retry-specific message with a Retry '
        'action', (tester) async {
      var retried = false;
      await _pumpAndShow(
        tester,
        LocationAvailability.unavailable,
        onRetry: () => retried = true,
      );

      final context = tester.element(find.byType(Scaffold));
      final l10n = AppLocalizations.of(context);
      expect(find.text(l10n.locationUnavailableRetryMessage), findsOneWidget);
      expect(find.text(l10n.commonRetry), findsOneWidget);

      await tester.tap(find.text(l10n.commonRetry));
      expect(retried, isTrue);
    });
  });
}
