import 'package:flutter/widgets.dart';

/// The three languages HandyGo ships in.
///
/// The app never resolves the language from the device — [romanUrdu] is the
/// default for anyone with no saved choice yet (first install, or app data/
/// storage cleared), across every screen including role selection and
/// login/register. Once a user picks a language it is persisted and used
/// verbatim until they change it again; picking never gets reset by logout.
enum AppLocale {
  english,
  urdu,
  romanUrdu;

  /// Value written to SharedPreferences. Stable across releases — changing one
  /// of these would silently reset every user's choice.
  String get storageValue => switch (this) {
        AppLocale.english => 'en',
        AppLocale.urdu => 'ur',
        AppLocale.romanUrdu => 'ur_Latn',
      };

  Locale get locale => switch (this) {
        AppLocale.english => const Locale('en'),
        AppLocale.urdu => const Locale('ur'),
        // Roman Urdu has no dedicated Flutter locale; ur + Latn script is the
        // standard BCP-47 way to say "Urdu written in Latin script".
        AppLocale.romanUrdu =>
          const Locale.fromSubtags(languageCode: 'ur', scriptCode: 'Latn'),
      };

  /// Shown in the language selector. Deliberately NOT translated — each
  /// language names itself, so a user who cannot read the current language can
  /// still find their own.
  String get displayLabel => switch (this) {
        AppLocale.english => 'English',
        AppLocale.urdu => 'اردو',
        AppLocale.romanUrdu => 'Roman Urdu',
      };

  /// The name shown on the onboarding language cards (see
  /// `LanguageSelectionPage`), where Roman Urdu is described more fully than
  /// the short [displayLabel] used in the settings sheet.
  ///
  /// Lives here rather than in the ARB files for the same reason as
  /// [displayLabel]: each option names itself, so the wording must be
  /// identical whatever locale is currently active — a user who cannot read
  /// the active language still has to be able to find their own. Putting it
  /// in the ARB would mean three keys carrying the same English text, which
  /// the translation set explicitly forbids (see arb_parity_test.dart).
  String get onboardingLabel => switch (this) {
        AppLocale.english => 'English',
        AppLocale.urdu => 'اردو',
        AppLocale.romanUrdu => 'Roman Urdu + Easy English',
      };

  /// HandyGo never mirrors its interface: the layout is left-to-right in all
  /// three languages, and Urdu changes the words only. Enforced app-wide by
  /// `AlwaysLtrWidgetsLocalizationsDelegate`, which pins the ambient
  /// `Directionality`; this getter exists so nothing has to re-derive the
  /// answer per-locale and accidentally reintroduce RTL.
  TextDirection get textDirection => TextDirection.ltr;

  /// Reads a persisted value, falling back to Roman Urdu for anything unknown
  /// (no saved choice yet, corrupted value, or a language removed in a later
  /// release) — HandyGo's app-wide default.
  static AppLocale fromStorage(String? value) {
    for (final option in AppLocale.values) {
      if (option.storageValue == value) return option;
    }
    return AppLocale.romanUrdu;
  }

  /// Maps a [Locale] back to the option that produced it.
  static AppLocale fromLocale(Locale locale) {
    if (locale.languageCode != 'ur') return AppLocale.english;
    return locale.scriptCode == 'Latn' ? AppLocale.romanUrdu : AppLocale.urdu;
  }
}
