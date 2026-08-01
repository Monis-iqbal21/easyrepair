/// Matching rules for finding the HandyGo Support conversation by search.
///
/// Deliberately matched ONLY against the alias list below — never against
/// arbitrary conversation text — so searching an Ustaad's name or a booking
/// reference can never surface Support.
library;

/// Words a user might plausibly type when looking for help, including the
/// common Roman Urdu terms. Typos are handled by [matchesSupport], so this
/// list holds intents, not misspellings.
const List<String> kSupportSearchAliases = <String>[
  'support',
  'suport',
  'soport',
  'saport',
  'handygo',
  'handy go',
  'handygo support',
  'help',
  'madad',
  'shikayat',
  'complaint',
  'masla',
];

/// Lowercases, drops everything that is not a letter or digit, and collapses a
/// run of the same character to one (`suuuport` → `suport`, `HANDY GO!` →
/// `handygo`).
String normalizeSupportQuery(String raw) {
  final lower = raw.toLowerCase();
  final buffer = StringBuffer();
  int? previous;
  for (final rune in lower.runes) {
    final isDigit = rune >= 0x30 && rune <= 0x39;
    final isLetter = rune >= 0x61 && rune <= 0x7a;
    if (!isDigit && !isLetter) continue;
    if (rune == previous) continue;
    buffer.writeCharCode(rune);
    previous = rune;
  }
  return buffer.toString();
}

/// Levenshtein distance, abandoned as soon as it is certain to exceed [max].
///
/// Bounding it is what keeps typo tolerance from becoming fuzzy-match-anything:
/// an unrelated query exits on the length check without doing any work.
int _boundedEditDistance(String a, String b, int max) {
  if ((a.length - b.length).abs() > max) return max + 1;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var previous = List<int>.generate(b.length + 1, (i) => i);
  var current = List<int>.filled(b.length + 1, 0);

  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    var rowMin = current[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final deletion = previous[j] + 1;
      final insertion = current[j - 1] + 1;
      final substitution = previous[j - 1] + cost;
      var best = deletion < insertion ? deletion : insertion;
      if (substitution < best) best = substitution;
      current[j] = best;
      if (best < rowMin) rowMin = best;
    }
    // Every remaining row can only add to the minimum, so once the whole row
    // is above the bound the final distance cannot come back under it.
    if (rowMin > max) return max + 1;
    final swap = previous;
    previous = current;
    current = swap;
  }
  return previous[b.length];
}

/// Whether a search query should surface the HandyGo Support conversation.
///
/// An empty query matches, so Support stays pinned when the box is untouched.
bool matchesSupport(String query) {
  final normalized = normalizeSupportQuery(query);
  if (normalized.isEmpty) return true;

  // A one- or two-character query is too weak a signal for edit distance —
  // at distance 2 it would match almost anything. Require a real prefix.
  final allowFuzzy = normalized.length >= 3;

  for (final alias in kSupportSearchAliases) {
    final target = normalizeSupportQuery(alias);
    if (target.isEmpty) continue;
    if (target.startsWith(normalized) || normalized.startsWith(target)) {
      return true;
    }
    if (allowFuzzy && _boundedEditDistance(normalized, target, 2) <= 2) {
      return true;
    }
  }
  return false;
}
