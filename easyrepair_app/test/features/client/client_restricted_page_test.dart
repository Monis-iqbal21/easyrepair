import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:handygo_app/features/client/presentation/pages/client_restricted_page.dart';
import 'package:handygo_app/features/client/presentation/widgets/client_bottom_nav_bar.dart';

import '../../support/l10n_test_app.dart';

class _FakeLogoutNotifier extends LogoutNotifier {
  int calls = 0;

  @override
  Future<void> build() async {}

  @override
  Future<void> logout() async {
    calls++;
    state = const AsyncData(null);
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  final launchCalls = <MethodCall>[];

  setUp(() {
    launchCalls.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        launchCalls.add(call);
        return true;
      },
    );
  });

  Future<_FakeLogoutNotifier> pump(WidgetTester tester) async {
    final fakeLogout = _FakeLogoutNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [logoutNotifierProvider.overrideWith(() => fakeLogout)],
        child: localizedApp(const ClientRestrictedPage()),
      ),
    );
    await tester.pumpAndSettle();
    return fakeLogout;
  }

  testWidgets('shows the restricted-account message', (tester) async {
    await pump(tester);
    expect(
      find.text(
        'Your HandyGo account has been suspended. Please contact Support for more information.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders no bottom navigation — nothing to tap into', (tester) async {
    await pump(tester);
    expect(find.byType(ClientBottomNavBar), findsNothing);
  });

  testWidgets(
    'system/Android back is swallowed — PopScope(canPop: false) blocks it',
    (tester) async {
      await pump(tester);
      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);
    },
  );

  testWidgets('Contact Support dials the HandyGo support number', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Contact Support'));
    await tester.pumpAndSettle();

    expect(launchCalls, hasLength(1));
    final uri = launchCalls.single.arguments['url'] as String;
    expect(uri, 'tel:+923320219006');
  });

  testWidgets('Logout calls the existing logout notifier', (tester) async {
    final fakeLogout = await pump(tester);

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    expect(fakeLogout.calls, 1);
  });
}
