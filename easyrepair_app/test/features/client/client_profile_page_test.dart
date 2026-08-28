import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/l10n/locale_provider.dart';
import 'package:handygo_app/core/network/api_client.dart';
import 'package:handygo_app/core/notifications/notification_permission_service.dart';
import 'package:handygo_app/core/presentation/pages/about_page.dart';
import 'package:handygo_app/core/presentation/pages/general_info_page.dart';
import 'package:handygo_app/core/presentation/pages/privacy_policy_page.dart';
import 'package:handygo_app/core/presentation/pages/terms_conditions_page.dart';
import 'package:handygo_app/core/theme/app_semantic_colors.dart';
import 'package:handygo_app/core/utils/app_version_info.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';
import 'package:handygo_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:handygo_app/features/client/presentation/pages/client_agreements_page.dart';
import 'package:handygo_app/features/client/presentation/pages/client_profile_page.dart';
import 'package:handygo_app/features/client/presentation/providers/customer_agreement_providers.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n_test_app.dart';

const _user = UserEntity(
  id: 'client-1',
  phone: '+923001234567',
  role: 'CLIENT',
  firstName: 'Ayesha',
  lastName: 'Khan',
);

class _StubAuthState extends AuthStateNotifier {
  @override
  Future<UserEntity?> build() async => _user;
}

