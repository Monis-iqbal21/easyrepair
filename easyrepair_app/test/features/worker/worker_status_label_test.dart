import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/features/worker/presentation/utils/worker_status_labels.dart';
import 'package:handygo_app/l10n/app_localizations.dart';

/// A booking whose status is ACCEPTED has been *assigned* to the Ustaad,
/// whichever lane it arrived through. The Home dashboard's Active Job card
/// used to carry its own copy of this mapping and said "Accepted" for
/// standard and bid jobs while every other screen said "Assigned"; it now
/// shares this helper, so the wording cannot differ per screen again.
Future<AppLocalizations> _l10n(AppLocale locale) =>
    AppLocalizations.delegate.load(locale.locale);

void main() {
  test('ACCEPTED reads as "Assigned", not "Accepted"', () async {
    final l10n = await _l10n(AppLocale.english);

    expect(ongoingJobStatusLabel(l10n, 'ACCEPTED'), 'Assigned');
  });

  test('the label is lane-agnostic — it is derived from status alone', () async {
    // The helper takes no lane, which is what makes a direct standard hire,
    // an inspection assignment and an accepted bid impossible to word
    // differently from one another.
    final l10n = await _l10n(AppLocale.english);
    final label = ongoingJobStatusLabel(l10n, 'ACCEPTED');

    expect(label, isNot(contains('Accepted')));
    expect(label, ongoingJobStatusLabel(l10n, 'accepted'));
  });

  test('the other live statuses keep their own wording', () async {
    final l10n = await _l10n(AppLocale.english);

    expect(ongoingJobStatusLabel(l10n, 'EN_ROUTE'), isNot('Assigned'));
    expect(ongoingJobStatusLabel(l10n, 'IN_PROGRESS'), isNot('Assigned'));
  });

  test('an unknown backend token is echoed, never machine-translated', () async {
    final l10n = await _l10n(AppLocale.english);

    expect(ongoingJobStatusLabel(l10n, 'SOME_NEW_STATUS'), 'SOME_NEW_STATUS');
  });

  test('every language has a real translation for it', () async {
    for (final locale in AppLocale.values) {
      final label = ongoingJobStatusLabel(await _l10n(locale), 'ACCEPTED');
      expect(label.trim(), isNotEmpty, reason: locale.storageValue);
    }

    // Urdu genuinely differs from English rather than falling through.
    expect(
      ongoingJobStatusLabel(await _l10n(AppLocale.urdu), 'ACCEPTED'),
      isNot(ongoingJobStatusLabel(await _l10n(AppLocale.english), 'ACCEPTED')),
    );
  });
}
