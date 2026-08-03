import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Supplies `WidgetsLocalizations` for every language, always in English —
/// which means always [TextDirection.ltr].
///
/// This is the single point where HandyGo's "never mirror the interface"
/// decision is enforced, and it is worth being precise about why it works
/// here and nowhere else.
///
/// `Localizations` sets the ambient [Directionality] for the whole subtree
/// from `WidgetsLocalizations.textDirection`, and `GlobalWidgetsLocalizations`
/// derives that from the language code alone — so plain `ur` would turn the
/// entire app right-to-left: rows, app bars, cards, icons, list order,
/// padding, navigation. HandyGo is designed left-to-right in all three
/// languages, so the direction is pinned at the source instead of being
/// patched over by `Directionality` wrappers on individual screens, which
/// would leave every unwrapped widget mirrored.
///
/// What this deliberately does NOT change:
///
///  * App copy — that comes from the generated `AppLocalizations`, which still
///    receives the real `ur` / `ur_Latn` and still renders Urdu script.
///  * Material and Cupertino strings — those keep their own delegates (see
///    [RomanUrduFallbackDelegate]) so "Cancel"/"Paste" are still translated.
///  * Urdu glyph shaping or within-paragraph bidi — Unicode handles those from
///    the characters themselves; an Urdu string renders correctly inside an
///    LTR paragraph.
class AlwaysLtrWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const AlwaysLtrWidgetsLocalizationsDelegate();

  /// Every locale the app supports, including ones added later.
  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      // Synchronous for `en`, so pinning the direction costs no extra frame.
      GlobalWidgetsLocalizations.delegate.load(const Locale('en'));

  @override
  bool shouldReload(
    covariant LocalizationsDelegate<WidgetsLocalizations> old,
  ) =>
      false;
}

/// Resolves Roman Urdu (`ur_Latn`) to English before handing a locale to
/// Flutter's own `GlobalMaterialLocalizations` / `GlobalCupertinoLocalizations`.
///
/// Roman Urdu is Urdu written in Latin script, so Material's own strings
/// ("Cancel", "Paste") should stay Latin rather than switching to Urdu script
/// mid-sentence. Urdu proper still gets the real `ur` Material strings.
///
/// Text direction is no longer this delegate's concern — that is pinned for
/// every language by [AlwaysLtrWidgetsLocalizationsDelegate].
///
/// The app's own strings are unaffected — those come from the generated
/// `AppLocalizations` delegate, which still receives the real `ur_Latn`.
class RomanUrduFallbackDelegate<T> extends LocalizationsDelegate<T> {
  const RomanUrduFallbackDelegate(this._inner);

  final LocalizationsDelegate<T> _inner;

  static Locale resolve(Locale locale) =>
      locale.scriptCode == 'Latn' ? const Locale('en') : locale;

  @override
  bool isSupported(Locale locale) => _inner.isSupported(resolve(locale));

  @override
  Future<T> load(Locale locale) => _inner.load(resolve(locale));

  // A locale change reloads Localizations on its own; the delegate itself
  // never changes, so forcing a reload here would just re-run the async load
  // on every rebuild.
  @override
  bool shouldReload(covariant LocalizationsDelegate<T> old) => false;
}
