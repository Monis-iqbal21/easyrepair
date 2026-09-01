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
    'startup stays off-white and uses the primary logo in dark mode',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authStateProvider.overrideWith(_LoadingAuthState.new)],
          child: localizedApp(const SplashPage(), theme: AppTheme.darkTheme),
        ),
      );
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppSemanticColors.light.background);
      expect(
        find.image(
          const AssetImage('assets/images/logo-primary-transparent.png'),
        ),
        findsOneWidget,
      );

      final wordmark = tester.widget<Text>(find.text('HandyGo'));
      expect(wordmark.style!.color, AppSemanticColors.light.textPrimary);
      expect(tester.takeException(), isNull);
    },
  );
}
