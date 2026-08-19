import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/l10n/l10n_extensions.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/presentation/utils/status_labels.dart';
import 'package:handygo_app/features/bookings/presentation/widgets/status_badge.dart';
import 'package:handygo_app/l10n/app_localizations.dart';

import '../../support/l10n_test_app.dart';

/// Resolves [AppLocalizations] for a locale without needing a running app.
Future<AppLocalizations> _l10nFor(
  WidgetTester tester,
  AppLocale locale,
) async {
  late AppLocalizations resolved;
  await tester.pumpWidget(
    localizedApp(
      Builder(
        builder: (context) {
          resolved = context.l10n;
          return const SizedBox.shrink();
        },
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
  return resolved;
}

void main() {
  group('booking and job status labels', () {
    testWidgets('every status has a label in all three languages', (
      tester,
    ) async {
      for (final locale in AppLocale.values) {
        final l10n = await _l10nFor(tester, locale);
        for (final status in BookingStatus.values) {
          expect(
            bookingStatusLabel(l10n, status).trim(),
            isNotEmpty,
            reason: '$status has no client label in ${locale.storageValue}',
          );
          expect(
            workerJobStatusLabel(l10n, status).trim(),
            isNotEmpty,
            reason: '$status has no Ustaad label in ${locale.storageValue}',
          );
        }
      }
    });

    testWidgets('labels actually differ between languages', (tester) async {
      final en = await _l10nFor(tester, AppLocale.english);
      final ur = await _l10nFor(tester, AppLocale.urdu);
      final latn = await _l10nFor(tester, AppLocale.romanUrdu);

      expect(bookingStatusLabel(en, BookingStatus.pending), 'Live');
      expect(bookingStatusLabel(ur, BookingStatus.pending), 'جاری');
      expect(bookingStatusLabel(latn, BookingStatus.pending), 'Jaari');
    });

    testWidgets('the several assigned-ish states collapse to one client label',
        (tester) async {
      final l10n = await _l10nFor(tester, AppLocale.english);

      for (final status in [
        BookingStatus.accepted,
        BookingStatus.enRoute,
        BookingStatus.arrived,
      ]) {
        expect(bookingStatusLabel(l10n, status), 'Assigned');
      }
      // The Ustaad still sees the full lifecycle.
      expect(workerJobStatusLabel(l10n, BookingStatus.enRoute), 'En Route');
      expect(workerJobStatusLabel(l10n, BookingStatus.arrived), 'Arrived');
    });

    testWidgets('a new job nobody has taken reads as Live, not Pending', (
      tester,
    ) async {
      final l10n = await _l10nFor(tester, AppLocale.english);

      expect(
        newJobStatusLabel(l10n, BookingStatus.pending,
            hasAssignedWorker: false),
        'Live',
      );
      expect(
        newJobStatusLabel(l10n, BookingStatus.pending, hasAssignedWorker: true),
        'Pending',
      );
    });

    test('the backend contract is untouched by localization', () {
      // These strings go into API requests — translating one would break the
      // backend, so they must stay exactly as the server defines them.
      expect(BookingStatus.pending.raw, 'PENDING');
      expect(BookingStatus.enRoute.raw, 'EN_ROUTE');
      expect(BookingStatus.inProgress.raw, 'IN_PROGRESS');
      expect(BookingStatus.completed.raw, 'COMPLETED');
      expect(BookingStatus.cancelled.raw, 'CANCELLED');
    });

    testWidgets('StatusBadge renders the localized label', (tester) async {
      for (final (locale, expected) in [
        (AppLocale.english, 'Completed'),
        (AppLocale.urdu, 'مکمل'),
        (AppLocale.romanUrdu, 'Mukammal'),
      ]) {
        await tester.pumpWidget(
          localizedApp(
            const Scaffold(
              body: StatusBadge(status: BookingStatus.completed),
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(expected), findsOneWidget);
      }
    });
  });

  group('user-entered and backend content is never translated', () {
    // Names, addresses, phone numbers and free text belong to the user. They
    // must be byte-identical whatever language the interface is in.
    const ustaadName = 'Ali Raza';
    const address = 'House 12, Street 4, Gulshan-e-Iqbal, Karachi';
    const phone = '+923001234567';
    const clientNote = 'AC thanda nahi kar raha, gas leak lag rahi hai';
    const price = 'Rs 2,500';

    testWidgets('the same values render in English, Urdu and Roman Urdu', (
      tester,
    ) async {
      for (final locale in AppLocale.values) {
        await tester.pumpWidget(
          localizedApp(
            const Scaffold(
              body: Column(
                children: [
                  Text(ustaadName),
                  Text(address),
                  Text(phone),
                  Text(clientNote),
                  Text(price),
                ],
              ),
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();

        for (final value in [ustaadName, address, phone, clientNote, price]) {
          expect(
            find.text(value),
            findsOneWidget,
            reason: '"$value" changed in ${locale.storageValue}',
          );
        }
      }
    });

    testWidgets('a name interpolated into a translated sentence survives '
        'intact', (tester) async {
      for (final locale in AppLocale.values) {
        final l10n = await _l10nFor(tester, locale);
        expect(l10n.authWelcomeToastTitle(ustaadName), contains(ustaadName));
      }
    });
  });

  group('validation messages are translated', () {
    testWidgets('the auth validators differ per language and are never blank', (
      tester,
    ) async {
      final messages = <String, List<String>>{};
      for (final locale in AppLocale.values) {
        final l10n = await _l10nFor(tester, locale);
        messages[locale.storageValue] = [
          l10n.authValidationNameRequired,
          l10n.authValidationPhoneRequired,
          l10n.authValidationPhoneInvalid,
          l10n.authValidationPasswordRequired,
          l10n.authValidationPasswordTooShort,
          l10n.authValidationPasswordsDoNotMatch,
        ];
      }

      for (final entry in messages.entries) {
        for (final message in entry.value) {
          expect(message.trim(), isNotEmpty);
        }
      }
      expect(messages['ur'], isNot(messages['en']));
      expect(messages['ur_Latn'], isNot(messages['en']));
      expect(messages['ur_Latn'], isNot(messages['ur']));
    });
  });

  group('the HandyGo brand survives every language', () {
    testWidgets('it is never transliterated', (tester) async {
      for (final locale in AppLocale.values) {
        final l10n = await _l10nFor(tester, locale);
        // authRoleQuestion deliberately no longer names the brand — the
        // approved role-selection copy is "Aap kya karna chahte hain?" /
        // "What would you like to do?". authWorkerTypeQuestion is the
        // brand-carrying heading on the very next screen, so the probe moved
        // there rather than being dropped.
        expect(l10n.authWorkerTypeQuestion, contains('HandyGo'));
        expect(l10n.authWorkerTypeNewSubtitle, contains('HandyGo'));
        expect(l10n.chatSupportBanner, contains('HandyGo'));
      }
    });
  });
}
