import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/theme/app_semantic_colors.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/core/widgets/handygo_brand_lockup.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';
import 'package:handygo_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:handygo_app/features/client/presentation/pages/client_home_page.dart';
import 'package:handygo_app/features/notifications/presentation/providers/notification_providers.dart';

import '../../support/l10n_test_app.dart';

class _SignedInClient extends AuthStateNotifier {
  @override
  Future<UserEntity?> build() async => const UserEntity(
    id: 'client-1',
    phone: '+923001234567',
    role: 'CLIENT',
    firstName: 'Sara',
    lastName: 'Khan',
  );
}

Future<void> _pumpHome(
  WidgetTester tester,
  ThemeData theme, {
  AppLocale locale = AppLocale.english,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(_SignedInClient.new),
        currentClientAreaProvider.overrideWith((ref) async => 'Lahore'),
        unreadNotificationCountProvider.overrideWith((ref) async => 0),
      ],
      child: localizedApp(const ClientHomePage(), theme: theme, locale: locale),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final entry in <String, ThemeData>{
    'light': AppTheme.lightTheme,
    'dark': AppTheme.darkTheme,
  }.entries) {
    testWidgets('home branding uses the approved logo and semantic colors in '
        '${entry.key} theme', (tester) async {
      await _pumpHome(tester, entry.value);

      expect(find.byType(HandyGoBrandMark), findsOneWidget);
      expect(
        find.image(
          const AssetImage('assets/images/logo-primary-transparent.png'),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.home_repair_service_rounded), findsNothing);

      final context = tester.element(find.text('Need help right now?'));
      final colors = context.semanticColors;
      final title = tester.widget<Text>(find.text('Need help right now?'));
      final badge = tester.widget<Text>(find.text('24/7'));
      expect(title.style!.color, colors.primary);
      expect(badge.style!.color, colors.onPrimary);

      final primaryOutlinedCards = tester
          .widgetList<Material>(find.byType(Material))
          .where((material) {
            final shape = material.shape;
            return material.color == colors.surface &&
                shape is RoundedRectangleBorder &&
                shape.side.color == colors.primary;
          });
      expect(primaryOutlinedCards, hasLength(1));

      final primaryAvatars = tester
          .widgetList<CircleAvatar>(find.byType(CircleAvatar))
          .where(
            (avatar) =>
                avatar.backgroundColor == colors.primary &&
                avatar.foregroundColor == colors.onPrimary,
          );
      expect(primaryAvatars, hasLength(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Roman Urdu home uses the requested service heading', (
    tester,
  ) async {
    await _pumpHome(tester, AppTheme.lightTheme, locale: AppLocale.romanUrdu);

    expect(find.text('Service select karein'), findsOneWidget);
    expect(find.text('Kya karwana hai?'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
