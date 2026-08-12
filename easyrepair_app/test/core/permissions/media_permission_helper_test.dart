import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/permissions/media_permission_helper.dart';
import 'package:handygo_app/l10n/app_localizations.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

import '../../support/l10n_test_app.dart';

class _FakePermissionHandlerPlatform extends PermissionHandlerPlatform {
  PermissionStatus status = PermissionStatus.granted;
  int openAppSettingsCalls = 0;

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async => status;

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalls++;
    return true;
  }
}

/// Pumps a page with a button that runs [action] with the real [BuildContext],
/// so the SnackBar recovery logic can be exercised end-to-end without ever
/// touching a real picker or platform channel.
Future<void> _pumpAndRun(
  WidgetTester tester,
  Future<void> Function(BuildContext context) action,
) async {
  await tester.pumpWidget(
    localizedApp(
      Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => action(context),
            child: const Text('trigger'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('trigger'));
  await tester.pumpAndSettle();
}

void main() {
  late _FakePermissionHandlerPlatform fake;

  setUp(() {
    fake = _FakePermissionHandlerPlatform();
    PermissionHandlerPlatform.instance = fake;
  });

  group('runPickerWithRecovery', () {
    testWidgets('a successful pick returns the value untouched, no SnackBar',
        (tester) async {
      String? result;
      await _pumpAndRun(tester, (context) async {
        result = await runPickerWithRecovery<String>(
          context,
          MediaPermissionKind.camera,
          () async => 'picked-path',
        );
      });

      expect(result, 'picked-path');
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
      'a camera_access_denied PlatformException shows the camera-specific '
      'friendly message — never the raw exception',
      (tester) async {
        fake.status = PermissionStatus.denied;
        await _pumpAndRun(tester, (context) async {
          await runPickerWithRecovery<String>(
            context,
            MediaPermissionKind.camera,
            () async => throw PlatformException(code: 'camera_access_denied'),
          );
        });

        final context = tester.element(find.byType(Scaffold));
        final l10n = AppLocalizations.of(context);
        expect(find.text(l10n.cameraPermissionDeniedMessage), findsOneWidget);
        expect(find.textContaining('PlatformException'), findsNothing);
      },
    );

    testWidgets(
      'a photo_access_denied PlatformException shows the gallery-specific '
      'friendly message',
      (tester) async {
        fake.status = PermissionStatus.denied;
        await _pumpAndRun(tester, (context) async {
          await runPickerWithRecovery<String>(
            context,
            MediaPermissionKind.gallery,
            () async => throw PlatformException(code: 'photo_access_denied'),
          );
        });

        final context = tester.element(find.byType(Scaffold));
        final l10n = AppLocalizations.of(context);
        expect(find.text(l10n.galleryPermissionDeniedMessage), findsOneWidget);
      },
    );

    testWidgets(
      'when already permanently denied, the picker is never invoked at all '
      '— the recovery message with an Open Settings action shows immediately',
      (tester) async {
        fake.status = PermissionStatus.permanentlyDenied;
        var pickerCalled = false;
        await _pumpAndRun(tester, (context) async {
          await runPickerWithRecovery<String>(
            context,
            MediaPermissionKind.camera,
            () async {
              pickerCalled = true;
              return 'unused';
            },
          );
        });

        expect(pickerCalled, isFalse);
        final context = tester.element(find.byType(Scaffold));
        final l10n = AppLocalizations.of(context);
        expect(find.text(l10n.cameraPermissionDeniedMessage), findsOneWidget);
        expect(find.text(l10n.commonOpenSettings), findsOneWidget);

        await tester.tap(find.text(l10n.commonOpenSettings));
        await tester.pumpAndSettle();
        expect(fake.openAppSettingsCalls, 1);
      },
    );

    testWidgets(
      'a non-permission PlatformException (e.g. no camera hardware) shows '
      'the generic friendly message, never raw exception text',
      (tester) async {
        await _pumpAndRun(tester, (context) async {
          await runPickerWithRecovery<String>(
            context,
            MediaPermissionKind.camera,
            () async => throw PlatformException(code: 'some_other_failure', message: 'boom'),
          );
        });

        final context = tester.element(find.byType(Scaffold));
        final l10n = AppLocalizations.of(context);
        expect(find.text(l10n.errorUnknown), findsOneWidget);
        expect(find.textContaining('boom'), findsNothing);
        expect(find.textContaining('PlatformException'), findsNothing);
      },
    );

    testWidgets('user cancelling the picker (returns null) shows no SnackBar',
        (tester) async {
      await _pumpAndRun(tester, (context) async {
        await runPickerWithRecovery<String?>(
          context,
          MediaPermissionKind.gallery,
          () async => null,
        );
      });

      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
