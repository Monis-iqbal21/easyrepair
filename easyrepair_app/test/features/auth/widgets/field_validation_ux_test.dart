import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/theme/app_semantic_colors.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/auth/presentation/widgets/client_auth_widgets.dart';

/// When a validation error is allowed on screen, and what it is allowed to
/// look like.
///
/// The reported behaviour was that tapping into an empty Password or Phone
/// field printed its error straight away, before a single character had been
/// typed. These tests pin the replacement rules field-by-field, because the
/// rules live in the shared widget and every auth screen inherits them:
///
///   * silent while pristine, however invalid the value is;
///   * error after the user has entered something and moved away;
///   * error on every invalid field the moment a submit is attempted;
///   * live correction once an error is already showing;
///   * and never, in any of those states, a red outline.

const _tooShort = 'at least 8 characters';

String? _minEight(String? v) =>
    (v == null || v.length < 8) ? _tooShort : null;

/// Two fields, so focus has somewhere to go — blur is what promotes a field
/// out of pristine, and a single-field page can never demonstrate it.
class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final formKey = GlobalKey<FormState>();
  final first = TextEditingController();
  final second = TextEditingController();
  bool submitted = false;

  @override
  void dispose() {
    first.dispose();
    second.dispose();
    super.dispose();
  }

  void submit() {
    setState(() => submitted = true);
    formKey.currentState!.validate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: formKey,
        child: Column(
          children: [
            ClientTextField(
              controller: first,
              hint: 'first',
              forceError: submitted,
              validator: _minEight,
            ),
            ClientTextField(
              controller: second,
              hint: 'second',
              forceError: submitted,
              validator: (_) => null,
            ),
            ElevatedButton(onPressed: submit, child: const Text('Submit')),
          ],
        ),
      ),
    );
  }
}

Future<void> _pump(WidgetTester tester, {bool dark = false}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      home: const _Harness(),
    ),
  );
  await tester.pump();
}

Finder get _firstField => find.byType(EditableText).first;
Finder get _secondField => find.byType(EditableText).last;

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _type(WidgetTester tester, Finder f, String text) async {
  await tester.enterText(f, text);
  await tester.pump(const Duration(milliseconds: 100));
}

InputDecoration _decoration(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first).decoration!;

AppSemanticColors _colors(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold)))
        .extension<AppSemanticColors>()!;

/// The colour actually painted around the field right now, which is the only
/// thing a user sees — reading `decoration.errorBorder` alone would not prove
/// which border Flutter selected.
Color _paintedBorderColor(WidgetTester tester) {
  final decorator = tester.widget<InputDecorator>(
    find.byType(InputDecorator).first,
  );
  final d = decorator.decoration;
  final isFocused = decorator.isFocused;
  final hasError = d.errorText != null;
  final border = hasError
      ? (isFocused ? d.focusedErrorBorder : d.errorBorder)
      : (isFocused ? d.focusedBorder : d.enabledBorder);
  return (border! as OutlineInputBorder).borderSide.color;
}

