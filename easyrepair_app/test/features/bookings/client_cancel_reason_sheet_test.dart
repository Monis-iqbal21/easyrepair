import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/l10n/app_localizations.dart';
import '../../support/l10n_test_app.dart';
import 'package:handygo_app/features/bookings/presentation/widgets/client_cancel_reason_sheet.dart';

/// Pumps the sheet and returns the reasons captured by [onSubmit].
Future<List<String>> _pumpSheet(
  WidgetTester tester, {
  required bool hasAssignedWorker,
  AppLocale locale = AppLocale.romanUrdu,
  Future<void> Function(String)? onSubmit,
}) async {
  final captured = <String>[];
  await tester.pumpWidget(
    localizedApp(
      Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showClientCancelReasonSheet(
              context: context,
              hasAssignedWorker: hasAssignedWorker,
              onSubmit: (reason) async {
                captured.add(reason);
                if (onSubmit != null) await onSubmit(reason);
              },
            ),
            child: const Text('OPEN'),
          ),
        ),
      ),
      locale: locale,
    ),
  );
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
  return captured;
}

Future<AppLocalizations> _l10nFor(AppLocale locale) =>
    AppLocalizations.delegate.load(locale.locale);

/// Scrolls [reason]'s row into view without tapping it. The reason list is a
/// scroller, so a row further down is not built until it is reached.
Future<Finder> _revealReason(
  WidgetTester tester,
  ClientCancelReason reason, {
  AppLocale locale = AppLocale.romanUrdu,
}) async {
  final l10n = await _l10nFor(locale);
  final target = find.text(reason.label(l10n));
  if (target.evaluate().isEmpty) {
    // Back to the top first, so one downward sweep always reaches the row
    // wherever the list happens to be scrolled.
    await tester.drag(find.byType(ListView), const Offset(0, 800));
    await tester.pumpAndSettle();
  }
  if (target.evaluate().isEmpty) {
    await tester.dragUntilVisible(
      target,
      find.byType(ListView),
      const Offset(0, -80),
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  return target;
}

/// Picks a reason from the radio list.
Future<void> _selectReason(
  WidgetTester tester,
  ClientCancelReason reason, {
  AppLocale locale = AppLocale.romanUrdu,
}) async {
  final target = await _revealReason(tester, reason, locale: locale);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Finder get _submitBtn => find.byKey(const Key('confirm-cancellation-button'));
Finder get _backBtn => find.byKey(const Key('keep-booking-button'));

/// Reads the real Material button inside the shared primitive — that is what
/// actually refuses a tap, both when nothing is selected and while a
/// cancellation is in flight.
bool _enabled(WidgetTester tester, Finder button) =>
    tester
        .widget<ButtonStyleButton>(
          find.descendant(
            of: button,
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          ),
        )
        .onPressed !=
    null;

void main() {
  group('ClientCancelReasonSheet — Roman Urdu wording', () {
    testWidgets('uses the exact required title and button labels', (
      tester,
    ) async {
      await _pumpSheet(tester, hasAssignedWorker: true);

      expect(find.text('Booking cancel karne ki wajah'), findsOneWidget);
      expect(find.text('Booking cancel karein'), findsOneWidget);
      expect(find.text('Wapas'), findsOneWidget);
    });

    testWidgets('offers all eight reasons when an Ustaad is assigned', (
      tester,
    ) async {
      final l10n = await _l10nFor(AppLocale.romanUrdu);
      await _pumpSheet(tester, hasAssignedWorker: true);

      expect(ClientCancelReason.values, hasLength(8));
      for (final reason in ClientCancelReason.values) {
        await _revealReason(tester, reason);
        expect(
          find.text(reason.label(l10n)),
          findsOneWidget,
          reason: 'missing: ${reason.name}',
        );
      }
    });

    testWidgets('every reason is laid out as a tappable radio row', (
      tester,
    ) async {
      await _pumpSheet(tester, hasAssignedWorker: true);

      // Radio rows, none of them selected before the client picks one.
      expect(find.byIcon(Icons.radio_button_unchecked), findsWidgets);
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);

      await _selectReason(tester, ClientCancelReason.problemSolved);

      // Exactly one selected — the list is genuinely single-select.
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);

      await _selectReason(tester, ClientCancelReason.timingNotSuitable);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    });
  });

  group('the displayed label follows the app language', () {
    for (final (locale, expected) in [
      (AppLocale.english, 'The problem sorted itself out'),
      (AppLocale.urdu, 'مسئلہ خود حل ہو گیا'),
      (AppLocale.romanUrdu, 'Masla khud hal ho gaya'),
    ]) {
      testWidgets('${locale.storageValue} shows "$expected"', (tester) async {
        await _pumpSheet(tester, hasAssignedWorker: true, locale: locale);

        expect(find.text(expected), findsOneWidget);
      });
    }

    test('every reason has a distinct label in each language', () async {
      for (final locale in AppLocale.values) {
        final l10n = await _l10nFor(locale);
        final labels = ClientCancelReason.values
            .map((r) => r.label(l10n))
            .toList();
        expect(
          labels.toSet(),
          hasLength(labels.length),
          reason: 'duplicate labels in ${locale.storageValue}: $labels',
        );
      }
    });
  });

  group('worker-related reasons', () {
    testWidgets('hides them when no Ustaad has been assigned yet', (
      tester,
    ) async {
      final l10n = await _l10nFor(AppLocale.romanUrdu);
      await _pumpSheet(tester, hasAssignedWorker: false);

      expect(
        find.text(ClientCancelReason.cannotReachUstaad.label(l10n)),
        findsNothing,
      );
      expect(
        find.text(ClientCancelReason.ustaadRunningLate.label(l10n)),
        findsNothing,
      );
      // …while the non-worker reasons remain available.
      expect(
        find.text(ClientCancelReason.noLongerNeeded.label(l10n)),
        findsOneWidget,
      );
      expect(find.text(ClientCancelReason.other.label(l10n)), findsOneWidget);
    });
  });

  group('validation', () {
    testWidgets('disables submit until a reason is selected', (tester) async {
      await _pumpSheet(tester, hasAssignedWorker: true);

      expect(_enabled(tester, _submitBtn), isFalse);

      await _selectReason(tester, ClientCancelReason.problemSolved);
      expect(_enabled(tester, _submitBtn), isTrue);
    });

    testWidgets('the free-text option requires text before submit enables', (
      tester,
    ) async {
      await _pumpSheet(tester, hasAssignedWorker: true);
      await _selectReason(tester, ClientCancelReason.other);

      // The free-text field appears with the required placeholder, and submit
      // stays disabled while it is empty.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Apni wajah likhein'), findsOneWidget);
      expect(_enabled(tester, _submitBtn), isFalse);

      await tester.enterText(find.byType(TextField), '  Ghar par koi nahi  ');
      await tester.pumpAndSettle();
      expect(_enabled(tester, _submitBtn), isTrue);
    });

    testWidgets('the free-text field only exists once "other" is picked', (
      tester,
    ) async {
      await _pumpSheet(tester, hasAssignedWorker: true);
      expect(find.byType(TextField), findsNothing);

      await _selectReason(tester, ClientCancelReason.other);
      expect(find.byType(TextField), findsOneWidget);

      await _selectReason(tester, ClientCancelReason.problemSolved);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('whitespace-only custom text does not enable submit', (
      tester,
    ) async {
      await _pumpSheet(tester, hasAssignedWorker: true);
      await _selectReason(tester, ClientCancelReason.other);

      await tester.enterText(find.byType(TextField), '     ');
      await tester.pumpAndSettle();

      expect(_enabled(tester, _submitBtn), isFalse);
    });

    testWidgets('caps the custom reason at 300 characters', (tester) async {
      await _pumpSheet(tester, hasAssignedWorker: true);
      await _selectReason(tester, ClientCancelReason.other);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLength, kClientCancelReasonMaxLength);
      expect(kClientCancelReasonMaxLength, 300);
    });
  });

  group('what gets stored', () {
    // The stored value is what an Ustaad, an admin or support later reads on
    // the booking, and it is already persisted against live bookings — so it
    // must not move when the client's language does.
    test('stored values are the original Roman Urdu strings', () {
      expect(
        ClientCancelReason.values.map((r) => r.storedValue).toList(),
        const [
          'Ab service ki zarurat nahi',
          'Booking ghalti se ho gayi',
          'Masla khud hal ho gaya',
          'Waqt ya tareekh munasib nahi',
          'Qeemat ya budget munasib nahi',
          'Ustaad se rabta nahi ho raha',
          'Ustaad bohat dair kar raha hai',
          'Dusri wajah',
        ],
      );
    });

    for (final locale in AppLocale.values) {
      testWidgets(
        'stores the same value in ${locale.storageValue} as in any other language',
        (tester) async {
          final captured = await _pumpSheet(
            tester,
            hasAssignedWorker: true,
            locale: locale,
          );
          await _selectReason(
            tester,
            ClientCancelReason.ustaadRunningLate,
            locale: locale,
          );
          await tester.tap(_submitBtn);
          await tester.pumpAndSettle();

          expect(captured, ['Ustaad bohat dair kar raha hai']);
        },
      );
    }

    testWidgets('stores ONLY the trimmed custom text for the free-text option', (
      tester,
    ) async {
      final captured = await _pumpSheet(tester, hasAssignedWorker: true);
      await _selectReason(tester, ClientCancelReason.other);
      await tester.enterText(find.byType(TextField), '  Ghar par koi nahi  ');
      await tester.pumpAndSettle();
      await tester.tap(_submitBtn);
      await tester.pumpAndSettle();

      expect(captured, ['Ghar par koi nahi']);
      expect(captured.first, isNot(contains('Dusri wajah')));
    });
  });

  group('submission', () {
    testWidgets('blocks a double submission while one is in flight', (
      tester,
    ) async {
      final captured = await _pumpSheet(
        tester,
        hasAssignedWorker: true,
        onSubmit: (_) => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await _selectReason(tester, ClientCancelReason.problemSolved);

      await tester.tap(_submitBtn);
      await tester.pump(); // enter loading state

      // While the request is in flight the button is disabled, so a second
      // tap cannot reach the handler — and the handler's own single-flight
      // guard would refuse it even if it did.
      expect(_enabled(tester, _submitBtn), isFalse);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(_submitBtn, warnIfMissed: false);
      await tester.pump();
      expect(captured, hasLength(1));

      await tester.pumpAndSettle();
      expect(captured, hasLength(1));
    });

    testWidgets('shows a loading state while cancelling', (tester) async {
      await _pumpSheet(
        tester,
        hasAssignedWorker: true,
        onSubmit: (_) => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await _selectReason(tester, ClientCancelReason.problemSolved);

      await tester.tap(_submitBtn);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('keeps the sheet open and the reason picked when it fails', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        hasAssignedWorker: true,
        onSubmit: (_) async => throw Exception('network'),
      );
      await _selectReason(tester, ClientCancelReason.priceNotSuitable);
      await tester.tap(_submitBtn);
      await tester.pumpAndSettle();

      // Still open, still showing the chosen reason selected, and retryable.
      expect(find.text('Booking cancel karne ki wajah'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(_enabled(tester, _submitBtn), isTrue);
    });

    testWidgets('"Wapas" closes without cancelling anything', (tester) async {
      final captured = await _pumpSheet(tester, hasAssignedWorker: true);
      await _selectReason(tester, ClientCancelReason.problemSolved);

      await tester.tap(_backBtn);
      await tester.pumpAndSettle();

      expect(captured, isEmpty);
      expect(find.text('Booking cancel karne ki wajah'), findsNothing);
    });
  });

  group('responsive', () {
    // Long Urdu reasons on the narrowest supported handset, at the largest
    // text scale we support: everything must wrap, nothing may overflow.
    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      testWidgets('lays out at ${width.toInt()}px with no overflow', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await _pumpSheet(
          tester,
          hasAssignedWorker: true,
          locale: AppLocale.urdu,
        );
        await _selectReason(
          tester,
          ClientCancelReason.other,
          locale: AppLocale.urdu,
        );

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('confirm-cancellation-button')), findsOne);
      });
    }

    testWidgets('survives a 2.0 text scale at 320px', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        localizedApp(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showClientCancelReasonSheet(
                      context: context,
                      hasAssignedWorker: true,
                      onSubmit: (_) async {},
                    ),
                    child: const Text('OPEN'),
                  ),
                ),
              ),
            ),
          ),
          locale: AppLocale.urdu,
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('confirm-cancellation-button')), findsOne);
      expect(find.byKey(const Key('keep-booking-button')), findsOne);
    });
  });
}
