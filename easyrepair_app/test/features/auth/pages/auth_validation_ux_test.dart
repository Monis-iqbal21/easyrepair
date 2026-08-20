import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:handygo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:handygo_app/features/auth/presentation/pages/client_login_page.dart';
import 'package:handygo_app/features/auth/presentation/pages/client_register_page.dart';
import 'package:handygo_app/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:handygo_app/features/auth/presentation/pages/ustaad_login_page.dart';
import 'package:handygo_app/features/auth/presentation/pages/ustaad_register_step1_page.dart';

import '../../../support/l10n_test_app.dart';

/// The no-error-on-first-tap rule, checked on the real screens.
///
/// `field_validation_ux_test.dart` pins the behaviour in the shared widget;
/// this file proves each page actually gets it, since the pages used to force
/// it off with `AutovalidateMode.onUserInteraction` on their `Form`. The
/// fields named here are the ones the report singled out: Password, Phone,
/// Full name and CNIC.

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<Either<Failure, DateTime>> requestOtp({
    required String phone,
    required OtpPurpose purpose,
  }) async =>
      Right(DateTime.now().add(const Duration(minutes: 5)));

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Widget _app(Widget page) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (_, _) => page)],
  );
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(_FakeAuthRepository())],
    child: localizedRouterApp(router, locale: AppLocale.romanUrdu),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Every error message rendered anywhere on the page right now.
///
/// Read off the decorations rather than by searching for particular strings,
/// so the assertion holds whatever the copy says and in whichever language.
List<String> _visibleErrors(WidgetTester tester) => tester
    .widgetList<TextField>(find.byType(TextField))
    .map((f) => f.decoration?.errorText)
    .whereType<String>()
    .toList();

Future<void> _tapField(WidgetTester tester, int index) async {
  final field = find.byType(EditableText).at(index);
  await tester.ensureVisible(field);
  await _settle(tester);
  await tester.tap(field);
  await _settle(tester);
}

void main() {
  group('tapping into an empty field never scolds the user', () {
    testWidgets('Ustaad login — Phone, then Password', (tester) async {
      await tester.pumpWidget(_app(const UstaadLoginPage()));
      await _settle(tester);

      await _tapField(tester, 0); // phone
      expect(_visibleErrors(tester), isEmpty);

      await _tapField(tester, 1); // password — the field in the report
      expect(_visibleErrors(tester), isEmpty,
          reason: 'moving from an untouched phone to the password must not '
              'flag the phone either');
    });

    testWidgets('Client login — Phone, then Password', (tester) async {
      await tester.pumpWidget(_app(const ClientLoginPage()));
      await _settle(tester);

      await _tapField(tester, 0);
      expect(_visibleErrors(tester), isEmpty);

      await _tapField(tester, 1);
      expect(_visibleErrors(tester), isEmpty);
    });

    testWidgets('Client register — Full name, Phone, Password, Confirm',
        (tester) async {
      await tester.pumpWidget(_app(const ClientRegisterPage()));
      await _settle(tester);

      for (var i = 0; i < 4; i++) {
        await _tapField(tester, i);
        expect(_visibleErrors(tester), isEmpty,
            reason: 'walking down the form must stay silent');
      }
    });

    testWidgets('Ustaad register step 1 — Full name, Phone, CNIC, Password',
        (tester) async {
      await tester.pumpWidget(_app(const UstaadRegisterStep1Page()));
      await _settle(tester);

      for (var i = 0; i < 4; i++) {
        await _tapField(tester, i);
        expect(_visibleErrors(tester), isEmpty);
      }
    });

    testWidgets('Forgot password — Phone', (tester) async {
      await tester.pumpWidget(_app(const ForgotPasswordPage()));
      await _settle(tester);

      await _tapField(tester, 0);
      expect(_visibleErrors(tester), isEmpty);
    });
  });

  group('but a field the user actually filled in badly does speak up', () {
    testWidgets('Ustaad register step 1 — a short password, then moving on',
        (tester) async {
      await tester.pumpWidget(_app(const UstaadRegisterStep1Page()));
      await _settle(tester);

      await _tapField(tester, 3); // password
      await tester.enterText(find.byType(EditableText).at(3), 'abc');
      await _settle(tester);
      expect(_visibleErrors(tester), isEmpty,
          reason: 'still typing — not finished yet');

      await _tapField(tester, 0); // blur onto the name field
      expect(_visibleErrors(tester), hasLength(1),
          reason: 'exactly the password, and nothing the user has not filled '
              'in yet');
    });

    testWidgets('Client register — a bad phone number, then moving on',
        (tester) async {
      await tester.pumpWidget(_app(const ClientRegisterPage()));
      await _settle(tester);

      await _tapField(tester, 1);
      await tester.enterText(find.byType(EditableText).at(1), '12345');
      await _settle(tester);
      await _tapField(tester, 2);

      expect(_visibleErrors(tester), hasLength(1));
    });

    testWidgets('and correcting it clears the message without another blur',
        (tester) async {
      await tester.pumpWidget(_app(const ClientRegisterPage()));
      await _settle(tester);

      await _tapField(tester, 1);
      await tester.enterText(find.byType(EditableText).at(1), '12345');
      await _settle(tester);
      await _tapField(tester, 2);
      expect(_visibleErrors(tester), hasLength(1));

      await _tapField(tester, 1);
      await tester.enterText(find.byType(EditableText).at(1), '3378372427');
      await _settle(tester);

      expect(_visibleErrors(tester), isEmpty);
    });
  });

  group('a submit reveals everything at once', () {
    // Reached through the keyboard's "done" action, which runs the page's
    // submit handler directly — the CTA is deliberately disabled while the
    // form is incomplete, and CTA enablement is a separate concern from error
    // visibility. This asserts the second one on a path a real user has.
    testWidgets('Ustaad login — submitting with an empty password flags it '
        'without ever leaving the field', (tester) async {
      await tester.pumpWidget(_app(const UstaadLoginPage()));
      await _settle(tester);

      await _tapField(tester, 0);
      await tester.enterText(find.byType(EditableText).at(0), '3378372427');
      await _settle(tester);
      await _tapField(tester, 1); // into the password, and stay there
      expect(_visibleErrors(tester), isEmpty);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _settle(tester);

      expect(_visibleErrors(tester), hasLength(1),
          reason: 'the empty password, revealed by the submit rather than by '
              'a blur');
    });

    testWidgets('Ustaad register step 1 — submitting an empty form flags every '
        'field at once', (tester) async {
      await tester.pumpWidget(_app(const UstaadRegisterStep1Page()));
      await _settle(tester);
      expect(_visibleErrors(tester), isEmpty);

      await _tapField(tester, 3); // password, last field
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _settle(tester);

      expect(_visibleErrors(tester), hasLength(4),
          reason: 'name, phone, CNIC and password — including the three the '
              'user never touched');
    });

    testWidgets('Client login — submitting with an empty password flags it',
        (tester) async {
      await tester.pumpWidget(_app(const ClientLoginPage()));
      await _settle(tester);

      await _tapField(tester, 0);
      await tester.enterText(find.byType(EditableText).at(0), '3378372427');
      await _settle(tester);
      await _tapField(tester, 1);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _settle(tester);

      expect(_visibleErrors(tester), hasLength(1));
    });
  });
}
