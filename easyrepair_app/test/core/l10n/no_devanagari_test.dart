import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// HandyGo is a Pakistani application. Hindi written in Devanagari script
/// (U+0900–U+097F) must never reach a user — not in the UI, not in a
/// translation, not in agreement content, not in an error message.
///
/// Roman Urdu is Latin script, so a stray Devanagari character is always a
/// mistake rather than a style choice, which makes this cheap to enforce
/// absolutely.
final _devanagari = RegExp(r'[ऀ-ॿ]');

/// Reports every offending line so a failure names the exact place to fix.
List<String> _scan(File file, String label) {
  final offences = <String>[];
  final lines = file.readAsStringSync().split('\n');
  for (var i = 0; i < lines.length; i++) {
    final matches = _devanagari.allMatches(lines[i]);
    if (matches.isEmpty) continue;
    final chars = matches.map((m) => m.group(0)).toSet().join();
    offences.add('$label:${i + 1} contains Devanagari "$chars"');
  }
  return offences;
}

Iterable<File> _dartSources() sync* {
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) yield entity;
  }
}

void main() {
  test('no Flutter source file contains Devanagari', () {
    final offences = <String>[];
    for (final file in _dartSources()) {
      offences.addAll(_scan(file, file.path));
    }

    expect(
      offences,
      isEmpty,
      reason: 'Hindi/Devanagari found in Flutter source:\n${offences.join('\n')}',
    );
  });

  test('no ARB translation value contains Devanagari', () {
    // Checks the decoded VALUES rather than the raw file, so an escaped
    // क sequence is caught just as a literal character would be.
    final offences = <String>[];

    for (final name in ['app_en.arb', 'app_ur.arb', 'app_ur_Latn.arb']) {
      final decoded =
          jsonDecode(File('lib/l10n/$name').readAsStringSync()) as Map<String, dynamic>;

      for (final entry in decoded.entries) {
        if (entry.key.startsWith('@')) continue;
        final value = entry.value;
        if (value is! String) continue;
        if (_devanagari.hasMatch(value)) {
          final chars =
              _devanagari.allMatches(value).map((m) => m.group(0)).toSet().join();
          offences.add('$name → ${entry.key} contains Devanagari "$chars"');
        }
      }
    }

    expect(
      offences,
      isEmpty,
      reason: 'Hindi/Devanagari found in translations:\n${offences.join('\n')}',
    );
  });

  test('the Urdu ARB uses Arabic-script Urdu, not Devanagari', () {
    // Positive control: proves the scanner is looking at real Urdu content
    // and would have something to catch if the wrong script were used.
    final decoded =
        jsonDecode(File('lib/l10n/app_ur.arb').readAsStringSync()) as Map<String, dynamic>;
    final urduScript = RegExp(r'[؀-ۿ]');

    final withUrduScript = decoded.entries
        .where((e) => !e.key.startsWith('@') && e.value is String)
        .where((e) => urduScript.hasMatch(e.value as String))
        .length;

    expect(withUrduScript, greaterThan(100));
  });

  test('the scanner actually detects Devanagari', () {
    // A guard that never fires is worthless — prove it fires.
    expect(_devanagari.hasMatch('यह हिंदी है'), isTrue);
    expect(_devanagari.hasMatch('Yeh Roman Urdu hai'), isFalse);
    expect(_devanagari.hasMatch('یہ اردو ہے'), isFalse);
    expect(_devanagari.hasMatch('This is English'), isFalse);
  });
}
