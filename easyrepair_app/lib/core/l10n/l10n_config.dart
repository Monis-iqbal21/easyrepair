import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../l10n/app_localizations.dart';
import 'global_localizations_fallback.dart';

/// The localization wiring handed to `MaterialApp.router`.
///
/// Kept here rather than inline in `app.dart` so tests configure their
/// `MaterialApp` from exactly the same list the app ships with — a test that
/// built its own delegate list could pass while the real app was misconfigured.
/// The type arguments are spelled out deliberately. `Localizations` looks each
/// delegate up by its exact type parameter, so letting the list's element type
/// infer them to `Object?` silently produces an app with no MaterialLocalizations.
const List<LocalizationsDelegate<Object?>> appLocalizationsDelegates = [
  AppLocalizations.delegate,
  // Wrapped so Roman Urdu (ur_Latn) resolves these to English — without it
  // GlobalWidgetsLocalizations would force RTL on Latin script.
  RomanUrduFallbackDelegate<WidgetsLocalizations>(
    GlobalWidgetsLocalizations.delegate,
  ),
  RomanUrduFallbackDelegate<MaterialLocalizations>(
    GlobalMaterialLocalizations.delegate,
  ),
  RomanUrduFallbackDelegate<CupertinoLocalizations>(
    GlobalCupertinoLocalizations.delegate,
  ),
];

/// The three locales the app ships in, generated from the ARB files.
const List<Locale> appSupportedLocales = AppLocalizations.supportedLocales;
