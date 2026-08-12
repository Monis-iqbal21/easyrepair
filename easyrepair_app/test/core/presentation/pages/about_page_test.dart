import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/presentation/pages/about_page.dart';
import 'package:handygo_app/core/utils/app_version_info.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../support/l10n_test_app.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
        child: localizedApp(const AboutPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the HandyGo name', (tester) async {
    await pump(tester);
    expect(find.text('HandyGo'), findsWidgets);
  });

  testWidgets('shows the official website', (tester) async {
    await pump(tester);
    expect(find.text('https://handygo.ai'), findsOneWidget);
  });

  testWidgets('shows the runtime version/build from PackageInfo, not a hardcoded string', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Version 1.0.1 (2)'), findsOneWidget);
  });

  testWidgets('never invents marketing claims — description is the fixed factual line', (
    tester,
  ) async {
    await pump(tester);
    expect(
      find.text(
        'HandyGo connects clients with nearby verified Ustaads for home repair and maintenance services.',
      ),
      findsOneWidget,
    );
  });
}
