import 'package:intl/intl.dart';

final NumberFormat _pkrNumberFormat = NumberFormat('#,##0', 'en_US');

/// Formats an amount as Pakistani Rupees — the app's only supported currency.
/// No decimals, comma thousands separator. e.g. `formatPkr(2000)` -> `"Rs 2,000"`.
String formatPkr(num? amount) {
  return 'Rs ${_pkrNumberFormat.format(amount ?? 0)}';
}
