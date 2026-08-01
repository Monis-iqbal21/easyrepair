import 'package:intl/intl.dart';

final NumberFormat _pkrNumberFormat = NumberFormat('#,##0', 'en_US');

/// Formats an amount as Pakistani Rupees — the app's only supported currency.
/// No decimals, comma thousands separator. e.g. `formatPkr(2000)` -> `"Rs 2,000"`.
///
/// Identical in English, Urdu and Roman Urdu on purpose: `Rs` and Latin digits
/// are an LTR island, so a price reads the same to everyone and never picks up
/// Urdu-Indic numerals. Pinned by `test/core/l10n/ltr_islands_test.dart`.
String formatPkr(num? amount) {
  // l10n-ignore: Currency LTR island — 'Rs' + Latin digits in every language
  return 'Rs ${_pkrNumberFormat.format(amount ?? 0)}';
}
