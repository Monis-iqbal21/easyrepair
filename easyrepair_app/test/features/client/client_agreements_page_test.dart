import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/features/client/domain/entities/customer_agreement_entity.dart';
import 'package:handygo_app/features/client/presentation/pages/client_agreements_page.dart';
import 'package:handygo_app/features/client/presentation/providers/customer_agreement_providers.dart';

import '../../support/l10n_test_app.dart';

AcceptedCustomerAgreementEntity _record({
  String id = 'row-1',
  String? acceptanceId = 'HG-ACC-2026-ABCDEF123456',
}) {
  return AcceptedCustomerAgreementEntity(
    id: id,
    acceptanceId: acceptanceId,
    documentType: kCustomerTermsDocumentType,
    title: 'HandyGo Customer Terms, Booking Rules aur Privacy Notice',
    version: '1.0',
    agreementLocale: 'ur_Latn',
    acceptedAt: DateTime(2026, 8, 7),
  );
}

class _FakeDownloadNotifier extends DownloadCustomerAgreementNotifier {
  int calls = 0;
  String? lastAcceptanceId;

  @override
  Future<void> build() async {}

  @override
  Future<List<int>?> download(String acceptanceId) async {
    calls++;
    lastAcceptanceId = acceptanceId;
    state = const AsyncLoading();
    final result = List<int>.filled(10, 1);
    state = const AsyncData(null);
    return result;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required List<AcceptedCustomerAgreementEntity> history,
  Object? historyError,
  _FakeDownloadNotifier? downloadNotifier,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (historyError != null)
          customerAgreementHistoryProvider.overrideWith((ref) async {
            throw historyError;
          })
        else
          customerAgreementHistoryProvider.overrideWith((ref) async => history),
        if (downloadNotifier != null)
          downloadCustomerAgreementProvider.overrideWith(() => downloadNotifier),
      ],
      child: localizedApp(const ClientAgreementsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final messenger = binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.createTempSync('handygo').path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async => true,
    );
  });

  group('accepted agreement history', () {
    testWidgets('shows the empty state when nothing has been accepted', (
      tester,
    ) async {
      await _pump(tester, history: const []);
      expect(
        find.text('You have not accepted any agreements yet.'),
        findsOneWidget,
      );
    });

    testWidgets('lists the title, version and accepted date', (tester) async {
      await _pump(tester, history: [_record()]);

      expect(
        find.text('HandyGo Customer Terms, Booking Rules aur Privacy Notice'),
        findsOneWidget,
      );
      expect(find.text('Version 1.0'), findsOneWidget);
      expect(find.textContaining('Accepted on'), findsOneWidget);
    });

    testWidgets('shows a retryable error when the history fails to load', (
      tester,
    ) async {
      await _pump(tester, history: const [], historyError: Exception('boom'));
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('viewing a record shows its Acceptance ID', (tester) async {
      await _pump(tester, history: [_record()]);

      await tester.tap(find.text('View Agreement'));
      await tester.pumpAndSettle();

      expect(find.textContaining('HG-ACC-2026-ABCDEF123456'), findsOneWidget);
    });

    testWidgets('downloading calls the download provider with the acceptance id', (
      tester,
    ) async {
      final notifier = _FakeDownloadNotifier();
      await _pump(tester, history: [_record()], downloadNotifier: notifier);

      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();

      expect(notifier.calls, 1);
      expect(notifier.lastAcceptanceId, 'HG-ACC-2026-ABCDEF123456');
    });

    testWidgets('multiple accepted records each render their own card', (
      tester,
    ) async {
      await _pump(
        tester,
        history: [
          _record(id: 'row-1', acceptanceId: 'HG-ACC-2026-AAAAAAAAAAAA'),
          _record(id: 'row-2', acceptanceId: 'HG-ACC-2026-BBBBBBBBBBBB'),
        ],
      );

      expect(find.text('Version 1.0'), findsNWidgets(2));
    });
  });
}
