import 'dart:math' as math;

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
///
/// The screen is a full-bleed `primary` canvas carrying the approved logo plus
/// the "HandyGo" wordmark and "Har maslay ka ustaad" tagline as REAL TEXT —
/// the old decorative artwork and the baked-in logo lockup are gone. The
/// colour group at the bottom pins that every pixel still comes from the
/// central palette rather than from literals in the page.

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
      GoRoute(path: '/auth/language', builder: (_, _) => _stub('LANGUAGE')),
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

/// The wrench mark — the only image on the screen now that the wordmark and
/// tagline are real text.
final Finder _wrench = find.byType(Image);

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

    testWidgets('renders "HandyGo" and the tagline as real Flutter text, '
        'not as an image', (tester) async {
      await _pump(tester);

      expect(find.text('HandyGo'), findsOneWidget);
      expect(find.text('Har maslay ka ustaad'), findsOneWidget);
    });

    testWidgets('the tagline sits below the wordmark, which sits below the '
        'wrench', (tester) async {
      await _pump(tester);

      final wrench = tester.getCenter(
        find.byType(Image).first,
      );
      final wordmark = tester.getCenter(find.text('HandyGo'));
      final tagline = tester.getCenter(find.text('Har maslay ka ustaad'));

      expect(wordmark.dy, greaterThan(wrench.dy));
      expect(tagline.dy, greaterThan(wordmark.dy));
    });

    testWidgets('the old decorative artwork and baked-in wordmark are gone',
        (tester) async {
      await _pump(tester);

      final assets = tester
          .widgetList<Image>(find.byType(Image))
          .map((img) => (img.image as AssetImage).assetName)
          .toList();

      expect(assets, contains('assets/images/logo-final.png'));
      expect(assets, isNot(contains('assets/images/background.png')));
      expect(assets, isNot(contains('assets/images/handygo_logo.png')));
    });

    testWidgets('the canvas is the primary colour edge to edge — no cream '
        'frame around it', (tester) async {
      await _pump(tester);

      final context = tester.element(find.byType(ElevatedButton));
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, context.semanticColors.primary);
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

    testWidgets('exposes the brand name to screen readers exactly once — the '
        'wrench is decorative now that the wordmark is text', (tester) async {
      await _pump(tester);

      expect(find.bySemanticsLabel('HandyGo'), findsOneWidget);
      expect(find.bySemanticsLabel('Har maslay ka ustaad'), findsOneWidget);
    });

    testWidgets('sets light system-bar icons for the dark teal canvas',
        (tester) async {
      await _pump(tester);

      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
      );
      expect(region.value.statusBarIconBrightness, Brightness.light);
      expect(region.value.statusBarBrightness, Brightness.dark);
    });
  });

  group('navigation', () {
    testWidgets('Shuru karein opens the onboarding language step, NOT the '
        'role picker directly', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Shuru karein'));
      await tester.pumpAndSettle();

      // Asserted on what is actually on screen: an imperative push keeps the
      // base location in currentConfiguration, so the rendered page is the
      // honest signal here.
      expect(find.text('LANGUAGE'), findsOneWidget);
      expect(find.text('ROLE_SELECT'), findsNothing);
    });

    testWidgets('it PUSHES the language step, so Back returns to Welcome',
        (tester) async {
      final router = await _pump(tester);

      await tester.tap(find.text('Shuru karein'));
      await tester.pumpAndSettle();
      expect(find.text('LANGUAGE'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('Shuru karein'), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/welcome',
      );
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

    testWidgets('the wrench keeps its aspect ratio at every size',
        (tester) async {
      for (final size in const [
        Size(320, 568),
        Size(390, 844),
        Size(768, 1024),
      ]) {
        await _pump(tester, size: size);

        final box = tester.getRect(_wrench);
        expect(
          box.width / box.height,
          closeTo(1.0, 0.01),
          reason: 'the mark is drawn in a square box and never stretched',
        );
        final image = tester.widget<Image>(_wrench);
        expect(image.fit, BoxFit.contain);
      }
    });

    testWidgets('the wrench does not become absurd on a tablet',
        (tester) async {
      await _pump(tester, size: const Size(768, 1024));

      final wrench = tester.getRect(_wrench);
      expect(wrench.width, lessThanOrEqualTo(168.0),
          reason: 'capped so it does not balloon on wide screens');
      expect(wrench.width / 768, lessThan(0.4));
    });

    testWidgets('the whole lockup is constrained on a wide screen',
        (tester) async {
      await _pump(tester, size: const Size(768, 1024));

      final wordmark = tester.getRect(find.text('HandyGo'));
      expect(wordmark.width, lessThanOrEqualTo(460.0));
    });

    testWidgets('the wrench stays legible on the smallest screen',
        (tester) async {
      await _pump(tester, size: const Size(320, 568));

      final wrench = tester.getRect(_wrench);
      expect(wrench.width, greaterThan(90),
          reason: 'must not shrink into illegibility');
    });

    testWidgets('the lockup shrinks rather than crowding a short screen',
        (tester) async {
      await _pump(tester, size: const Size(640, 360));

      expect(tester.takeException(), isNull);
      final wrench = tester.getRect(_wrench);
      expect(wrench.width, lessThan(120),
          reason: 'the height budget, not the width, governs a short screen');
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
    // HandyGo's FINAL brand primary. Pinned here so a stray edit to the
    // central palette cannot quietly move the brand colour.
    const handyGoTeal = Color(0xFF11645D);

    testWidgets('the central primary token IS the HandyGo brand teal',
        (tester) async {
      await _pump(tester);

      final colors = tester.element(find.byType(ElevatedButton)).semanticColors;
      expect(colors.primary, handyGoTeal);
      expect(colors.primaryPressed, const Color(0xFF0D514B));
    });

    testWidgets('the old orange is no longer the brand primary anywhere '
        'central', (tester) async {
      await _pump(tester);

      const retiredOrange = Color(0xFFDB6234);
      final colors = tester.element(find.byType(ElevatedButton)).semanticColors;
      final theme = Theme.of(tester.element(find.byType(ElevatedButton)));

      expect(colors.primary, isNot(retiredOrange));
      expect(theme.colorScheme.primary, isNot(retiredOrange));
      expect(theme.colorScheme.primary, handyGoTeal);
    });

    testWidgets('the page paints its canvas from the primary token, without '
        'naming a colour itself', (tester) async {
      await _pump(tester);

      final colors = tester.element(find.byType(ElevatedButton)).semanticColors;
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, colors.primary);
    });

    testWidgets('the lockup text uses the on-primary token and stays legible '
        'on the brand fill', (tester) async {
      await _pump(tester);

      final colors = tester.element(find.byType(ElevatedButton)).semanticColors;
      final wordmark = tester.widget<Text>(find.text('HandyGo'));
      expect(wordmark.style!.color, colors.onPrimary);

      // Sanity-check the contrast rather than trusting the eye: the wordmark
      // must clear the WCAG AA large-text bar (3:1) on the primary canvas.
      final ratio = _contrastRatio(colors.onPrimary, colors.primary);
      expect(ratio, greaterThan(3.0));
    });

    testWidgets('the CTA takes the inverse pairing, so it cannot disappear '
        'into the primary canvas', (tester) async {
      await _pump(tester);

      final context = tester.element(find.byType(ElevatedButton));
      final colors = context.semanticColors;

      final style =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).style!;
      const enabled = <WidgetState>{};

      expect(style.backgroundColor!.resolve(enabled), colors.surface);
      expect(style.foregroundColor!.resolve(enabled), colors.primary);

      final arrow = tester.widget<Icon>(
        find.byIcon(Icons.arrow_forward_rounded),
      );
      expect(arrow.color, colors.primary);

      expect(_contrastRatio(colors.surface, colors.primary),
          greaterThan(4.5),
          reason: 'the CTA carries body-sized text');
    });

    testWidgets('changing the central palette repaints the page — no page '
        'edit required', (tester) async {
      // Proves the indirection is real: swap ONLY the theme extension and the
      // canvas, the lockup and the button all follow. This is what makes a
      // future palette change a one-file job.
      const swappedPrimary = Color(0xFF123456);
      const swappedOnPrimary = Color(0xFF654321);
      const swappedSurface = Color(0xFFABCDEF);

      final base = AppTheme.lightTheme;
      final theme = base.copyWith(
        extensions: <ThemeExtension<dynamic>>[
          AppSemanticColors.light.copyWith(
            primary: swappedPrimary,
            onPrimary: swappedOnPrimary,
            surface: swappedSurface,
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

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        swappedPrimary,
      );
      expect(
        tester.widget<Text>(find.text('HandyGo')).style!.color,
        swappedOnPrimary,
      );
      final style = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      ).style!;
      expect(style.backgroundColor!.resolve(const {}), swappedSurface);
      expect(style.foregroundColor!.resolve(const {}), swappedPrimary);
    });

    testWidgets('the same page renders from the DARK palette with no page '
        'change — the tokens carry both brightnesses', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          home: const WelcomePage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AppSemanticColors.dark.primary,
      );
      expect(
        tester.widget<Text>(find.text('HandyGo')).style!.color,
        AppSemanticColors.dark.onPrimary,
      );
    });
  });
}

/// WCAG relative-luminance contrast ratio between two opaque colours.
double _contrastRatio(Color a, Color b) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final la = luminance(a);
  final lb = luminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}
