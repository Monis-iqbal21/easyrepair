import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/features/client/domain/entities/customer_agreement_entity.dart';
import 'package:handygo_app/features/client/presentation/pages/customer_agreement_gate_page.dart';
import 'package:handygo_app/features/client/presentation/pages/customer_agreement_viewer_page.dart';
import 'package:handygo_app/features/client/presentation/providers/customer_agreement_providers.dart';

import '../../support/l10n_test_app.dart';

const _legalBody = 'This is the full legal body text for testing purposes.';

CustomerAgreementStatusEntity _pendingStatus() => const CustomerAgreementStatusEntity(
      acceptanceRequired: true,
      agreement: CustomerAgreementEntity(
        documentType: kCustomerTermsDocumentType,
        title: 'HandyGo Customer Terms, Booking Rules aur Privacy Notice',
        version: '1.0',
        agreementLocale: 'ur_Latn',
        sourceHash:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        contentText: _legalBody,
        legalLanguageNoticeRequired: false,
        requestedAppLocale: 'en',
      ),
      existingAcceptance: null,
    );

/// Never actually calls the repository — a widget test drives only the UI
/// contract: it starts loading, then resolves to either success or a
/// specific error, and never marks anything accepted without going through
/// this exact sequence.
class _FakeAcceptNotifier extends AcceptCustomerAgreementNotifier {
  _FakeAcceptNotifier({this.error});
  final Object? error;
  int calls = 0;

  @override
  Future<void> build() async {}

  @override
  Future<bool> accept({String? deviceDescriptor}) async {
    calls++;
    state = const AsyncLoading();
    await Future<void>.delayed(Duration.zero);
    if (error != null) {
      state = AsyncError(error!, StackTrace.current);
      return false;
    }
    state = const AsyncData(null);
    return true;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  _FakeAcceptNotifier? acceptNotifier,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        requiredCustomerAgreementProvider.overrideWith((ref) async => _pendingStatus()),
        if (acceptNotifier != null)
          acceptCustomerAgreementProvider.overrideWith(() => acceptNotifier),
      ],
      child: localizedApp(const CustomerAgreementGatePage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('checkbox and I Agree gating', () {
    testWidgets('the checkbox starts unchecked — never pre-selected', (tester) async {
      await _pump(tester);
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
    });

    testWidgets('I Agree is disabled until the checkbox is ticked', (tester) async {
      await _pump(tester);

      final before =
          tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'I Agree'));
      expect(before.onPressed, isNull);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      final after =
          tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'I Agree'));
      expect(after.onPressed, isNotNull);
    });

    testWidgets('unticking the checkbox disables I Agree again', (tester) async {
      await _pump(tester);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      final button =
          tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'I Agree'));
      expect(button.onPressed, isNull);
    });
  });

  group('non-dismissibility', () {
    testWidgets('has no AppBar / close button', (tester) async {
      await _pump(tester);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('system back does not dismiss the gate', (tester) async {
      // Push the gate on top of a real screen so a successful pop would be
      // observable — PopScope(canPop:false) must keep it on top regardless.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            requiredCustomerAgreementProvider
                .overrideWith((ref) async => _pendingStatus()),
          ],
          child: localizedApp(
            Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CustomerAgreementGatePage(),
                      ),
                    ),
                    child: const Text('open gate'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open gate'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerAgreementGatePage), findsOneWidget);

      // Simulate the Android system back button / gesture.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(CustomerAgreementGatePage), findsOneWidget);
      expect(find.text('open gate'), findsNothing);
    });
  });

  group('submission', () {
    testWidgets('a failed submission keeps the gate open and shows a retryable error', (
      tester,
    ) async {
      final notifier = _FakeAcceptNotifier(error: Exception('boom'));
      await _pump(tester, acceptNotifier: notifier);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'I Agree'));
      await tester.pumpAndSettle();

      expect(notifier.calls, 1);
      expect(find.byType(CustomerAgreementGatePage), findsOneWidget);
      expect(
        find.text('Acceptance could not be saved. Please try again.'),
        findsOneWidget,
      );
      // The checkbox stays ticked and the button stays enabled — a retry
      // should not force the Client to re-read and re-tick.
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
    });

    testWidgets('a successful submission calls accept exactly once', (tester) async {
      final notifier = _FakeAcceptNotifier();
      await _pump(tester, acceptNotifier: notifier);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'I Agree'));
      await tester.pumpAndSettle();

      expect(notifier.calls, 1);
      // Success surfaces no inline error — the router (tested separately in
      // customer_agreement_redirect_test.dart) is what actually navigates
      // away once requiredCustomerAgreementProvider re-resolves.
      expect(
        find.text('Acceptance could not be saved. Please try again.'),
        findsNothing,
      );
    });

    testWidgets('I Agree shows a loading spinner while submitting', (tester) async {
      final notifier = _FakeAcceptNotifier();
      await _pump(tester, acceptNotifier: notifier);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'I Agree'));
      await tester.pump(); // one frame — mid-submission, before it settles

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    // Chunk 3 launch-hardening: a double-tap that races past the disabled
    // button (both taps land before the first rebuild shows the spinner)
    // must still only fire one accept request.
    testWidgets('repeated tap before the spinner renders triggers only one accept request', (
      tester,
    ) async {
      final notifier = _FakeAcceptNotifier();
      await _pump(tester, acceptNotifier: notifier);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      final button = find.widgetWithText(ElevatedButton, 'I Agree');
      // Two taps back-to-back, no pump in between — simulates a real
      // double-tap landing before the widget rebuilds with isLoading:true.
      await tester.tap(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(notifier.calls, 1);
    });
  });

  group('reading the agreement', () {
    testWidgets('the full legal text is shown inline, scrollable', (tester) async {
      await _pump(tester);
      expect(find.text(_legalBody), findsOneWidget);
    });

    testWidgets('View/Download PDF opens the full-text viewer', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('View/Download PDF'));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerAgreementViewerPage), findsOneWidget);
      expect(find.text(_legalBody), findsOneWidget);
    });

    testWidgets('viewing is optional — checkbox never requires it first', (
      tester,
    ) async {
      await _pump(tester);
      // Tick without ever opening the viewer.
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      final button =
          tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'I Agree'));
      expect(button.onPressed, isNotNull);
    });
  });
}
