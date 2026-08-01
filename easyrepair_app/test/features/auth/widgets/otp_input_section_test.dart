import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/l10n_test_app.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/features/auth/presentation/widgets/otp_input_section.dart';

// Roman Urdu: these assertions cover the exact copy this screen shipped with
// before localization, which now lives in app_ur_Latn.arb.
Widget _wrap(Widget child) =>
    localizedApp(Scaffold(body: child), locale: AppLocale.romanUrdu);

void main() {
  group('OtpInputSection', () {
    testWidgets('shows a counting-down timer derived from expiresAt', (
      tester,
    ) async {
      final expiresAt = DateTime.now().add(const Duration(minutes: 4, seconds: 59));
      await tester.pumpWidget(
        _wrap(
          OtpInputSection(
            expiresAt: expiresAt,
            onChanged: (_) {},
            onCompleted: (_) {},
            onResend: () {},
            resendInFlight: false,
          ),
        ),
      );

      expect(find.textContaining('mein expire hoga'), findsOneWidget);
      expect(find.textContaining('04:5'), findsOneWidget);
    });

    testWidgets('flips to expired wording once expiresAt has passed', (
      tester,
    ) async {
      final expiresAt = DateTime.now().subtract(const Duration(seconds: 1));
      await tester.pumpWidget(
        _wrap(
          OtpInputSection(
            expiresAt: expiresAt,
            onChanged: (_) {},
            onCompleted: (_) {},
            onResend: () {},
            resendInFlight: false,
          ),
        ),
      );

      expect(
        find.text('Code expire ho gaya hai. Naya code mangwayein.'),
        findsOneWidget,
      );
    });

    testWidgets('resend link is disabled until 60 seconds have passed since request', (
      tester,
    ) async {
      // expiresAt = now + 5min means the OTP was "requested" now — resend
      // should not be available yet.
      final expiresAt = DateTime.now().add(const Duration(minutes: 5));
      await tester.pumpWidget(
        _wrap(
          OtpInputSection(
            expiresAt: expiresAt,
            onChanged: (_) {},
            onCompleted: (_) {},
            onResend: () {},
            resendInFlight: false,
          ),
        ),
      );

      expect(find.textContaining('Code dobara bhejein ('), findsOneWidget);
    });

    testWidgets('resend link becomes tappable once the cooldown has passed', (
      tester,
    ) async {
      // requestedAt = expiresAt - 5min. To simulate 61s since request, set
      // expiresAt to (now - 61s + 5min) = now + 4min59s worth back-computed.
      final requestedAt = DateTime.now().subtract(const Duration(seconds: 61));
      final expiresAt = requestedAt.add(const Duration(minutes: 5));
      var resendTapped = false;

      await tester.pumpWidget(
        _wrap(
          OtpInputSection(
            expiresAt: expiresAt,
            onChanged: (_) {},
            onCompleted: (_) {},
            onResend: () => resendTapped = true,
            resendInFlight: false,
          ),
        ),
      );

      final resendFinder = find.text('Code dobara bhejein');
      expect(resendFinder, findsOneWidget);
      await tester.tap(resendFinder);
      expect(resendTapped, isTrue);
    });

    testWidgets('shows a spinner instead of the resend link while a resend is in flight', (
      tester,
    ) async {
      final requestedAt = DateTime.now().subtract(const Duration(seconds: 61));
      final expiresAt = requestedAt.add(const Duration(minutes: 5));

      await tester.pumpWidget(
        _wrap(
          OtpInputSection(
            expiresAt: expiresAt,
            onChanged: (_) {},
            onCompleted: (_) {},
            onResend: () {},
            resendInFlight: true,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Code dobara bhejein'), findsNothing);
    });

    testWidgets('recomputes the countdown when expiresAt changes (e.g. after resend)', (
      tester,
    ) async {
      final firstExpiry = DateTime.now().add(const Duration(seconds: 10));
      await tester.pumpWidget(
        _wrap(
          OtpInputSection(
            expiresAt: firstExpiry,
            onChanged: (_) {},
            onCompleted: (_) {},
            onResend: () {},
            resendInFlight: false,
          ),
        ),
      );
      expect(find.textContaining('00:0'), findsOneWidget);

      final newExpiry = DateTime.now().add(const Duration(minutes: 5));
      await tester.pumpWidget(
        _wrap(
          OtpInputSection(
            expiresAt: newExpiry,
            onChanged: (_) {},
            onCompleted: (_) {},
            onResend: () {},
            resendInFlight: false,
          ),
        ),
      );
      expect(find.textContaining('04:5'), findsOneWidget);
    });
  });
}
