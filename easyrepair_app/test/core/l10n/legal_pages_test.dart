import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/presentation/pages/privacy_policy_page.dart';
import 'package:handygo_app/core/presentation/pages/terms_conditions_page.dart';

import '../../support/l10n_test_app.dart';

/// The Privacy Policy and Terms bodies are approved in English only. The page
/// chrome around them is localized; the documents themselves are not, and must
/// not be machine-translated. See docs/legal_translation_exclusions.md.

const _legalPages = {
  'lib/core/presentation/pages/privacy_policy_page.dart':
      'Privacy Policy body',
  'lib/core/presentation/pages/terms_conditions_page.dart':
      'Terms and Conditions body',
};

void main() {
  group('the English-only notice speaks the reader\'s language', () {
    for (final (locale, expected) in [
      (AppLocale.english,
       'This legal document is currently available in English only.'),
      (AppLocale.urdu, 'یہ قانونی دستاویز فی الحال صرف انگریزی میں دستیاب ہے۔'),
      (AppLocale.romanUrdu,
       'Yeh qanooni document filhal sirf English mein available hai.'),
    ]) {
      testWidgets('Privacy Policy — ${locale.storageValue}', (tester) async {
        await tester.pumpWidget(
          localizedApp(const PrivacyPolicyPage(), locale: locale),
        );
        await tester.pumpAndSettle();

        expect(find.text(expected), findsOneWidget);
      });

      testWidgets('Terms — ${locale.storageValue}', (tester) async {
        await tester.pumpWidget(
          localizedApp(const TermsConditionsPage(), locale: locale),
        );
        await tester.pumpAndSettle();

        expect(find.text(expected), findsOneWidget);
      });
    }
  });

  testWidgets('the document body stays English and left-to-right under Urdu', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(const PrivacyPolicyPage(), locale: AppLocale.urdu),
    );
    await tester.pumpAndSettle();

    // The page itself is mirrored...
    expect(
      Directionality.of(tester.element(find.byType(Scaffold))),
      TextDirection.rtl,
    );
    // ...but the approved English clauses are not.
    final clause = find.text('1. Information We Collect');
    expect(clause, findsOneWidget);
    expect(Directionality.of(tester.element(clause)), TextDirection.ltr);
  });

  test('the legal bodies stay marked so the audit reports them as Category 5',
      () {
    for (final entry in _legalPages.entries) {
      final source = File(entry.key).readAsStringSync();
      expect(
        source.contains('L10N-LEGAL-BODY:START'),
        isTrue,
        reason: '${entry.value}: the audit marker was removed, so the '
            'document would be reported as missed translation work',
      );
      expect(source.contains('L10N-LEGAL-BODY:END'), isTrue);
    }
  });

  test('no legal clause was quietly moved into the ARB files', () {
    // A phrase from each document. If either ever appears in app_en.arb, the
    // body has been pulled into the translation pipeline and would be machine
    // translated — exactly what the legal exclusion forbids.
    final arb = File('lib/l10n/app_en.arb').readAsStringSync();
    for (final clause in [
      'is committed to protecting your',
      'By creating an account or using our',
      'Last updated',
    ]) {
      expect(
        arb.contains(clause),
        isFalse,
        reason: 'legal text "$clause" leaked into app_en.arb',
      );
    }
  });
}
