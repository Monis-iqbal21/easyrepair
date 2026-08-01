import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/errors/failure_messages.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/l10n/app_localizations.dart';

import '../../support/l10n_test_app.dart';

/// Resolves [AppLocalizations] for a locale by pumping a real MaterialApp,
/// which is the only supported way to build the generated class.
Future<AppLocalizations> _l10nFor(WidgetTester tester, AppLocale locale) async {
  late AppLocalizations resolved;
  await tester.pumpWidget(
    localizedApp(
      Builder(
        builder: (context) {
          resolved = AppLocalizations.of(context);
          return const SizedBox.shrink();
        },
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
  return resolved;
}

void main() {
  group('failureMessage', () {
    testWidgets('a sentence written by the backend is shown verbatim', (
      tester,
    ) async {
      const backendText = 'Ye booking pehle hi cancel ho chuki hai.';
      for (final locale in AppLocale.values) {
        final l10n = await _l10nFor(tester, locale);

        expect(
          failureMessage(l10n, const ConflictFailure(backendText)),
          backendText,
          reason: 'backend copy was rewritten in ${locale.storageValue}',
        );
      }
    });

    testWidgets('an app-owned code is rendered in the selected language', (
      tester,
    ) async {
      final en = await _l10nFor(tester, AppLocale.english);
      final ur = await _l10nFor(tester, AppLocale.urdu);
      final urLatn = await _l10nFor(tester, AppLocale.romanUrdu);

      const failure = UnauthorizedFailure('');

      expect(failureMessage(en, failure), en.errorSessionExpired);
      expect(failureMessage(ur, failure), ur.errorSessionExpired);
      expect(failureMessage(urLatn, failure), urLatn.errorSessionExpired);

      // Three genuinely different strings, not one language leaking.
      expect(
        {
          failureMessage(en, failure),
          failureMessage(ur, failure),
          failureMessage(urLatn, failure),
        }.length,
        3,
      );
    });

    testWidgets('the screen fallback wins only when nothing is known', (
      tester,
    ) async {
      final l10n = await _l10nFor(tester, AppLocale.english);

      expect(
        failureMessage(
          l10n,
          const ServerFailure('', code: FailureCode.unknown),
          fallback: 'Could not cancel this booking.',
        ),
        'Could not cancel this booking.',
      );
      // A known code is more specific than the screen's generic wording.
      expect(
        failureMessage(
          l10n,
          const NetworkFailure('', code: FailureCode.timeout),
          fallback: 'Could not cancel this booking.',
        ),
        l10n.errorTimeout,
      );
    });

    testWidgets('a non-Failure error still produces readable text', (
      tester,
    ) async {
      final l10n = await _l10nFor(tester, AppLocale.english);

      expect(failureMessage(l10n, Exception('boom')), l10n.errorUnknown);
      expect(
        failureMessage(l10n, null, fallback: 'Upload failed.'),
        'Upload failed.',
      );
    });

    testWidgets('every FailureCode has wording in every language', (
      tester,
    ) async {
      for (final locale in AppLocale.values) {
        final l10n = await _l10nFor(tester, locale);
        for (final code in FailureCode.values) {
          final text = failureCodeMessage(l10n, code);
          expect(
            text.trim(),
            isNotEmpty,
            reason: '$code has no wording in ${locale.storageValue}',
          );
        }
      }
    });
  });
}
