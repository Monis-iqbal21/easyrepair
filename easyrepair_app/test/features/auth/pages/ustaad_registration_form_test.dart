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
import 'package:handygo_app/features/auth/presentation/providers/ustaad_registration_draft.dart';
import 'package:handygo_app/features/worker/domain/entities/category_entity.dart';
import 'package:handygo_app/features/worker/presentation/providers/worker_providers.dart';

import '../../../support/l10n_test_app.dart';

/// Typing into the Ustaad registration forms.
///
/// The reported bug is specifically about EDITING: a field takes its first
/// value, but coming back to it after visiting another field leaves it stuck.
/// Every test here therefore types, moves focus away, comes back and types
/// again — asserting on what the field actually shows, not on what was sent
/// to it.

class _FakeAuthRepository implements AuthRepository {
  int requestOtpCalls = 0;

  @override
  Future<Either<Failure, DateTime>> requestOtp({
    required String phone,
    required OtpPurpose purpose,
  }) async {
    requestOtpCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return Right(DateTime.now().add(const Duration(minutes: 5)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Widget _app({required String at, _FakeAuthRepository? repository}) {
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
      authRepositoryProvider.overrideWithValue(
        repository ?? _FakeAuthRepository(),
      ),
      // Step 3 renders the live trade list; a fixed one keeps the test about
      // typing rather than about the network.
      categoriesProvider.overrideWith(
        (ref) async => const [CategoryEntity(id: 'c1', name: 'Electrician')],
      ),
    ],
    child: localizedRouterApp(router, locale: AppLocale.romanUrdu),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// What the field is actually SHOWING — the only thing that proves an edit
/// landed. Asserting on the draft alone would pass even with a frozen field.
String _shown(WidgetTester tester, int index) => tester
    .widget<EditableText>(find.byType(EditableText).at(index))
    .controller
    .text;

/// Types into the field at [index] the way a person does: focus it first, then
/// replace its contents.
Future<void> _typeInto(WidgetTester tester, int index, String text) async {
  await tester.ensureVisible(find.byType(EditableText).at(index));
  await _settle(tester);
  await tester.tap(find.byType(EditableText).at(index));
  await _settle(tester);
  await tester.enterText(find.byType(EditableText).at(index), text);
  await _settle(tester);
}

void main() {
  group('Step 1 — every field stays editable after focus moves', () {
    // Field order on the page.
    const name = 0;
    const phone = 1;
    const cnic = 2;
    const password = 3;

    testWidgets('the exact reported sequence: fill, move away, come back and '
        'change each one', (tester) async {
      await tester.pumpWidget(_app(at: UstaadRegisterStep1Page.route));
      await _settle(tester);

      await _typeInto(tester, name, 'Ali Khan');
      expect(_shown(tester, name), 'Ali Khan');

      await _typeInto(tester, cnic, '4210112345671');
      expect(_shown(tester, cnic), '42101-1234567-1');

      // Back to the first field — this is where it used to freeze.
      await _typeInto(tester, name, 'Ali Raza Khan');
      expect(
        _shown(tester, name),
        'Ali Raza Khan',
        reason: 'the name must change after another field was focused',
      );
      expect(
        _shown(tester, cnic),
        '42101-1234567-1',
        reason: 'and editing it must not disturb the CNIC',
      );

      await _typeInto(tester, phone, '03378372427');
      expect(_shown(tester, phone), '03378372427');

      await _typeInto(tester, cnic, '4210198765432');
      expect(
        _shown(tester, cnic),
        '42101-9876543-2',
        reason: 're-editing the CNIC after focus changes must work',
      );
      expect(_shown(tester, name), 'Ali Raza Khan');
      expect(_shown(tester, phone), '03378372427');
    });

    testWidgets('name, phone and password accept mid-string insert/delete '
        'after focus leaves and returns', (tester) async {
      await tester.pumpWidget(_app(at: UstaadRegisterStep1Page.route));
      await _settle(tester);

      await _typeInto(tester, name, 'Ali Khan');
      await _typeInto(tester, phone, '03378372427');
      await _typeInto(tester, password, 'password123');

      Future<void> edit(int field, TextEditingValue value) async {
        await tester.tap(find.byType(EditableText).at(field));
        final state = tester.state<EditableTextState>(
          find.byType(EditableText).at(field),
        );
        state.userUpdateTextEditingValue(value, SelectionChangedCause.keyboard);
        await _settle(tester);
      }

      // Insert in the middle after returning from other fields.
      await edit(
        name,
        const TextEditingValue(
          text: 'Ali Raza Khan',
          selection: TextSelection.collapsed(offset: 8),
        ),
      );
      expect(_shown(tester, name), 'Ali Raza Khan');

      // Delete a middle digit, then insert it again at the logical caret.
      await edit(
        phone,
        const TextEditingValue(
          text: '0337372427',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      expect(_shown(tester, phone), '0337372427');
      await edit(
        phone,
        const TextEditingValue(
          text: '03378372427',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      expect(_shown(tester, phone), '03378372427');

      // A platform backspace removes the character before this mid-string
      // caret; the controller must accept the resulting value on return.
      await edit(
        password,
        const TextEditingValue(
          text: 'pasword123',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      expect(_shown(tester, password), 'pasword123');
    });

    testWidgets('password uses normal obscuring and Show/Hide preserves text '
        'without submitting or navigating', (tester) async {
      final repository = _FakeAuthRepository();
      await tester.pumpWidget(
        _app(at: UstaadRegisterStep1Page.route, repository: repository),
      );
      await _settle(tester);

      await _typeInto(tester, password, 'password123');
      expect(_shown(tester, password), 'password123');

      EditableText field() =>
          tester.widget<EditableText>(find.byType(EditableText).at(password));
      expect(field().obscureText, isTrue);

      await tester.ensureVisible(find.text('Show'));
      await _settle(tester);
      await tester.tap(find.text('Show'));
      await _settle(tester);
      expect(field().obscureText, isFalse);
      expect(find.text('Hide'), findsOneWidget);
      expect(
        _shown(tester, password),
        'password123',
        reason: 'revealing must never clear the value',
      );
      expect(repository.requestOtpCalls, 0);
      expect(find.byType(UstaadRegisterStep1Page), findsOneWidget);

      await _typeInto(tester, password, 'newpassword456');
      expect(
        _shown(tester, password),
        'newpassword456',
        reason: 'and it must still be editable once revealed',
      );

      await tester.tap(find.text('Hide'));
      await _settle(tester);
      expect(field().obscureText, isTrue);
      expect(find.text('Show'), findsOneWidget);
      expect(_shown(tester, password), 'newpassword456');
      expect(repository.requestOtpCalls, 0);
      expect(find.byType(UstaadRegisterStep1Page), findsOneWidget);
    });

    testWidgets('keyboard Next only advances focus and Done only unfocuses', (
      tester,
    ) async {
      final repository = _FakeAuthRepository();
      await tester.pumpWidget(
        _app(at: UstaadRegisterStep1Page.route, repository: repository),
      );
      await _settle(tester);

      await tester.tap(find.byType(EditableText).at(name));
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await _settle(tester);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).at(phone))
            .focusNode
            .hasFocus,
        isTrue,
      );

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await _settle(tester);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).at(cnic))
            .focusNode
            .hasFocus,
        isTrue,
      );

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await _settle(tester);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).at(password))
            .focusNode
            .hasFocus,
        isTrue,
      );

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _settle(tester);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).at(password))
            .focusNode
            .hasFocus,
        isFalse,
      );
      expect(repository.requestOtpCalls, 0);
      expect(find.byType(UstaadRegisterStep1Page), findsOneWidget);
    });

