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

Future<void> _selectReason(
  WidgetTester tester,
  ClientCancelReason reason, {
  AppLocale locale = AppLocale.romanUrdu,
}) async {
  final l10n = await _l10nFor(locale);
  await tester.tap(find.byType(DropdownButtonFormField<ClientCancelReason>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(reason.label(l10n)).last);
  await tester.pumpAndSettle();
}

Finder get _submitBtn =>
    find.widgetWithText(TextButton, 'Booking cancel karein');

/// The submit button in whichever language the sheet is currently showing.
Future<Finder> _submitBtnIn(AppLocale locale) async =>
    find.widgetWithText(TextButton, (await _l10nFor(locale)).bookingCancelBooking);

void main() {
  group('ClientCancelReasonSheet — Roman Urdu wording', () {
    testWidgets('uses the exact required title and button labels', (
      tester,
    ) async {
      await _pumpSheet(tester, hasAssignedWorker: true);

      expect(find.text('Booking Cancel Karne Ki Wajah'), findsOneWidget);
      expect(find.text('Booking cancel karein'), findsOneWidget);
      expect(find.text('Wapas'), findsOneWidget);
    });

    testWidgets('offers all eight reasons when an Ustaad is assigned', (
      tester,
    ) async {
      final l10n = await _l10nFor(AppLocale.romanUrdu);
      await _pumpSheet(tester, hasAssignedWorker: true);
      await tester.tap(find.byType(DropdownButtonFormField<ClientCancelReason>));
      await tester.pumpAndSettle();

      expect(ClientCancelReason.values, hasLength(8));
      for (final reason in ClientCancelReason.values) {
        expect(
          find.text(reason.label(l10n)),
          findsWidgets,
          reason: 'missing: ${reason.name}',
        );
      }
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
        await tester
            .tap(find.byType(DropdownButtonFormField<ClientCancelReason>));
        await tester.pumpAndSettle();

        expect(find.text(expected), findsWidgets);
      });
    }

    test('every reason has a distinct label in each language', () async {
      for (final locale in AppLocale.values) {
        final l10n = await _l10nFor(locale);
        final labels =
            ClientCancelReason.values.map((r) => r.label(l10n)).toList();
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
      await tester.tap(find.byType(DropdownButtonFormField<ClientCancelReason>));
      await tester.pumpAndSettle();

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
        findsWidgets,
      );
      expect(find.text(ClientCancelReason.other.label(l10n)), findsWidgets);
    });
  });

  group('validation', () {
    testWidgets('disables submit until a reason is selected', (tester) async {
      await _pumpSheet(tester, hasAssignedWorker: true);

      expect(tester.widget<TextButton>(_submitBtn).onPressed, isNull);

      await _selectReason(tester, ClientCancelReason.problemSolved);
      expect(tester.widget<TextButton>(_submitBtn).onPressed, isNotNull);
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
      expect(tester.widget<TextButton>(_submitBtn).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '  Ghar par koi nahi  ');
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(_submitBtn).onPressed, isNotNull);
    });

    testWidgets('whitespace-only custom text does not enable submit', (
      tester,
    ) async {
      await _pumpSheet(tester, hasAssignedWorker: true);
      await _selectReason(tester, ClientCancelReason.other);

      await tester.enterText(find.byType(TextField), '     ');
      await tester.pumpAndSettle();

      expect(tester.widget<TextButton>(_submitBtn).onPressed, isNull);
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
          await tester.tap(await _submitBtnIn(locale));
          await tester.pumpAndSettle();

          expect(captured, ['Ustaad bohat dair kar raha hai']);
        },
      );
    }

    testWidgets(
      'stores ONLY the trimmed custom text for the free-text option',
      (tester) async {
        final captured = await _pumpSheet(tester, hasAssignedWorker: true);
        await _selectReason(tester, ClientCancelReason.other);
        await tester.enterText(find.byType(TextField), '  Ghar par koi nahi  ');
        await tester.pumpAndSettle();
        await tester.tap(_submitBtn);
        await tester.pumpAndSettle();

        expect(captured, ['Ghar par koi nahi']);
        expect(captured.first, isNot(contains('Dusri wajah')));
      },
    );
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

      // While the request is in flight the submit label is replaced by a
      // spinner, so there is physically nothing left to tap a second time.
      expect(_submitBtn, findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
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
      final l10n = await _l10nFor(AppLocale.romanUrdu);
      await _pumpSheet(
        tester,
        hasAssignedWorker: true,
        onSubmit: (_) async => throw Exception('network'),
      );
      await _selectReason(tester, ClientCancelReason.priceNotSuitable);
      await tester.tap(_submitBtn);
      await tester.pumpAndSettle();

      // Still open, still showing the chosen reason, and retryable.
      expect(find.text('Booking Cancel Karne Ki Wajah'), findsOneWidget);
      expect(
        find.text(ClientCancelReason.priceNotSuitable.label(l10n)),
        findsWidgets,
      );
      expect(tester.widget<TextButton>(_submitBtn).onPressed, isNotNull);
    });

    testWidgets('"Wapas" closes without cancelling anything', (tester) async {
      final captured = await _pumpSheet(tester, hasAssignedWorker: true);
      await _selectReason(tester, ClientCancelReason.problemSolved);

      await tester.tap(find.widgetWithText(TextButton, 'Wapas'));
      await tester.pumpAndSettle();

      expect(captured, isEmpty);
      expect(find.text('Booking Cancel Karne Ki Wajah'), findsNothing);
    });
  });
}
