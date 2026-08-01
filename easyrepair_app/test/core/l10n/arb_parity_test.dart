import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keys that are deliberately left untranslated.
///
/// `l10nFallbackProbe` exists only to prove the English-fallback path works —
/// see locale_switching_test.dart. Nothing else belongs here.
const _intentionallyUntranslated = {'l10nFallbackProbe'};

Map<String, String> _messages(String fileName) {
  final raw = File('lib/l10n/$fileName').readAsStringSync();
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  return {
    for (final entry in decoded.entries)
      // '@@locale' is metadata; '@key' entries are descriptions.
      if (!entry.key.startsWith('@')) entry.key: entry.value as String,
  };
}

void main() {
  late Map<String, String> en;
  late Map<String, String> ur;
  late Map<String, String> urLatn;

  setUpAll(() {
    en = _messages('app_en.arb');
    ur = _messages('app_ur.arb');
    urLatn = _messages('app_ur_Latn.arb');
  });

  test('every English key is translated into Urdu', () {
    final missing = en.keys
        .where((k) => !ur.containsKey(k))
        .where((k) => !_intentionallyUntranslated.contains(k))
        .toList();

    expect(missing, isEmpty, reason: 'Missing from app_ur.arb: $missing');
  });

  test('every English key is translated into Roman Urdu', () {
    // This one matters more than it looks: the generated
    // AppLocalizationsUrLatn extends AppLocalizationsUr, so a key present in
    // Urdu but missing here renders Urdu script on a left-to-right screen
    // rather than falling back to English.
    final missing = en.keys
        .where((k) => !urLatn.containsKey(k))
        .where((k) => !_intentionallyUntranslated.contains(k))
        .toList();

    expect(missing, isEmpty, reason: 'Missing from app_ur_Latn.arb: $missing');
  });

  test('a key present in Urdu is never absent from Roman Urdu', () {
    final leaks = ur.keys.where((k) => !urLatn.containsKey(k)).toList();

    expect(
      leaks,
      isEmpty,
      reason: 'These would render Urdu script inside Roman Urdu: $leaks',
    );
  });

  test('translated files contain no keys the template does not define', () {
    expect(ur.keys.where((k) => !en.containsKey(k)), isEmpty);
    expect(urLatn.keys.where((k) => !en.containsKey(k)), isEmpty);
  });

  test('no two English keys carry the same text', () {
    // Duplicate values mean two keys for one meaning — the thing that makes a
    // translation set drift out of sync over time.
    final byValue = <String, List<String>>{};
    for (final entry in en.entries) {
      byValue.putIfAbsent(entry.value, () => []).add(entry.key);
    }
    final duplicates = byValue.entries.where((e) => e.value.length > 1).toList();

    expect(
      duplicates,
      isEmpty,
      reason: 'Reuse one key instead: '
          '${duplicates.map((e) => '"${e.key}" → ${e.value}').join(', ')}',
    );
  });

  test('no translation is left empty', () {
    for (final (name, messages) in [
      ('app_en.arb', en),
      ('app_ur.arb', ur),
      ('app_ur_Latn.arb', urLatn),
    ]) {
      final blanks = messages.entries
          .where((e) => e.value.trim().isEmpty)
          .map((e) => e.key)
          .toList();
      expect(blanks, isEmpty, reason: 'Empty values in $name: $blanks');
    }
  });

  test('the HandyGo brand name is never translated', () {
    for (final (name, messages) in [('app_ur.arb', ur), ('app_ur_Latn.arb', urLatn)]) {
      for (final entry in en.entries) {
        if (!entry.value.contains('HandyGo')) continue;
        final translated = messages[entry.key];
        if (translated == null) continue;
        expect(
          translated,
          contains('HandyGo'),
          reason: '${entry.key} in $name dropped or transliterated the brand',
        );
      }
    }
  });

  test('placeholders survive translation', () {
    // A placeholder lost in translation is a runtime failure, not a typo.
    final placeholder = RegExp(r'\{(\w+)\}');
    for (final (name, messages) in [('app_ur.arb', ur), ('app_ur_Latn.arb', urLatn)]) {
      for (final entry in en.entries) {
        final expected =
            placeholder.allMatches(entry.value).map((m) => m.group(1)!).toSet();
        if (expected.isEmpty) continue;
        final translated = messages[entry.key];
        if (translated == null) continue;
        final actual =
            placeholder.allMatches(translated).map((m) => m.group(1)!).toSet();
        expect(
          actual,
          expected,
          reason: '${entry.key} in $name has mismatched placeholders',
        );
      }
    }
  });

  test('Urdu translations actually use Urdu script', () {
    final urduScript = RegExp(r'[؀-ۿ]');
    // A value made only of placeholders and punctuation (a date pattern, for
    // instance) is legitimately identical in every language.
    // Values built only from placeholders plus separators (a date pattern,
    // an id format, a "name xN" line) are legitimately identical everywhere.
    final placeholdersOnly = RegExp(
      r'^[\s\p{P}\p{S}\p{N}A-Za-z]*(\{\w+\}[\s\p{P}\p{S}\p{N}A-Za-z]*)+$',
      unicode: true,
    );
    final suspicious = <String>[];
    for (final entry in ur.entries) {
      if (placeholdersOnly.hasMatch(entry.value)) continue;
      // Latin-only values are fine for brand names and loanwords kept as-is,
      // but flag anything that is byte-identical to the English text.
      if (entry.value == en[entry.key] && !urduScript.hasMatch(entry.value)) {
        suspicious.add(entry.key);
      }
    }

    expect(
      suspicious,
      isEmpty,
      reason: 'Untranslated English left in app_ur.arb: $suspicious',
    );
  });

  test('Roman Urdu stays in Latin script', () {
    final urduScript = RegExp(r'[؀-ۿ]');
    final wrongScript = urLatn.entries
        .where((e) => urduScript.hasMatch(e.value))
        .map((e) => e.key)
        .toList();

    expect(
      wrongScript,
      isEmpty,
      reason: 'Urdu script found in the Roman Urdu file: $wrongScript',
    );
  });
}
