import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:handygo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:handygo_app/features/auth/presentation/pages/ustaad_register_step1_page.dart';
import 'package:handygo_app/features/auth/presentation/pages/ustaad_register_step3_page.dart';
import 'package:handygo_app/features/worker/domain/entities/category_entity.dart';
import 'package:handygo_app/features/worker/presentation/providers/worker_providers.dart';

import '../../../support/l10n_test_app.dart';

/// The registration CTA and the keyboard.
///
/// Two bugs lived in `UstaadStepScaffold`, and neither was reachable from an
/// ordinary widget test because widget tests run with `viewInsets.bottom == 0`:
///
///  1. The CTA was deleted from the tree whenever the keyboard was up
///     (`if (keyboard == 0)`), and because it sits OUTSIDE the scroll view
///     there was no way to scroll to it either. Every field on Step 1 needs
///     the keyboard, so "Aage" was invisible for the whole time the form was
///     being filled in — read by users as "there is no Next button".
///  2. `resizeToAvoidBottomInset: false` kept the scroll VIEWPORT at full
///     screen height, so Flutter's scroll-into-view measured against a
///     viewport that extends behind the keyboard and left the lower fields
///     physically under the IME.
///
/// Every test here therefore raises a real bottom inset first.
///
/// NOTE: this simulates the INSET, not the Android IME. Focus handoff, the
/// soft keyboard actually opening, and platform autofill still need a device.

