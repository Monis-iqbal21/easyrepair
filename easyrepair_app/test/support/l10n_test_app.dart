import 'package:flutter/material.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/l10n/l10n_config.dart';

/// Wraps [home] in a MaterialApp configured exactly like the real app root.
///
/// Any widget that reads `context.l10n` needs the localization delegates in
/// scope, so widget tests build their MaterialApp through this helper rather
/// than hand-rolling one — a test that forgot a delegate would fail with an
/// unhelpful null-check error.
MaterialApp localizedApp(
  Widget home, {
  AppLocale locale = AppLocale.english,
  NavigatorObserver? navigatorObserver,
  Map<String, WidgetBuilder> routes = const {},
}) {
  return MaterialApp(
    locale: locale.locale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    localeResolutionCallback: (_, _) => locale.locale,
    navigatorObservers: [?navigatorObserver],
    routes: routes,
    home: home,
  );
}
