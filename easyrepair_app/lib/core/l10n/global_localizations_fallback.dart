import 'package:flutter/widgets.dart';

/// Resolves Roman Urdu (`ur_Latn`) to English before handing a locale to
/// Flutter's own `Global*Localizations` delegates.
///
/// Without this, `GlobalWidgetsLocalizations` picks text direction from the
/// language code alone — so `ur_Latn` would be forced RTL, which is wrong for
/// Latin script. Resolving to English means `Directionality.of(context)`
/// genuinely reports LTR rather than being patched over by a wrapper widget,
/// and Material's own strings ("Cancel", "Paste") stay in Latin script for
/// Roman Urdu users.
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