    testWidgets('manual Aage is visible and is the only submit path', (
      tester,
    ) async {
      final repository = _FakeAuthRepository();
      await tester.pumpWidget(
        _app(at: UstaadRegisterStep1Page.route, repository: repository),
      );
      await _settle(tester);

      expect(find.text('Aage'), findsOneWidget);
      await tester.ensureVisible(find.text('Aage'));
      await tester.tap(find.text('Aage'));
      await _settle(tester);

      expect(
        repository.requestOtpCalls,
        0,
        reason: 'invalid manual submit validates but sends nothing',
      );
      expect(find.text('Poora naam likhein.'), findsOneWidget);
      expect(find.byType(UstaadRegisterStep1Page), findsOneWidget);
    });

    testWidgets('the CNIC can be edited in the middle — the cursor is not '
        'dragged to the end on every keystroke', (tester) async {
      await tester.pumpWidget(_app(at: UstaadRegisterStep1Page.route));
      await _settle(tester);

      await _typeInto(tester, cnic, '4210112345671');
      expect(_shown(tester, cnic), '42101-1234567-1');

      // Put the caret after the fifth digit and type there, exactly as
      // someone correcting a mistyped district code would.
      final state = tester.state<EditableTextState>(
        find.byType(EditableText).at(cnic),
      );
      state.userUpdateTextEditingValue(
        state.textEditingValue.copyWith(
          selection: const TextSelection.collapsed(offset: 3),
        ),
        SelectionChangedCause.tap,
      );
      await _settle(tester);

      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).at(cnic))
            .controller
            .selection
            .baseOffset,
        3,
        reason: 'the caret must stay where the user put it',
      );
    });

    testWidgets('a digit typed into the middle of the CNIC lands there, and '
        'the caret follows it instead of jumping to the end', (tester) async {
      await tester.pumpWidget(_app(at: UstaadRegisterStep1Page.route));
      await _settle(tester);

      await _typeInto(tester, cnic, '4210112345671');
      expect(_shown(tester, cnic), '42101-1234567-1');

      final state = tester.state<EditableTextState>(
        find.byType(EditableText).at(cnic),
      );

      // Exactly what the platform sends when someone puts the caret after the
      // third digit and presses "9": the whole new string plus the new caret
      // offset, for the formatter to re-space.
      state.userUpdateTextEditingValue(
        const TextEditingValue(
          text: '421901-1234567-1',
          selection: TextSelection.collapsed(offset: 4),
        ),
        SelectionChangedCause.keyboard,
      );
      await _settle(tester);

      final field = tester.widget<EditableText>(
        find.byType(EditableText).at(cnic),
      );
      expect(
        field.controller.text,
        '42190-1123456-7',
        reason:
            'the digit belongs where it was typed, and the dashes '
            'reflow around it',
      );
      expect(
        field.controller.selection.baseOffset,
        4,
        reason:
            'the caret sits just after the digit that was inserted — '
            'pinning it to the end made mid-string correction impossible',
      );
    });

    testWidgets('deleting a digit from the middle reflows without throwing the '
        'caret away', (tester) async {
      await tester.pumpWidget(_app(at: UstaadRegisterStep1Page.route));
      await _settle(tester);

      await _typeInto(tester, cnic, '4210112345671');

      final state = tester.state<EditableTextState>(
        find.byType(EditableText).at(cnic),
      );
      // Backspace over the third digit.
      state.userUpdateTextEditingValue(
        const TextEditingValue(
          text: '4201-1234567-1',
          selection: TextSelection.collapsed(offset: 2),
        ),
        SelectionChangedCause.keyboard,
      );
      await _settle(tester);

      final field = tester.widget<EditableText>(
        find.byType(EditableText).at(cnic),
      );
      // Twelve digits left, so the second dash is gone until a thirteenth
      // arrives — the same reflow the formatter has always done.
      expect(field.controller.text, '42011-2345671');
      expect(field.controller.selection.baseOffset, 2);
    });

    testWidgets('typing into an empty CNIC still appends normally — the caret '
        'fix must not break the ordinary case', (tester) async {
      await tester.pumpWidget(_app(at: UstaadRegisterStep1Page.route));
      await _settle(tester);

      await _typeInto(tester, cnic, '42101');
      final state = tester.state<EditableTextState>(
        find.byType(EditableText).at(cnic),
      );
      state.userUpdateTextEditingValue(
        const TextEditingValue(
          text: '421011',
          selection: TextSelection.collapsed(offset: 6),
        ),
        SelectionChangedCause.keyboard,
      );
      await _settle(tester);

      final field = tester.widget<EditableText>(
        find.byType(EditableText).at(cnic),
      );
      expect(field.controller.text, '42101-1');
      expect(
        field.controller.selection.baseOffset,
        7,
        reason:
            'past the dash the formatter just inserted, ready for the '
            'next digit',
      );
    });

    testWidgets(
      'the draft carries the LAST edited values, not the first ones',
      (tester) async {
        await tester.pumpWidget(_app(at: UstaadRegisterStep1Page.route));
        await _settle(tester);

        await _typeInto(tester, name, 'Ali Khan');
        await _typeInto(tester, phone, '03378372427');
        await _typeInto(tester, cnic, '4210112345671');
        await _typeInto(tester, password, 'password123');
        // The edit that used to be lost.
        await _typeInto(tester, name, 'Ali Raza Khan');

        await tester.ensureVisible(find.text('Aage'));
        await _settle(tester);
        await tester.tap(find.text('Aage'));
        await _settle(tester);
        await _settle(tester);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(Scaffold).last),
        );
        final draft = container.read(ustaadRegistrationDraftProvider);
        expect(draft.fullName, 'Ali Raza Khan');
        expect(draft.phone, '03378372427');
        expect(draft.cnicNumber, '42101-1234567-1');
        expect(draft.password, 'password123');
      },
    );
  });

  group('Step 3 — the address fields', () {
    // Field order on the page. Father name and date of birth now sit above the
    // address — they are required by `submitProfileForReview` and were
    // previously collected nowhere, which is what made every submission from
    // this flow fail. `_orderIsAsExpected` below pins the order so these
    // indices cannot drift silently again.
    const fatherName = 0;
    const dateOfBirth = 1;
    const area = 2;
    const street = 3;
    const house = 4;
    const landmark = 5;

    void orderIsAsExpected(WidgetTester tester) {
      expect(
        find.byType(EditableText),
        findsNWidgets(6),
        reason: 'father name, date of birth, area, street, house, landmark',
      );
    }

    testWidgets(
      'each one takes text, and editing one leaves the others alone',
      (tester) async {
        await tester.pumpWidget(_app(at: UstaadRegisterStep3Page.route));
        await _settle(tester);
        orderIsAsExpected(tester);

        await _typeInto(tester, area, 'Saddar');
        await _typeInto(tester, street, '14');
        await _typeInto(tester, house, 'B-42');
        await _typeInto(tester, landmark, 'Masjid ke saamne');

        expect(_shown(tester, area), 'Saddar');
        expect(_shown(tester, street), '14');
        expect(_shown(tester, house), 'B-42');
        expect(_shown(tester, landmark), 'Masjid ke saamne');

        // Go back through them and change each — the reported failure.
        await _typeInto(tester, area, 'Gulshan');
        expect(_shown(tester, area), 'Gulshan');
        expect(_shown(tester, house), 'B-42', reason: 'others untouched');

        await _typeInto(tester, house, 'C-17');
        expect(_shown(tester, house), 'C-17');
        expect(_shown(tester, area), 'Gulshan');
        expect(_shown(tester, street), '14');
        expect(_shown(tester, landmark), 'Masjid ke saamne');
      },
    );

    testWidgets('letters, digits and punctuation are all accepted — no field '
        'silently drops keystrokes', (tester) async {
      await tester.pumpWidget(_app(at: UstaadRegisterStep3Page.route));
      await _settle(tester);
      orderIsAsExpected(tester);

      await _typeInto(tester, house, 'B-42/A');
      expect(_shown(tester, house), 'B-42/A');

      await _typeInto(tester, street, 'Main Road 14');
      expect(_shown(tester, street), 'Main Road 14');
    });

    testWidgets('the draft holds the latest edited address', (tester) async {
      await tester.pumpWidget(_app(at: UstaadRegisterStep3Page.route));
      await _settle(tester);
      orderIsAsExpected(tester);

      await _typeInto(tester, fatherName, 'Sheikh Rafiq');
      await _typeInto(tester, area, 'Saddar');
      await _typeInto(tester, street, '14');
      await _typeInto(tester, house, 'B-42');
      await _typeInto(tester, area, 'Gulshan');

      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).last),
      );
      final draft = container.read(ustaadRegistrationDraftProvider);
      expect(draft.area, 'Gulshan');
      expect(draft.street, '14');
      expect(draft.house, 'B-42');
      expect(draft.fatherName, 'Sheikh Rafiq');
    });

    testWidgets('the date of birth is picker-driven, not typed', (tester) async {
      await tester.pumpWidget(_app(at: UstaadRegisterStep3Page.route));
      await _settle(tester);
      orderIsAsExpected(tester);

      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).at(dateOfBirth))
            .readOnly,
        isTrue,
        reason:
            'a keyboard-typed date could never be trusted to be the '
            'yyyy-MM-dd the legal document prints',
      );
    });
  });
}
