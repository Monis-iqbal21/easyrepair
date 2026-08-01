import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/utils/distance_utils.dart';
import 'package:handygo_app/l10n/app_localizations.dart';

import '../../support/l10n_test_app.dart';

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
  group('distance labels', () {
    testWidgets('the wording follows the language', (tester) async {
      final en = await _l10nFor(tester, AppLocale.english);
      final ur = await _l10nFor(tester, AppLocale.urdu);
      final urLatn = await _l10nFor(tester, AppLocale.romanUrdu);

      expect(formatDistanceLabel(en, 10), en.distanceAtYourLocation);
      expect(formatDistanceLabel(ur, 10), ur.distanceAtYourLocation);
      expect(formatDistanceLabel(urLatn, 10), urLatn.distanceAtYourLocation);

      expect(
        {
          formatDistanceLabel(en, 10),
          formatDistanceLabel(ur, 10),
          formatDistanceLabel(urLatn, 10),
        }.length,
        3,
        reason: 'one language is leaking into another',
      );
    });

    testWidgets('each range picks the rounding it reads best in', (
      tester,
    ) async {
      final en = await _l10nFor(tester, AppLocale.english);

      expect(formatDistanceLabel(en, 250), '250 m away');
      expect(formatDistanceLabel(en, 1800), '1.8 km away');
      expect(formatDistanceLabel(en, 24600), '25 km away');
    });

    testWidgets('the number itself never changes script', (tester) async {
      final urduIndicDigits = RegExp(r'[٠-٩۰-۹]');
      for (final locale in AppLocale.values) {
        final l10n = await _l10nFor(tester, locale);
        for (final meters in [250.0, 1800.0, 24600.0]) {
          final label = formatDistanceLabel(l10n, meters);
          expect(
            urduIndicDigits.hasMatch(label),
            isFalse,
            reason: '$label used non-Latin digits in ${locale.storageValue}',
          );
          expect(RegExp(r'\d').hasMatch(label), isTrue);
        }
      }
    });
  });
}
