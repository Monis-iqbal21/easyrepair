import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

/// Shorthand for the generated localizations: `context.l10n.someKey`.
///
/// This is the only way widgets should reach translated text — no
/// language-based conditionals anywhere in the widget tree.
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
