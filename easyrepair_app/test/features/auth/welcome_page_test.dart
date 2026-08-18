import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/l10n/l10n_config.dart';
import 'package:handygo_app/core/router/app_router.dart';
import 'package:handygo_app/core/theme/app_semantic_colors.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';
import 'package:handygo_app/features/auth/presentation/pages/welcome_page.dart';
import 'package:handygo_app/features/auth/presentation/providers/auth_providers.dart';

/// The HandyGo branded welcome screen: what it shows, where its button goes,
/// that an authenticated user is never trapped on it, and that it survives
/// every phone size and text scale without overflowing.

const _client = UserEntity(
  id: 'c1',
  phone: '+923001234567',
  role: 'CLIENT',
  firstName: 'Ali',
  lastName: 'Khan',
);

const _worker = UserEntity(
  id: 'w1',
  phone: '+923001234568',
  role: 'WORKER',
  firstName: 'Bilal',
  lastName: 'Ahmed',
);

Widget _stub(String label) => Scaffold(body: Center(child: Text(label)));

class _FakeAuthStateNotifier extends AuthStateNotifier {
  _FakeAuthStateNotifier(this._user);
  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

/// Mirrors the real router's top-level auth redirect over the real
/// [WelcomePage], so "does Shuru karein reach role selection" and "is a
/// signed-in user bounced off this page" are answered by production logic.
GoRouter _router(ProviderContainer container, {String initialLocation = '/welcome'}) {
  // The real router re-runs its redirect when auth state settles; mirror that
  // here or the first (still-loading) decision would be the only one made.
  final refreshNotifier = ValueNotifier<bool>(false);
  container.listen(authStateProvider, (_, _) {
    refreshNotifier.value = !refreshNotifier.value;
  });

  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refreshNotifier,
    redirect: (context, state) => resolveAuthRedirect(
      authState: container.read(authStateProvider),
      matchedLocation: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => _stub('SPLASH')),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomePage()),
      GoRoute(
        path: '/auth/role-select',
        builder: (_, _) => _stub('ROLE_SELECT'),
      ),
      GoRoute(path: '/client/home', builder: (_, _) => _stub('CLIENT_HOME')),
      GoRoute(path: '/worker/home', builder: (_, _) => _stub('WORKER_HOME')),
    ],
  );
}

Future<GoRouter> _pump(
  WidgetTester tester, {
  UserEntity? user,
  AsyncValue<UserEntity?>? rawAuthState,
  Size size = const Size(390, 844),
  double textScale = 1.0,
  String initialLocation = '/welcome',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      if (rawAuthState == null)
        authStateProvider.overrideWith(() => _FakeAuthStateNotifier(user)),
    ],
  );
  addTearDown(container.dispose);

  final router = _router(container, initialLocation: initialLocation);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Image _imageWithAsset(WidgetTester tester, String assetName) {
  return tester
      .widgetList<Image>(find.byType(Image))
      .firstWhere((img) => (img.image as AssetImage).assetName == assetName);
}