/// Refuses every request the moment it is made, so the page's post-frame
/// avatar fetch resolves immediately instead of leaving `pumpAndSettle`
/// waiting on a socket that will never open.
class _OfflineAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'offline in tests',
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  AppLocale locale = AppLocale.english,
}) async {
  SharedPreferences.setMockInitialValues({
    kLocalePrefsKey: locale.storageValue,
  });
  final prefs = await SharedPreferences.getInstance();

  final dio = Dio()..httpClientAdapter = _OfflineAdapter();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith(_StubAuthState.new),
        dioProvider.overrideWithValue(dio),
        // Granted → the recovery card renders nothing, which is the normal
        // state this test is about.
        notificationPermissionStateProvider.overrideWith(
          (ref) async => NotificationPermissionState.granted,
        ),
        customerAgreementHistoryProvider.overrideWith((ref) async => []),
        appVersionInfoProvider.overrideWith(
          (ref) async => PackageInfo(
            appName: 'HandyGo',
            packageName: 'com.handygo.app',
            version: '1.0.1',
            buildNumber: '2',
            buildSignature: '',
          ),
        ),
      ],
      child: localizedApp(const ClientProfilePage(), locale: locale),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openRow(WidgetTester tester, String label) async {
  final row = find.text(label).last;
  // The default 800x600 test window is shorter than the settings list.
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

void main() {
  group('Client Profile identity', () {
    testWidgets('shows the signed-in name and phone verbatim', (tester) async {
      await _pump(tester);

      expect(find.text('Ayesha Khan'), findsOneWidget);
      expect(find.text('+923001234567'), findsOneWidget);
    });

    testWidgets('a name and a phone number are never translated', (
      tester,
    ) async {
      await _pump(tester, locale: AppLocale.urdu);

      expect(find.text('Ayesha Khan'), findsOneWidget);
      expect(find.text('+923001234567'), findsOneWidget);
    });
  });

  group('Client Profile navigation', () {
    testWidgets('General opens the shared General Info page', (tester) async {
      await _pump(tester);
      await _openRow(tester, 'General');

      expect(find.byType(GeneralInfoPage), findsOneWidget);
    });

    testWidgets('Privacy Policy opens the shared legal page', (tester) async {
      await _pump(tester);
      await _openRow(tester, 'Privacy Policy');

      expect(find.byType(PrivacyPolicyPage), findsOneWidget);
    });

    testWidgets('Terms & Conditions opens the shared legal page', (
      tester,
    ) async {
      await _pump(tester);
      await _openRow(tester, 'Terms & Conditions');

      expect(find.byType(TermsConditionsPage), findsOneWidget);
    });

    testWidgets('Accepted Agreements opens the Client agreement history', (
      tester,
    ) async {
      await _pump(tester);
      await _openRow(tester, 'Accepted Agreements');

      expect(find.byType(ClientAgreementsPage), findsOneWidget);
    });

    testWidgets('About opens the shared About page', (tester) async {
      await _pump(tester);
      await _openRow(tester, 'About HandyGo');

      expect(find.byType(AboutPage), findsOneWidget);
    });

    testWidgets('the language row shows the active language and opens the '
        'selector', (tester) async {
      await _pump(tester);

      // The current language is readable without opening anything.
      expect(find.text('English'), findsOneWidget);

      await _openRow(tester, 'Language');

      // All three options, each naming itself.
      expect(find.text('اردو'), findsOneWidget);
      expect(find.text('Roman Urdu'), findsOneWidget);
      expect(find.text('English'), findsWidgets);
    });
  });

  group('Client Profile grouping', () {
    testWidgets('every section header is present', (tester) async {
      await _pump(tester);

      for (final header in [
        'ACCOUNT',
        'SETTINGS',
        'LEGAL',
        'SUPPORT',
        'DANGER ZONE',
      ]) {
        expect(find.text(header), findsOneWidget, reason: '$header is missing');
      }
    });

    testWidgets('section headers are not uppercased in Urdu — Urdu has no '
        'letter case', (tester) async {
      await _pump(tester, locale: AppLocale.urdu);

      // Nothing on the page shouts in caps.
      expect(find.text('ACCOUNT'), findsNothing);
      expect(find.text('DANGER ZONE'), findsNothing);
    });

    testWidgets('logout is offered, and is not styled as the destructive '
        'action — Delete Account is', (tester) async {
      await _pump(tester);

      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Logout'),
      );
      final context = tester.element(find.byType(ClientProfilePage));
      final c = context.semanticColors;

      final side = button.style?.side?.resolve({});
      expect(side?.color, c.border);
      expect(side?.color, isNot(c.error));

      expect(find.text('Delete Account'), findsOneWidget);
    });
  });

  group('Client Profile theme discipline', () {
    testWidgets('the page paints on the semantic background, not a literal', (
      tester,
    ) async {
      await _pump(tester);

      final context = tester.element(find.byType(ClientProfilePage));
      final scaffold = tester.widget<Scaffold>(
        find.descendant(
          of: find.byType(ClientProfilePage),
          matching: find.byType(Scaffold),
        ),
      );
      expect(scaffold.backgroundColor, context.semanticColors.background);
    });

    testWidgets('no card in the profile casts a shadow', (tester) async {
      await _pump(tester);

      final decorated = tester
          .widgetList<Container>(find.byType(Container))
          .map((container) => container.decoration)
          .whereType<BoxDecoration>();

      expect(decorated, isNotEmpty);
      for (final decoration in decorated) {
        expect(
          decoration.boxShadow,
          anyOf(isNull, isEmpty),
          reason: 'HandyGo cards are surface + radius + a hairline, no shadow',
        );
      }
    });
  });

  group('Client Profile responsiveness', () {
    for (final size in [
      const Size(320, 800), // narrow Android
      const Size(360, 780),
      const Size(390, 844), // iPhone 14/15
      const Size(430, 932), // iPhone Pro Max
    ]) {
      testWidgets('lays out without overflow at ${size.width.toInt()}px wide', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await _pump(tester);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('survives a 2.0 text scale without overflowing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({
        kLocalePrefsKey: AppLocale.english.storageValue,
      });
      final prefs = await SharedPreferences.getInstance();
      final dio = Dio()..httpClientAdapter = _OfflineAdapter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authStateProvider.overrideWith(_StubAuthState.new),
            dioProvider.overrideWithValue(dio),
            notificationPermissionStateProvider.overrideWith(
              (ref) async => NotificationPermissionState.granted,
            ),
          ],
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: localizedApp(const ClientProfilePage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
