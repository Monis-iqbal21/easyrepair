import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the CSV review pipeline (tool/translations_csv.py).
///
/// The CSV is what non-developers edit, so it has to stay in step with the ARB
/// files, and the sync script has to refuse anything that would corrupt them.
/// The rejection cases are exercised by driving the real script, not a mock —
/// a validator that is never run against bad input is not a validator.

const _csvPath = '../docs/handygo_translations.csv';
const _script = 'tool/translations_csv.py';

/// Naive CSV row splitter that honours quoted fields containing commas.
List<String> _splitRow(String line) {
  final fields = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char == ',' && !inQuotes) {
      fields.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  fields.add(buffer.toString());
  return fields;
}

List<List<String>> _readCsv() {
  var text = File(_csvPath).readAsStringSync();
  if (text.startsWith('﻿')) text = text.substring(1);
  // Fields may contain newlines inside quotes; join them back up.
  final rows = <List<String>>[];
  final buffer = StringBuffer();
  var quotes = 0;
  for (final line in const LineSplitter().convert(text)) {
    buffer.write(buffer.isEmpty ? line : '\n$line');
    quotes += '"'.allMatches(line).length;
    if (quotes.isEven) {
      rows.add(_splitRow(buffer.toString()));
      buffer.clear();
      quotes = 0;
    }
  }
  return rows;
}

Set<String> _arbKeys(String fileName) {
  final decoded = jsonDecode(File('lib/l10n/$fileName').readAsStringSync())
      as Map<String, dynamic>;
  return decoded.keys.where((k) => !k.startsWith('@')).toSet();
}

ProcessResult _run(List<String> args) {
  return Process.runSync(
    'python',
    [_script, ...args],
    environment: {'PYTHONIOENCODING': 'utf-8'},
  );
}

void main() {
  group('the review CSV mirrors the ARB files', () {
    late List<List<String>> rows;

    setUpAll(() {
      rows = _readCsv();
    });

    test('has the required columns in the documented order', () {
      expect(rows.first, [
        'Key',
        'Screen/Context',
        'English',
        'Urdu',
        'Roman Urdu',
        'Notes',
      ]);
    });

    test('contains every key from app_en.arb', () {
      final csvKeys = rows.skip(1).map((r) => r[0]).toSet();
      final missing = _arbKeys('app_en.arb').difference(csvKeys);

      expect(missing, isEmpty, reason: 'Missing from the CSV: $missing');
    });

    test('introduces no key the ARB does not define', () {
      final csvKeys = rows.skip(1).map((r) => r[0]).toSet();
      final extra = csvKeys.difference(_arbKeys('app_en.arb'));

      expect(extra, isEmpty, reason: 'Not in app_en.arb: $extra');
    });

    test('has no duplicate rows', () {
      final keys = rows.skip(1).map((r) => r[0]).toList();

      expect(keys.length, keys.toSet().length);
    });

    test('carries all three languages on one row', () {
      for (final row in rows.skip(1)) {
        final key = row[0];
        expect(row[2].trim(), isNotEmpty, reason: '$key has no English');
        if (key == 'l10nFallbackProbe') continue; // deliberately untranslated
        expect(row[3].trim(), isNotEmpty, reason: '$key has no Urdu');
        expect(row[4].trim(), isNotEmpty, reason: '$key has no Roman Urdu');
      }
    });

    test('includes the bottom-navigation labels so they can be reviewed', () {
      // The nav bars are translated (only their layout is pinned LTR — see
      // bottom_nav_protection_test.dart), so every key they read must be
      // editable by a reviewer here. Several tabs deliberately share a key
      // with the page they open, which is why this checks keys, not wording.
      const navKeys = {
        'navHome',
        'navBookings',
        'navChats',
        'clientProfileTitle',
        'clientJobsTitle',
        'workerNewJobsTitle',
        'chatTitleFallback',
      };
      final present = rows.skip(1).map((row) => row[0]).toSet();

      for (final key in navKeys) {
        expect(
          present,
          contains(key),
          reason: '$key is read by a bottom-nav tab and must be reviewable',
        );
      }
    });

    test('every row is tagged with a screen or feature', () {
      for (final row in rows.skip(1)) {
        expect(row[1].trim(), isNotEmpty, reason: '${row[0]} has no context');
      }
    });
  });

  group('the sync script validates before it writes', () {
    test('accepts the checked-in CSV', () {
      final result = _run(['validate']);

      expect(
        result.exitCode,
        0,
        reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
      );
      expect(result.stdout.toString(), contains('valid'));
    });

    // Each case corrupts a copy of the CSV, runs the real validator, restores
    // the original, then asserts the failure was caught.
    Future<void> expectRejected(
      String description,
      List<String> Function(List<String> lines) corrupt,
    ) async {
      final file = File(_csvPath);
      final original = file.readAsStringSync();
      try {
        final lines = const LineSplitter().convert(original);
        file.writeAsStringSync(corrupt(lines).join('\n'));
        final result = _run(['validate']);
        expect(
          result.exitCode,
          isNot(0),
          reason: '$description was NOT rejected',
        );
        expect(result.stdout.toString(), contains('VALIDATION FAILED'));
      } finally {
        file.writeAsStringSync(original);
      }
      // The ARB files must be untouched by a failed validation.
      expect(_run(['validate']).exitCode, 0);
    }

    test('rejects a duplicate key', () async {
      await expectRejected('a duplicate key', (lines) => [...lines, lines[1]]);
    });

    test('rejects a missing key', () async {
      await expectRejected(
        'a missing key',
        (lines) => [lines.first, ...lines.skip(2)],
      );
    });

    test('rejects an unknown key', () async {
      await expectRejected(
        'an unknown key',
        (lines) => [...lines, 'notARealKey,Shared,Hello,ہیلو,Hello,'],
      );
    });

    test('rejects a blank translation', () async {
      await expectRejected('a blank translation', (lines) {
        final index = lines.indexWhere((l) => l.startsWith('commonCancel,'));
        final fields = _splitRow(lines[index]);
        fields[3] = '';
        return [...lines]..[index] = fields.join(',');
      });
    });

    test('rejects a removed placeholder', () async {
      await expectRejected('a removed placeholder', (lines) {
        final index =
            lines.indexWhere((l) => l.startsWith('authWelcomeToastTitle,'));
        final fields = _splitRow(lines[index]);
        fields[3] = fields[3].replaceAll('{name}', '');
        return [...lines]..[index] = fields.join(',');
      });
    });

    test('rejects a renamed placeholder', () async {
      await expectRejected('a renamed placeholder', (lines) {
        final index =
            lines.indexWhere((l) => l.startsWith('authWelcomeToastTitle,'));
        final fields = _splitRow(lines[index]);
        fields[4] = fields[4].replaceAll('{name}', '{naam}');
        return [...lines]..[index] = fields.join(',');
      });
    });

    test('rejects malformed ICU syntax', () async {
      await expectRejected('malformed ICU', (lines) {
        final index =
            lines.indexWhere((l) => l.startsWith('workerRatingWithJobs,'));
        final fields = _splitRow(lines[index]);
        fields[3] = fields[3].replaceFirst('}', '');
        return [...lines]..[index] = fields.join(',');
      });
    });
  });
}
