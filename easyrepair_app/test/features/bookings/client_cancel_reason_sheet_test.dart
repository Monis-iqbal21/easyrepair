import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import '../../support/l10n_test_app.dart';
import 'package:handygo_app/features/bookings/presentation/widgets/client_cancel_reason_sheet.dart';

/// Pumps the sheet and returns the reasons captured by [onSubmit].
Future<List<String>> _pumpSheet(
  WidgetTester tester, {
  required bool hasAssignedWorker,
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
        locale: AppLocale.romanUrdu,
      ),
  );
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
  return captured;
}

Future<void> _selectReason(WidgetTester tester, String reason) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(reason).last);
  await tester.pumpAndSettle();
}

Finder get _submitBtn =>
    find.widgetWithText(TextButton, 'Booking cancel karein');

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
      await _pumpSheet(tester, hasAssignedWorker: true);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      for (final reason in const [
        'Ab service ki zarurat nahi',
        'Booking ghalti se ho gayi',
        'Masla khud hal ho gaya',
        'Waqt ya tareekh munasib nahi',
        'Qeemat ya budget munasib nahi',
        'Ustaad se rabta nahi ho raha',
        'Ustaad bohat dair kar raha hai',
        'Dusri wajah',
      ]) {
        expect(find.text(reason), findsWidgets, reason: 'missing: $reason');
      }
    });
  });

  group('worker-related reasons', () {
    testWidgets('hides them when no Ustaad has been assigned yet', (
      tester,
    ) async {
      await _pumpSheet(tester, hasAssignedWorker: false);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.text('Ustaad se rabta nahi ho raha'), findsNothing);
      expect(find.text('Ustaad bohat dair kar raha hai'), findsNothing);
      // …while the non-worker reasons remain available.
      expect(find.text('Ab service ki zarurat nahi'), findsWidgets);
      expect(find.text('Dusri wajah'), findsWidgets);
    });
  });

  group('validation', () {
    testWidgets('disables submit until a reason is selected', (tester) async {
      await _pumpSheet(tester, hasAssignedWorker: true);

      expect(tester.widget<TextButton>(_submitBtn).onPressed, isNull);

      await _selectReason(tester, 'Masla khud hal ho gaya');
      expect(tester.widget<TextButton>(_submitBtn).onPressed, isNotNull);
    });

    testWidgets('"Dusri wajah" requires custom text before submit enables', (
      tester,
    ) async {
      await _pumpSheet(tester, hasAssignedWorker: true);
      await _selectReason(tester, 'Dusri wajah');

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
      await _selectReason(tester, 'Dusri wajah');

      await tester.enterText(find.byType(TextField), '     ');
      await tester.pumpAndSettle();

      expect(tester.widget<TextButton>(_submitBtn).onPressed, isNull);
    });

    testWidgets('caps the custom reason at 300 characters', (tester) async {
      await _pumpSheet(tester, hasAssignedWorker: true);
      await _selectReason(tester, 'Dusri wajah');

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLength, kClientCancelReasonMaxLength);
      expect(kClientCancelReasonMaxLength, 300);
    });
  });

  group('what gets stored', () {
    testWidgets('stores the selected Roman Urdu label verbatim', (
      tester,
    ) async {
      final captured = await _pumpSheet(tester, hasAssignedWorker: true);
      await _selectReason(tester, 'Ustaad bohat dair kar raha hai');
      await tester.tap(_submitBtn);
      await tester.pumpAndSettle();

      expect(captured, ['Ustaad bohat dair kar raha hai']);
    });

    testWidgets(
      'stores ONLY the trimmed custom text for "Dusri wajah" (never the label)',
      (tester) async {
        final captured = await _pumpSheet(tester, hasAssignedWorker: true);
        await _selectReason(tester, 'Dusri wajah');
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
      await _selectReason(tester, 'Masla khud hal ho gaya');

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
      await _selectReason(tester, 'Masla khud hal ho gaya');

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
      await _selectReason(tester, 'Qeemat ya budget munasib nahi');
      await tester.tap(_submitBtn);
      await tester.pumpAndSettle();

      // Still open, still showing the chosen reason, and retryable.
      expect(find.text('Booking Cancel Karne Ki Wajah'), findsOneWidget);
      expect(find.text('Qeemat ya budget munasib nahi'), findsWidgets);
      expect(tester.widget<TextButton>(_submitBtn).onPressed, isNotNull);
    });

    testWidgets('"Wapas" closes without cancelling anything', (tester) async {
      final captured = await _pumpSheet(tester, hasAssignedWorker: true);
      await _selectReason(tester, 'Masla khud hal ho gaya');

      await tester.tap(find.widgetWithText(TextButton, 'Wapas'));
      await tester.pumpAndSettle();

      expect(captured, isEmpty);
      expect(find.text('Booking Cancel Karne Ki Wajah'), findsNothing);
    });
  });
}
