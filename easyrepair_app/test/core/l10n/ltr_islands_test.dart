import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/utils/currency_utils.dart';
import 'package:handygo_app/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:handygo_app/features/auth/presentation/widgets/otp_input_section.dart';
import 'package:pinput/pinput.dart';

import '../../support/l10n_test_app.dart';

/// Urdu flips the interface right-to-left, but a handful of values are Latin or
/// numeric and become unusable when mirrored. These must stay left-to-right
/// inside an otherwise RTL screen.

Future<TextField> _pumpField(
  WidgetTester tester, {
  required TextInputType keyboardType,
  bool obscureText = false,
}) async {
  await tester.pumpWidget(
    localizedApp(
      Scaffold(
        body: AuthTextField(
          controller: TextEditingController(),
          label: 'Field',
          keyboardType: keyboardType,
          obscureText: obscureText,
        ),
      ),
      locale: AppLocale.urdu,
    ),
  );
  await tester.pumpAndSettle();
  return tester.widget<TextField>(find.byType(TextField));
}

void main() {
  group('inputs that must stay LTR under Urdu', () {
    testWidgets('the page around them really is RTL', (tester) async {
      await _pumpField(tester, keyboardType: TextInputType.phone);

      final scaffold = tester.element(find.byType(Scaffold));
      expect(Directionality.of(scaffold), TextDirection.rtl);
    });

    testWidgets('phone number field', (tester) async {
      final field = await _pumpField(tester, keyboardType: TextInputType.phone);

      expect(field.textDirection, TextDirection.ltr);
      expect(field.textAlign, TextAlign.left);
    });

    testWidgets('password field', (tester) async {
      final field = await _pumpField(
        tester,
        keyboardType: TextInputType.visiblePassword,
        obscureText: true,
      );

      expect(field.textDirection, TextDirection.ltr);
    });

    testWidgets('email field', (tester) async {
      final field =
          await _pumpField(tester, keyboardType: TextInputType.emailAddress);

      expect(field.textDirection, TextDirection.ltr);
    });

    testWidgets('numeric field', (tester) async {
      final field = await _pumpField(tester, keyboardType: TextInputType.number);

      expect(field.textDirection, TextDirection.ltr);
    });

    testWidgets('an ordinary text field still follows the locale', (
      tester,
    ) async {
      // Only the technical field types are pinned — a name or an address must
      // still align the way the language expects.
      final field = await _pumpField(tester, keyboardType: TextInputType.text);

      expect(field.textDirection, isNull);
      expect(field.textAlign, TextAlign.start);
    });

    testWidgets('OTP boxes fill left-to-right', (tester) async {
      await tester.pumpWidget(
        localizedApp(
          Scaffold(
            body: OtpInputSection(
              expiresAt: DateTime.now().add(const Duration(minutes: 5)),
              onChanged: (_) {},
              onCompleted: (_) {},
              onResend: () {},
              resendInFlight: false,
            ),
          ),
          locale: AppLocale.urdu,
        ),
      );
      // Not pumpAndSettle: the section runs a countdown timer that never
      // settles.
      await tester.pump();

      final pinContext = tester.element(find.byType(Pinput));
      expect(Directionality.of(pinContext), TextDirection.ltr);
    });
  });

  group('prices stay readable in every language', () {
    testWidgets('formatPkr keeps Rs, Latin digits and comma grouping', (
      tester,
    ) async {
      for (final locale in AppLocale.values) {
        await tester.pumpWidget(
          localizedApp(
            Scaffold(body: Text(formatPkr(2500))),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Rs 2,500'),
          findsOneWidget,
          reason: 'price changed in ${locale.storageValue}',
        );
      }
    });

    test('no Urdu-Indic digits are introduced', () {
      expect(formatPkr(1234567), 'Rs 1,234,567');
      expect(RegExp(r'[٠-٩۰-۹]').hasMatch(formatPkr(1234567)), isFalse);
    });
  });
}