void main() {
  group('content', () {
    testWidgets('shows the HandyGo logo lockup', (tester) async {
      await _pump(tester);

      final logo = _imageWithAsset(tester, WelcomePage.logoAsset);
      expect(logo.fit, BoxFit.contain, reason: 'never stretched or clipped');
    });

    testWidgets('renders the branded background full-bleed', (tester) async {
      await _pump(tester);

      final bg = _imageWithAsset(tester, WelcomePage.backgroundAsset);
      expect(bg.fit, BoxFit.cover,
          reason: 'BoxFit.fill would distort the artwork');
      expect(find.byType(Positioned).evaluate(), isNotEmpty);
    });

    testWidgets('shows the Shuru karein button with a trailing arrow',
        (tester) async {
      await _pump(tester);

      expect(find.text('Shuru karein'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('the arrow sits to the right of the label', (tester) async {
      await _pump(tester);

      final label = tester.getCenter(find.text('Shuru karein'));
      final arrow = tester.getCenter(find.byIcon(Icons.arrow_forward_rounded));
      expect(arrow.dx, greaterThan(label.dx));
    });

    testWidgets('exposes the logo to screen readers as "HandyGo"',
        (tester) async {
      await _pump(tester);
      expect(find.bySemanticsLabel('HandyGo'), findsOneWidget);
    });

    testWidgets('sets dark system-bar icons for the light artwork',
        (tester) async {
      await _pump(tester);

      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
      );
      expect(region.value.statusBarIconBrightness, Brightness.dark);
      expect(region.value.statusBarBrightness, Brightness.light);
    });
  });

  group('navigation', () {
    testWidgets('Shuru karein goes to the EXISTING role-selection route',
        (tester) async {
      final router = await _pump(tester);

      await tester.tap(find.text('Shuru karein'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/auth/role-select',
      );
      expect(find.text('ROLE_SELECT'), findsOneWidget);
    });
  });

  group('authenticated users are never trapped here', () {
    testWidgets('a signed-in CLIENT landing on /welcome is dispatched to '
        'Client Home', (tester) async {
      await _pump(tester, user: _client);

      expect(find.text('CLIENT_HOME'), findsOneWidget);
      expect(find.text('Shuru karein'), findsNothing);
    });

    testWidgets('a signed-in WORKER landing on /welcome is dispatched to '
        'Worker Home', (tester) async {
      await _pump(tester, user: _worker);

      expect(find.text('WORKER_HOME'), findsOneWidget);
      expect(find.text('Shuru karein'), findsNothing);
    });

    testWidgets('a signed-in Client opening the app goes straight to Home, '
        'never through the welcome screen', (tester) async {
      await _pump(tester, user: _client, initialLocation: '/splash');
      expect(find.text('CLIENT_HOME'), findsOneWidget);
    });
  });

  group('auth refresh safety', () {
    // Regression cover for the old "nested page -> splash -> home" bug: a
    // background refresh of an ALREADY-confirmed session keeps its previous
    // value, and must never be read as a logout that shows the welcome page.
    test('a refreshing session with a retained user is not sent to /welcome',
        () {
      final refreshing = const AsyncLoading<UserEntity?>()
          .copyWithPrevious(const AsyncData<UserEntity?>(_client));

      expect(
        resolveAuthRedirect(
          authState: refreshing,
          matchedLocation: '/client/booking/b1',
        ),
        isNull,
        reason: 'the user stays exactly where they were',
      );
    });

    test('an errored refresh with a retained user is not sent to /welcome',
        () {
      final errored = AsyncError<UserEntity?>(
        Exception('network blip'),
        StackTrace.empty,
      ).copyWithPrevious(const AsyncData<UserEntity?>(_worker));

      expect(
        resolveAuthRedirect(
          authState: errored,
          matchedLocation: '/worker/job/j1',
        ),
        isNull,
      );
    });

    test('a first-load failure with NO confirmed user waits on splash rather '
        'than guessing logged out', () {
      expect(
        resolveAuthRedirect(
          authState: AsyncError<UserEntity?>(
            Exception('no internet'),
            StackTrace.empty,
          ),
          matchedLocation: '/client/home',
        ),
        '/splash',
      );
    });
  });

  group('responsive — no overflow on any supported size', () {
    const sizes = <String, Size>{
      'iPhone SE / small Android 320x568': Size(320, 568),
      'common Android 360x640': Size(360, 640),
      'iPhone 14 390x844': Size(390, 844),
      'iPhone 16 Pro Max 430x932': Size(430, 932),
      'tablet-ish 768x1024': Size(768, 1024),
      'short landscape-ish 640x360': Size(640, 360),
    };

    sizes.forEach((name, size) {
      testWidgets('$name lays out without overflow', (tester) async {
        await _pump(tester, size: size);

        expect(tester.takeException(), isNull);
        expect(find.text('Shuru karein'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

        // The button is fully on screen and reachable.
        final button = tester.getRect(find.byType(ElevatedButton));
        expect(button.left, greaterThanOrEqualTo(0));
        expect(button.right, lessThanOrEqualTo(size.width + 0.5));
        expect(button.height, greaterThanOrEqualTo(48),
            reason: 'accessible minimum tap target');
      });
    });

    testWidgets('the logo keeps its aspect ratio at every size',
        (tester) async {
      for (final size in const [
        Size(320, 568),
        Size(390, 844),
        Size(768, 1024),
      ]) {
        await _pump(tester, size: size);

        final box = tester.getRect(find.byType(AspectRatio).first);
        expect(
          box.width / box.height,
          closeTo(WelcomePage.logoAspectRatio, 0.01),
          reason: 'the lockup must never be stretched',
        );
      }
    });

    testWidgets('the logo does not become absurd on a tablet', (tester) async {
      await _pump(tester, size: const Size(768, 1024));

      final logo = tester.getRect(find.byType(AspectRatio).first);
      expect(logo.width, lessThanOrEqualTo(420.0),
          reason: 'capped so it does not balloon on wide screens');
      expect(logo.width / 768, lessThan(0.7));
    });

    testWidgets('the logo stays legible on the smallest screen',
        (tester) async {
      await _pump(tester, size: const Size(320, 568));

      final logo = tester.getRect(find.byType(AspectRatio).first);
      expect(logo.width, greaterThan(150),
          reason: 'must not shrink into illegibility');
    });

    testWidgets('the button is capped to a comfortable width on a tablet',
        (tester) async {
      await _pump(tester, size: const Size(768, 1024));

      final button = tester.getRect(find.byType(ElevatedButton));
      expect(button.width, lessThanOrEqualTo(460.0));
    });
  });

  group('accessibility text scaling', () {
    for (final scale in const [1.3, 1.6, 2.0]) {
      testWidgets('text scale ${scale}x does not overflow or hide the button',
          (tester) async {
        await _pump(tester, size: const Size(320, 568), textScale: scale);

        expect(tester.takeException(), isNull);
        expect(find.text('Shuru karein'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
      });
    }

    testWidgets('an extreme text scale scrolls rather than overflowing',
        (tester) async {
      await _pump(tester, size: const Size(320, 568), textScale: 3.0);

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });

  group('colour architecture', () {
    testWidgets('the button paints from the central semantic tokens, not '
        'from literals baked into the page', (tester) async {
      await _pump(tester);

      final context = tester.element(find.byType(ElevatedButton));
      final colors = context.semanticColors;

      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      final style = button.style!;
      const enabled = <WidgetState>{};

      expect(style.backgroundColor!.resolve(enabled), colors.primary);
      expect(style.foregroundColor!.resolve(enabled), colors.onPrimary);

      final arrow = tester.widget<Icon>(
        find.byIcon(Icons.arrow_forward_rounded),
      );
      expect(arrow.color, colors.onPrimary);
    });

    testWidgets('changing the central palette repaints the button — no page '
        'edit required', (tester) async {
      // Proves the indirection is real: swap ONLY the theme extension and the
      // button follows. This is what makes the future HandyGo palette change
      // a one-file job.
      const swapped = Color(0xFF123456);
      const swappedOn = Color(0xFF654321);

      final base = AppTheme.lightTheme;
      final theme = base.copyWith(
        extensions: <ThemeExtension<dynamic>>[
          AppSemanticColors.fromColorScheme(base.colorScheme).copyWith(
            primary: swapped,
            onPrimary: swappedOn,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          home: const WelcomePage(),
        ),
      );
      await tester.pumpAndSettle();

      final style = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      ).style!;
      expect(style.backgroundColor!.resolve(const {}), swapped);
      expect(style.foregroundColor!.resolve(const {}), swappedOn);
    });
  });
}
