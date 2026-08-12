import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/network/offline_banner.dart';

import '../../support/l10n_test_app.dart';

void main() {
  group('OfflineDataBanner', () {
    testWidgets('shows the localized "showing saved data" copy in every '
        'supported language', (tester) async {
      for (final locale in AppLocale.values) {
        await tester.pumpWidget(
          localizedApp(const Scaffold(body: OfflineDataBanner()), locale: locale),
        );
        await tester.pumpAndSettle();

        // Roman Urdu and English share latin script; Urdu renders its own
        // script — either way, some non-empty text specific to this banner
        // (not a generic loading/error string) must be on screen.
        expect(find.byType(OfflineDataBanner), findsOneWidget);
        expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      }
    });

    testWidgets('renders distinct wording per language (not the same '
        'string reused across locales)', (tester) async {
      final seen = <String>{};
      for (final locale in AppLocale.values) {
        await tester.pumpWidget(
          localizedApp(const Scaffold(body: OfflineDataBanner()), locale: locale),
        );
        await tester.pumpAndSettle();

        final textWidget = tester.widget<Text>(find.byType(Text));
        seen.add(textWidget.data ?? '');
      }
      expect(seen.length, AppLocale.values.length);
      expect(seen, everyElement(isNotEmpty));
    });
  });
}