/// Logical-pixel height of a typical Android soft keyboard.
const _keyboardHeight = 300.0;

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<Either<Failure, DateTime>> requestOtp({
    required String phone,
    required OtpPurpose purpose,
  }) async => Right(DateTime.now().add(const Duration(minutes: 5)));

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Widget _app({required String at}) {
  final router = GoRouter(
    initialLocation: at,
    routes: [
      GoRoute(
        path: UstaadRegisterStep1Page.route,
        builder: (_, _) => const UstaadRegisterStep1Page(),
      ),
      GoRoute(
        path: '/auth/worker/register/verify',
        builder: (_, _) => const Scaffold(body: Text('STEP_2')),
      ),
      GoRoute(
        path: UstaadRegisterStep3Page.route,
        builder: (_, _) => const UstaadRegisterStep3Page(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      categoriesProvider.overrideWith(
        (ref) async => const [CategoryEntity(id: 'c1', name: 'Electrician')],
      ),
    ],
    child: localizedRouterApp(router, locale: AppLocale.romanUrdu),
  );
}

/// Sizes the test view and (optionally) raises the keyboard inset, the way the
/// platform does when the IME opens.
void _sizeView(
  WidgetTester tester, {
  required double width,
  required double height,
  double keyboard = 0,
}) {
  const dpr = 1.0;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(width * dpr, height * dpr);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * dpr);
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// The bottom edge of the visible viewport — everything below this is covered
/// by the keyboard and might as well not be on screen.
double _visibleBottom(WidgetTester tester, double keyboard) =>
    tester.view.physicalSize.height / tester.view.devicePixelRatio - keyboard;

void main() {
  // Every size the brief asked for: a small budget Android phone, a common
  // mid-range one, and a large modern one.
  const layouts = <(String, double, double)>[
    ('320x640 small', 320, 640),
    ('360x800 common', 360, 800),
    ('390x844 large', 390, 844),
  ];

  group('Step 1 — the CTA survives the keyboard', () {
    for (final (label, width, height) in layouts) {
      testWidgets('$label: Aage stays in the tree and above the keyboard', (
        tester,
      ) async {
        _sizeView(
          tester,
          width: width,
          height: height,
          keyboard: _keyboardHeight,
        );
        await tester.pumpWidget(_app(at: UstaadRegisterStep1Page.route));
        await _settle(tester);

        expect(
          find.text('Aage'),
          findsOneWidget,
          reason: 'the CTA used to be removed from the tree by `if '
              '(keyboard == 0)` — with nothing to scroll to, since it lives '
              'outside the scroll view',
        );

        final cta = tester.getRect(find.text('Aage'));
        expect(
          cta.bottom,
          lessThanOrEqualTo(_visibleBottom(tester, _keyboardHeight) + 0.5),
          reason: 'the CTA must sit above the keyboard, not behind it',
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'no overflow at this size with the keyboard up',
        );
      });
    }

    testWidgets('the CTA is present with the keyboard down too', (
      tester,
    ) async {
      _sizeView(tester, width: 360, height: 800);
      await tester.pumpWidget(_app(at: UstaadRegisterStep1Page.route));
      await _settle(tester);

      expect(find.text('Aage'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the CTA never covers a field', (tester) async {
      _sizeView(tester, width: 360, height: 800, keyboard: _keyboardHeight);
      await tester.pumpWidget(_app(at: UstaadRegisterStep1Page.route));
      await _settle(tester);

      final cta = tester.getRect(find.text('Aage'));
      for (var i = 0; i < tester.widgetList(find.byType(EditableText)).length; i++) {
        final field = tester.getRect(find.byType(EditableText).at(i));
        expect(
          field.overlaps(cta),
          isFalse,
          reason: 'field $i is drawn underneath the CTA bar',
        );
      }
    });
  });

  group('Step 1 — the focused field is reachable above the keyboard', () {
    testWidgets('the keyboard SHORTENS the scroll viewport rather than being '
        'padded around', (tester) async {
      // This is the mechanism behind the "tapping back into a field does
      // nothing" report, and the one thing that separates the fix from the
      // bug. With `resizeToAvoidBottomInset: false` the viewport stayed the
      // full height of the screen and the inset was faked as bottom padding,
      // so `RenderEditable.showOnScreen` measured a field sitting under the
      // IME as already visible and never scrolled it up. Shortening the
      // viewport is what makes the framework's own scroll-into-view honest.
      _sizeView(tester, width: 360, height: 800);
      await tester.pumpWidget(_app(at: UstaadRegisterStep1Page.route));
      await _settle(tester);

      final open = tester.getRect(find.byType(SingleChildScrollView));

      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboardHeight);
      await _settle(tester);

      final shut = tester.getRect(find.byType(SingleChildScrollView));
      expect(
        open.height - shut.height,
        closeTo(_keyboardHeight, 1),
        reason: 'the viewport must lose exactly the keyboard it gained',
      );
      expect(
        shut.bottom,
        lessThanOrEqualTo(_visibleBottom(tester, _keyboardHeight) + 0.5),
        reason: 'and none of it may extend behind the keyboard',
      );
    });

    testWidgets('the LAST field can be scrolled fully clear of the IME', (
      tester,
    ) async {
      // The smallest layout is the hardest: the password field is well below
      // the fold once 300px of keyboard is taken out.
      _sizeView(tester, width: 320, height: 640, keyboard: _keyboardHeight);
      await tester.pumpWidget(_app(at: UstaadRegisterStep1Page.route));
      await _settle(tester);

      final password = find.byType(EditableText).at(3);
      await tester.ensureVisible(password);
      await _settle(tester);

      final rect = tester.getRect(password);
      expect(
        rect.bottom,
        lessThanOrEqualTo(_visibleBottom(tester, _keyboardHeight) + 0.5),
        reason:
            'with `resizeToAvoidBottomInset: false` the viewport stayed full '
            'height, so this field sat behind the keyboard and the framework '
            'believed it was visible',
      );
      expect(rect.top, greaterThanOrEqualTo(-0.5));
      expect(tester.takeException(), isNull);
    });
  });

  group('Step 3 — the same scaffold, the same guarantees', () {
    for (final (label, width, height) in layouts) {
      testWidgets('$label: Aage stays reachable while the address is typed', (
        tester,
      ) async {
        _sizeView(
          tester,
          width: width,
          height: height,
          keyboard: _keyboardHeight,
        );
        await tester.pumpWidget(_app(at: UstaadRegisterStep3Page.route));
        await _settle(tester);

        expect(find.text('Aage'), findsOneWidget);
        final cta = tester.getRect(find.text('Aage'));
        expect(
          cta.bottom,
          lessThanOrEqualTo(_visibleBottom(tester, _keyboardHeight) + 0.5),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the last address field scrolls clear of the keyboard', (
      tester,
    ) async {
      _sizeView(tester, width: 320, height: 640, keyboard: _keyboardHeight);
      await tester.pumpWidget(_app(at: UstaadRegisterStep3Page.route));
      await _settle(tester);

      final landmark = find.byType(EditableText).at(5);
      await tester.ensureVisible(landmark);
      await _settle(tester);

      expect(
        tester.getRect(landmark).bottom,
        lessThanOrEqualTo(_visibleBottom(tester, _keyboardHeight) + 0.5),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
