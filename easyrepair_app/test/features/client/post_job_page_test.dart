import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/presentation/providers/booking_providers.dart';
import 'package:handygo_app/features/categories/domain/entities/service_category_entity.dart';
import 'package:handygo_app/features/categories/presentation/providers/categories_providers.dart';
import 'package:handygo_app/features/client/presentation/pages/post_job_page.dart';

import '../../support/l10n_test_app.dart';

/// Booking-form fixes covered here:
///  * The "understanding the problem is our job" tagline must only show for
///    the INSPECTION lane — it used to render for STANDARD and BIDDING too.
///  * The attachment button's "Photo/Video" label overflowed on narrow
///    screens because the Text inside it wasn't Flexible.
///  * The attachment helper/counter text implied "4 photos plus a video"
///    instead of one combined cap of 4 photos-or-videos.

const _category = ServiceCategoryEntity(
  id: 'cat-1',
  name: 'Electrician',
  inspectionFee: 500,
);

const _nextLabel = {
  AppLocale.english: 'Next',
  AppLocale.romanUrdu: 'Aage',
  AppLocale.urdu: 'آگے',
};

ProviderScope _wrap(
  Widget child, {
  AppLocale locale = AppLocale.english,
  BookingEntity? editBooking,
}) {
  return ProviderScope(
    overrides: [
      clientBookingCategoriesProvider.overrideWith(
        (ref) async => [_category],
      ),
      // Switching to STANDARD triggers this fetch — stub it so the test
      // never makes a real (never-resolving-in-test) network call.
      standardServicesProvider.overrideWith((ref, categoryId) async => []),
      if (editBooking != null)
        bookingDetailProvider.overrideWith(
          () => _FakeBookingDetailNotifier(editBooking),
        ),
    ],
    child: localizedApp(child, locale: locale),
  );
}

class _FakeBookingDetailNotifier extends BookingDetailNotifier {
  _FakeBookingDetailNotifier(this._booking);
  final BookingEntity _booking;

  @override
  Future<BookingEntity> build(String arg) async => _booking;
}

BookingEntity _editableBooking({
  required BookingLane lane,
  List<BookingAttachmentEntity> attachments = const [],
}) {
  return BookingEntity(
    id: 'booking-1',
    referenceId: '#HG-1',
    serviceCategory: 'Electrician',
    serviceEmoji: '⚡',
    status: BookingStatus.pending,
    urgency: BookingUrgency.normal,
    createdAt: DateTime(2026, 7, 1),
    lane: lane,
    address: 'House 1, Street 2, Lahore',
    attachments: attachments,
  );
}

/// Reaches Step 2 (lane + media section) from a fresh (non-edit) form with a
/// preselected service, so the service picker never has to be driven.
Future<void> _goToStep2(
  WidgetTester tester, {
  AppLocale locale = AppLocale.english,
}) async {
  await tester.pumpWidget(
    _wrap(
      const BookServicePage(preselectedService: 'Electrician'),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byType(TextFormField).first,
    'House 1, Street 2, Lahore',
  );
  await tester.tap(find.text(_nextLabel[locale]!));
  await tester.pumpAndSettle();
}

/// Switches lane by tapping the option's title and settling only the
/// state-driven rerender — never `pumpAndSettle()`, which would hang forever
/// once STANDARD triggers a real (unmocked, never-resolving in this test)
/// standard-services fetch behind a spinner.
Future<void> _selectLane(WidgetTester tester, String optionTitle) async {
  final finder = find.text(optionTitle);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  group('lane-selection tagline visibility', () {
    testWidgets('shown for INSPECTION (the default lane)', (tester) async {
      await _goToStep2(tester);

      expect(
        find.text('Understanding the problem is our job — not yours.'),
        findsOneWidget,
      );
    });

    testWidgets('hidden for STANDARD', (tester) async {
      await _goToStep2(tester);
      expect(
        find.text('Understanding the problem is our job — not yours.'),
        findsOneWidget,
      );

      await _selectLane(tester, 'Standard work');

      expect(
        find.text('Understanding the problem is our job — not yours.'),
        findsNothing,
      );
    });

    testWidgets('hidden for BIDDING', (tester) async {
      await _goToStep2(tester);

      await _selectLane(tester, 'I know the exact part');

      expect(
        find.text('Understanding the problem is our job — not yours.'),
        findsNothing,
      );
    });
  });

  group('Photo/Video attachment button label', () {
    testWidgets('renders in English', (tester) async {
      await _goToStep2(tester);
      expect(find.text('Photo/Video'), findsOneWidget);
    });

    testWidgets('renders in Roman Urdu', (tester) async {
      await _goToStep2(tester, locale: AppLocale.romanUrdu);
      expect(find.text('Photo/Video'), findsOneWidget);
    });

    testWidgets('renders تصویر/ویڈیو in Urdu', (tester) async {
      await _goToStep2(tester, locale: AppLocale.urdu);
      expect(find.text('تصویر/ویڈیو'), findsOneWidget);
    });

    testWidgets(
      'no overflow on a small Android screen, in every language',
      (tester) async {
        // Reproduces the exact shape _buildActionButton uses (Icon +
        // Flexible(Text, ellipsis) split half-width in a Row) at a
        // deliberately tight width — tighter than the pre-fix label ever
        // needed to overflow. Isolated from the full BookServicePage on
        // purpose: that page has its own, unrelated pre-existing overflow
        // bugs in its header/hero-card at small widths (out of scope here —
        // this task only covers the attachment button), which would
        // otherwise make `tester.takeException()` report the wrong cause.
        for (final label in [
          'Photo/Video', // English & Roman Urdu (identical)
          'تصویر/ویڈیو', // Urdu
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 90, // half of a ~180px-wide two-button row
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.attach_file_rounded, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: '"$label" overflowed the compact button layout',
          );
        }
      },
    );
  });

  group('attachment helper and live counter text', () {
    testWidgets('helper text mentions 30 seconds and maximum 4 attachments', (
      tester,
    ) async {
      await _goToStep2(tester);

      expect(
        find.text(
          'Add photos or a video up to 30 seconds. Maximum 4 attachments.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('counter counts mixed photo/video attachments toward 4', (
      tester,
    ) async {
      final booking = _editableBooking(
        lane: BookingLane.bidding,
        attachments: [
          BookingAttachmentEntity(
            id: 'a1',
            type: AttachmentType.image,
            url: 'https://example.test/1.jpg',
            createdAt: DateTime(2026, 7, 1),
          ),
          BookingAttachmentEntity(
            id: 'a2',
            type: AttachmentType.video,
            url: 'https://example.test/1.mp4',
            createdAt: DateTime(2026, 7, 1),
          ),
          BookingAttachmentEntity(
            id: 'a3',
            type: AttachmentType.video,
            url: 'https://example.test/2.mp4',
            createdAt: DateTime(2026, 7, 1),
          ),
        ],
      );

      await tester.pumpWidget(
        _wrap(
          BookServicePage(editBookingId: booking.id),
          editBooking: booking,
        ),
      );
      // Lets the postFrameCallback prefill run and the categories future
      // resolve before advancing the step.
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // 1 photo + 2 videos = 3 total, never "0 photos" or a photos-only count.
      expect(find.text('3/4 attachments added'), findsOneWidget);
      expect(find.textContaining('0 photo'), findsNothing);
    });
  });
}
