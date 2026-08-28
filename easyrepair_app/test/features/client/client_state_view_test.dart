import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/l10n/l10n_extensions.dart';
import 'package:handygo_app/core/theme/app_semantic_colors.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/client/presentation/widgets/client_state_view.dart';

import '../../support/l10n_test_app.dart';

Widget _stateHarness({
  required Widget child,
  double width = 390,
  double textScale = 1,
}) {
  return Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      height: 600,
      child: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 600),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  testWidgets('loading renders progress and localized helper text', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => _stateHarness(
            child: ClientStateView.loading(
              message: context.l10n.clientStateLoading,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading…'), findsOneWidget);
  });

  testWidgets('empty state renders contextual copy and invokes its CTA', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      localizedApp(
        _stateHarness(
          child: ClientStateView.empty(
            icon: Icons.receipt_long_outlined,
            title: 'No bookings yet',
            message: 'Post a repair request when you need an Ustaad.',
            actionLabel: 'Post a job',
            onAction: () => calls++,
          ),
        ),
      ),
    );

    expect(find.text('No bookings yet'), findsOneWidget);
    expect(
      find.text('Post a repair request when you need an Ustaad.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Post a job'));
    expect(calls, 1);
  });

  testWidgets('error state invokes the supplied retry callback', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      localizedApp(
        _stateHarness(
          child: ClientStateView.error(
            title: 'We could not load this',
            message: 'Please check your connection and try again.',
            actionLabel: 'Retry',
            onAction: () => retries++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets(
    'long localized state copy does not overflow at supported widths',
    (tester) async {
      for (final locale in AppLocale.values) {
        for (final width in <double>[320, 360, 390, 430]) {
          await tester.pumpWidget(
            localizedApp(
              Builder(
                builder: (context) => _stateHarness(
                  width: width,
                  textScale: 2,
                  child: ClientStateView.empty(
                    icon: Icons.gavel_rounded,
                    title: context.l10n.customerAgreementHistoryEmptyTitle,
                    message: context.l10n.customerAgreementHistoryEmptyHelper,
                    actionLabel: context.l10n.commonRetry,
                    onAction: () {},
                  ),
                ),
              ),
              locale: locale,
            ),
          );
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: '${locale.name} overflowed at ${width.toInt()} px',
          );
        }
      }
    },
  );

  testWidgets('error treatment uses dark-theme semantic colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(
        _stateHarness(
          child: ClientStateView.error(
            title: 'Unavailable',
            message: 'Try again.',
            actionLabel: 'Retry',
            onAction: () {},
          ),
        ),
        theme: AppTheme.darkTheme,
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline_rounded));
    expect(icon.color, AppSemanticColors.dark.error);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox &&
            widget.color == AppSemanticColors.dark.background,
      ),
      findsWidgets,
    );
    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(
      button.style?.foregroundColor?.resolve({}),
      AppSemanticColors.dark.primary,
    );
  });
}
