import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/notifications/notification_permission_card.dart';
import 'package:handygo_app/l10n/app_localizations.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

import '../../support/l10n_test_app.dart';

class _FakePermissionHandlerPlatform extends PermissionHandlerPlatform {
  PermissionStatus status = PermissionStatus.granted;
  int openAppSettingsCalls = 0;
  int requestCalls = 0;

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async => status;

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    requestCalls++;
    status = PermissionStatus.granted;
    return {for (final p in permissions) p: status};
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalls++;
    return true;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  AppLocale locale = AppLocale.english,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: localizedApp(
        const Scaffold(body: NotificationPermissionCard()),
        locale: locale,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late _FakePermissionHandlerPlatform fake;

  setUp(() {
    fake = _FakePermissionHandlerPlatform();
    PermissionHandlerPlatform.instance = fake;
  });

  group('NotificationPermissionCard', () {
    testWidgets('renders nothing when permission is already granted — no '
        'nagging when there is nothing to recover', (tester) async {
      fake.status = PermissionStatus.granted;
      await _pump(tester);

      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.text(l10n.notificationsPermissionOffMessage), findsNothing);
    });

    testWidgets('deniedCanAsk shows the recovery message with an "Allow '
        'Notifications" action that re-requests', (tester) async {
      fake.status = PermissionStatus.denied;
      await _pump(tester);

      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.text(l10n.notificationsPermissionOffMessage), findsOneWidget);
      expect(find.text(l10n.notificationsAllowAction), findsOneWidget);

      await tester.tap(find.text(l10n.notificationsAllowAction));
      await tester.pumpAndSettle();

      expect(fake.requestCalls, 1);
      // The card disappears once the request succeeded (status is now granted).
      expect(find.text(l10n.notificationsPermissionOffMessage), findsNothing);
    });

    testWidgets('permanentlyDenied shows the same message but an "Open '
        'Settings" action instead', (tester) async {
      fake.status = PermissionStatus.permanentlyDenied;
      await _pump(tester);

      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.text(l10n.notificationsPermissionOffMessage), findsOneWidget);
      expect(find.text(l10n.commonOpenSettings), findsOneWidget);
      expect(find.text(l10n.notificationsAllowAction), findsNothing);

      await tester.tap(find.text(l10n.commonOpenSettings));
      await tester.pumpAndSettle();

      expect(fake.openAppSettingsCalls, 1);
      expect(fake.requestCalls, 0,
          reason: 'permanently denied must never re-trigger the OS prompt');
    });

    testWidgets('the recovery message is distinct per language', (tester) async {
      fake.status = PermissionStatus.denied;
      final seen = <String>{};
      for (final locale in AppLocale.values) {
        await _pump(tester, locale: locale);
        final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
        seen.add(l10n.notificationsPermissionOffMessage);
      }
      expect(seen.length, AppLocale.values.length);
    });
  });
}
