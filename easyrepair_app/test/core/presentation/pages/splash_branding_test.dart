import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/presentation/pages/splash_page.dart';
import 'package:handygo_app/core/theme/app_semantic_colors.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';
import 'package:handygo_app/features/auth/presentation/providers/auth_providers.dart';

import '../../../support/l10n_test_app.dart';

class _LoadingAuthState extends AuthStateNotifier {
  @override
  Future<UserEntity?> build() => Completer<UserEntity?>().future;
}

void main() {
  testWidgets(
    'startup is the approved icon — brand teal carrying the off-white mark — '
    'and stays that way in dark mode',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authStateProvider.overrideWith(_LoadingAuthState.new)],
          child: localizedApp(const SplashPage(), theme: AppTheme.darkTheme),
        ),
      );
      await tester.pump();

      // The loading screen takes over from a native launch screen painted in
      // the brand teal that neither platform can theme, so it holds that
      // colour whatever the saved dark-mode preference says.
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppSemanticColors.light.primary);

      // The off-white mark from logo-final.png, drawn straight onto the teal.
      expect(
        find.image(
          const AssetImage('assets/images/logo-onprimary-transparent.png'),
        ),
        findsOneWidget,
      );

      // The inverse — a teal mark, which would need an off-white tile behind
      // it to be legible here — is not HandyGo's startup branding.
      expect(
        find.image(
          const AssetImage('assets/images/logo-primary-transparent.png'),
        ),
        findsNothing,
      );

      final wordmark = tester.widget<Text>(find.text('HandyGo'));
      expect(wordmark.style!.color, AppSemanticColors.light.onPrimary);
      expect(tester.takeException(), isNull);
    },
  );
}