void main() {
  group('a field stays silent until the user has actually engaged with it', () {
    testWidgets('tapping into an empty field shows nothing — the reported bug',
        (tester) async {
      await _pump(tester);
      await _tap(tester, _firstField);

      expect(find.text(_tooShort), findsNothing,
          reason: 'placing the caret is not a reason to be told off');
    });

    testWidgets('tapping in and straight back out shows nothing either',
        (tester) async {
      await _pump(tester);
      await _tap(tester, _firstField);
      await _tap(tester, _secondField);

      expect(find.text(_tooShort), findsNothing,
          reason: 'passing through a field is not entering invalid data');
    });

    testWidgets('typing something invalid shows nothing while still in the '
        'field — the user has not finished', (tester) async {
      await _pump(tester);
      await _tap(tester, _firstField);
      await _type(tester, _firstField, 'abc');

      expect(find.text(_tooShort), findsNothing);
    });

    testWidgets('a field never even visited stays silent', (tester) async {
      await _pump(tester);
      await _tap(tester, _secondField);

      expect(find.text(_tooShort), findsNothing);
    });
  });

  group('the error appears when it should', () {
    testWidgets('invalid data, then moving away', (tester) async {
      await _pump(tester);
      await _tap(tester, _firstField);
      await _type(tester, _firstField, 'abc');
      await _tap(tester, _secondField); // blur

      expect(find.text(_tooShort), findsOneWidget);
    });

    testWidgets('a submit reveals every invalid field at once, untouched ones '
        'included', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Submit'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(_tooShort), findsOneWidget);
    });

    testWidgets('correcting a visible error clears it live, without a second '
        'submit or another blur', (tester) async {
      await _pump(tester);
      await _tap(tester, _firstField);
      await _type(tester, _firstField, 'abc');
      await _tap(tester, _secondField);
      expect(find.text(_tooShort), findsOneWidget);

      // Back into the field and fix it — the message must go on its own.
      await _tap(tester, _firstField);
      await _type(tester, _firstField, 'abcdefghij');

      expect(find.text(_tooShort), findsNothing);
    });

    testWidgets('and a valid field that goes invalid again says so live',
        (tester) async {
      await _pump(tester);
      await _tap(tester, _firstField);
      await _type(tester, _firstField, 'abcdefghij');
      await _tap(tester, _secondField);
      expect(find.text(_tooShort), findsNothing);

      await _tap(tester, _firstField);
      await _type(tester, _firstField, 'abc');

      expect(find.text(_tooShort), findsOneWidget);
    });
  });

  group('validation still gates submission', () {
    testWidgets('Form.validate() reports false for a pristine invalid field — '
        'silence is about display, never about letting a bad request out',
        (tester) async {
      await _pump(tester);
      final state = tester.state<_HarnessState>(find.byType(_Harness));

      expect(state.formKey.currentState!.validate(), isFalse);
    });

    testWidgets('and true once every field is valid', (tester) async {
      await _pump(tester);
      await _type(tester, _firstField, 'abcdefghij');
      final state = tester.state<_HarnessState>(find.byType(_Harness));

      expect(state.formKey.currentState!.validate(), isTrue);
    });
  });

  group('an invalid field is never outlined in red', () {
    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';

      testWidgets('$mode — the border stays the neutral control colour while '
          'the error is showing and the field is not focused', (tester) async {
        await _pump(tester, dark: dark);
        final colors = _colors(tester);

        await _tap(tester, _firstField);
        await _type(tester, _firstField, 'abc');
        await _tap(tester, _secondField);
        expect(find.text(_tooShort), findsOneWidget);

        expect(_paintedBorderColor(tester), colors.controlBorder);
        expect(_paintedBorderColor(tester), isNot(colors.error));
      });

      testWidgets('$mode — and the primary colour while it IS focused, exactly '
          'as a valid field would be', (tester) async {
        await _pump(tester, dark: dark);
        final colors = _colors(tester);

        await _tap(tester, _firstField);
        await _type(tester, _firstField, 'abc');
        await _tap(tester, _secondField);
        await _tap(tester, _firstField); // back in, error still showing
        expect(find.text(_tooShort), findsOneWidget);

        expect(_paintedBorderColor(tester), colors.primary);
        expect(_paintedBorderColor(tester), isNot(colors.error));
      });

      testWidgets('$mode — no error border in the decoration is red in the '
          'first place', (tester) async {
        await _pump(tester, dark: dark);
        final colors = _colors(tester);
        final d = _decoration(tester);

        for (final border in [d.errorBorder, d.focusedErrorBorder]) {
          expect((border! as OutlineInputBorder).borderSide.color,
              isNot(colors.error));
        }
        expect((d.errorBorder! as OutlineInputBorder).borderSide.color,
            (d.enabledBorder! as OutlineInputBorder).borderSide.color);
        expect((d.focusedErrorBorder! as OutlineInputBorder).borderSide.color,
            (d.focusedBorder! as OutlineInputBorder).borderSide.color);
      });
    }
  });

  group('the message itself', () {
    testWidgets('is rendered in the semantic error colour', (tester) async {
      await _pump(tester);
      final colors = _colors(tester);

      expect(_decoration(tester).errorStyle!.color, colors.error);
    });

    testWidgets('sits below the field, not inside it', (tester) async {
      await _pump(tester);
      await _tap(tester, _firstField);
      await _type(tester, _firstField, 'abc');
      await _tap(tester, _secondField);

      expect(
        tester.getTopLeft(find.text(_tooShort)).dy,
        greaterThan(tester.getBottomLeft(_firstField).dy - 1),
        reason: 'the error belongs under the input, not over it',
      );
    });
  });
}
