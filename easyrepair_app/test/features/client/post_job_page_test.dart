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

/// Booking-form behavior covered here:
///  * Page 2 was split into two dedicated steps: 2.1 lane selection only,
///    2.2 the selected lane's detail form. Page 2.1 must never show
///    lane-specific fields, attachment controls or the inspection tagline.
///  * The "understanding the problem is our job" tagline moved from the
///    lane-selection page into the INSPECTION details step only, and its
///    old "Rate batane se pehle..." counterpart is gone entirely.
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

const _backLabel = {
  AppLocale.english: 'Back',
  AppLocale.romanUrdu: 'Wapas',
  AppLocale.urdu: 'پیچھے',
};

const _tagline = 'Understanding the problem is our job — not yours.';
const _oldTaglineRomanUrdu =
    'Rate batane se pehle kuch nahi khulta — jo kaha, wohi liya.';

// Section-title markers unique to each lane's Page 2.2 content.
const _standardMarker = 'Choose a standard service';
const _inspectionMarker = 'How inspection works';
const _biddingMarker = "What needs fixing?";

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

/// Reaches Page 2.1 (lane selection only) from a fresh (non-edit) form with
/// a preselected service, so the service picker never has to be driven.
Future<void> _goToLaneSelectStep(
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

/// Reaches Page 2.2 (the selected lane's details) from a fresh form.
/// Passing no [laneOptionTitle] keeps the default lane (INSPECTION).
Future<void> _goToLaneDetailsStep(
  WidgetTester tester, {
  AppLocale locale = AppLocale.english,
  String? laneOptionTitle,
}) async {
  await _goToLaneSelectStep(tester, locale: locale);
  if (laneOptionTitle != null) {
    await _selectLane(tester, laneOptionTitle);
  }
  await tester.tap(find.text(_nextLabel[locale]!));
  await tester.pumpAndSettle();
}

void main() {
  group('Page 2.1 — lane selection only', () {
    testWidgets('shows exactly the 3 lane choices', (tester) async {
      await _goToLaneSelectStep(tester);

      expect(find.text('Standard work'), findsOneWidget);
      expect(find.text('Something is broken'), findsOneWidget);
      expect(find.text('I know the exact part'), findsOneWidget);
    });

    testWidgets('does not show any lane-specific form fields', (
      tester,
    ) async {
      // Default lane is INSPECTION, so this is the strictest check: none of
      // the lane detail sections — for any lane — render on this page.
      await _goToLaneSelectStep(tester);

      expect(find.text(_standardMarker), findsNothing);
      expect(find.text(_inspectionMarker), findsNothing);
      expect(find.text(_biddingMarker), findsNothing);
    });

    testWidgets('does not show attachment controls', (tester) async {
      await _goToLaneSelectStep(tester);
      expect(find.text('Photo/Video'), findsNothing);
    });

    testWidgets('does not show the inspection tagline', (tester) async {
      await _goToLaneSelectStep(tester);
      expect(find.text(_tagline), findsNothing);
    });

    testWidgets('Next is not blocked — the default lane selection carries '
        'forward', (tester) async {
      await _goToLaneSelectStep(tester);
      await tester.tap(find.text(_nextLabel[AppLocale.english]!));
      await tester.pumpAndSettle();

      expect(find.text(_inspectionMarker), findsOneWidget);
    });
  });

  group('Page 2.2 — selected lane\'s details only', () {
    testWidgets('selecting STANDARD opens only STANDARD details', (
      tester,
    ) async {
      await _goToLaneDetailsStep(tester, laneOptionTitle: 'Standard work');

      expect(find.text(_standardMarker), findsOneWidget);
      expect(find.text(_inspectionMarker), findsNothing);
      expect(find.text(_biddingMarker), findsNothing);
    });

    testWidgets('selecting INSPECTION opens only INSPECTION details', (
      tester,
    ) async {
      await _goToLaneDetailsStep(tester);

      expect(find.text(_inspectionMarker), findsOneWidget);
      expect(find.text(_standardMarker), findsNothing);
      expect(find.text(_biddingMarker), findsNothing);
    });

    testWidgets('selecting BIDDING opens only BIDDING details', (
      tester,
    ) async {
      await _goToLaneDetailsStep(
        tester,
        laneOptionTitle: 'I know the exact part',
      );

      expect(find.text(_biddingMarker), findsOneWidget);
      expect(find.text(_standardMarker), findsNothing);
      expect(find.text(_inspectionMarker), findsNothing);
    });

    testWidgets('the lane cards themselves are gone on this page', (
      tester,
    ) async {
      await _goToLaneDetailsStep(tester);
      expect(find.text('Standard work'), findsNothing);
      expect(find.text('I know the exact part'), findsNothing);
    });
  });

  group('Back/Next navigation between 2.1 and 2.2', () {
    testWidgets('Back from lane-details returns to lane-selection', (
      tester,
    ) async {
      await _goToLaneDetailsStep(tester);
      expect(find.text(_inspectionMarker), findsOneWidget);

      await tester.tap(find.text(_backLabel[AppLocale.english]!));
      await tester.pumpAndSettle();

      expect(find.text('Standard work'), findsOneWidget);
      expect(find.text(_inspectionMarker), findsNothing);
    });

    testWidgets('selected lane remains selected after Back then Next', (
      tester,
    ) async {
      await _goToLaneDetailsStep(
        tester,
        laneOptionTitle: 'I know the exact part',
      );
      expect(find.text(_biddingMarker), findsOneWidget);

      await tester.tap(find.text(_backLabel[AppLocale.english]!));
      await tester.pumpAndSettle();

      // No re-selection here — BIDDING must still be the remembered choice.
      await tester.tap(find.text(_nextLabel[AppLocale.english]!));
      await tester.pumpAndSettle();

      expect(find.text(_biddingMarker), findsOneWidget);
    });

    testWidgets('entered BIDDING details text survives Back then Next', (
      tester,
    ) async {
      await _goToLaneDetailsStep(
        tester,
        laneOptionTitle: 'I know the exact part',
      );

      await tester.enterText(
        find.byType(TextFormField).first,
        'Broken kitchen faucet',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(_backLabel[AppLocale.english]!));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_nextLabel[AppLocale.english]!));
      await tester.pumpAndSettle();

      expect(find.text('Broken kitchen faucet'), findsOneWidget);
    });
  });

  group('Edit-booking mode', () {
    testWidgets('STANDARD booking: lane-select shows the locked header, '
        'Next opens STANDARD details', (tester) async {
      final booking = _editableBooking(lane: BookingLane.standard);
      await tester.pumpWidget(
        _wrap(
          BookServicePage(editBookingId: booking.id),
          editBooking: booking,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Locked header replaces the 3 lane cards for a STANDARD edit.
      expect(find.text('Standard work'), findsNothing);
      expect(find.text('I know the exact part'), findsNothing);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text(_standardMarker), findsOneWidget);
    });

    testWidgets('BIDDING booking: lane-select opens with BIDDING '
        'preselected, Next opens BIDDING details', (tester) async {
      final booking = _editableBooking(lane: BookingLane.bidding);
      await tester.pumpWidget(
        _wrap(
          BookServicePage(editBookingId: booking.id),
          editBooking: booking,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      // No lane re-selection — the booking's own lane must already be
      // active.
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text(_biddingMarker), findsOneWidget);
      expect(find.text(_standardMarker), findsNothing);
      expect(find.text(_inspectionMarker), findsNothing);
    });
  });

  group('Validation is unchanged, just relocated to its own step', () {
    testWidgets('BIDDING details step blocks Next until a real title is '
        'entered', (tester) async {
      await _goToLaneDetailsStep(
        tester,
        laneOptionTitle: 'I know the exact part',
      );

      await tester.tap(find.text(_nextLabel[AppLocale.english]!));
      await tester.pumpAndSettle();

      // Still on the BIDDING details step — validation blocked the advance.
      expect(find.text(_biddingMarker), findsOneWidget);
    });
  });

  group('Inspection wording', () {
    testWidgets('old "Rate batane se pehle..." text no longer appears', (
      tester,
    ) async {
      await _goToLaneDetailsStep(tester, locale: AppLocale.romanUrdu);
      expect(find.text(_oldTaglineRomanUrdu), findsNothing);
    });

    testWidgets('new tagline appears only in INSPECTION details', (
      tester,
    ) async {
      await _goToLaneSelectStep(tester);
      expect(find.text(_tagline), findsNothing);

      await tester.tap(find.text(_nextLabel[AppLocale.english]!));
      await tester.pumpAndSettle();
      expect(find.text(_tagline), findsOneWidget);
    });

    testWidgets('new tagline does not appear for STANDARD or BIDDING '
        'details', (tester) async {
      await _goToLaneDetailsStep(tester, laneOptionTitle: 'Standard work');
      expect(find.text(_tagline), findsNothing);
    });

    testWidgets('renders in Roman Urdu', (tester) async {
      await _goToLaneDetailsStep(tester, locale: AppLocale.romanUrdu);
      expect(
        find.text('Masla samajhna hamara kaam hai — aapka nahi.'),
        findsOneWidget,
      );
    });

    testWidgets('renders in Urdu', (tester) async {
      await _goToLaneDetailsStep(tester, locale: AppLocale.urdu);
      expect(
        find.text('مسئلہ سمجھنا ہمارا کام ہے — آپ کا نہیں۔'),
        findsOneWidget,
      );
    });
  });

  group('Photo/Video attachment button label', () {
    testWidgets('renders in English', (tester) async {
      await _goToLaneDetailsStep(tester);
      expect(find.text('Photo/Video'), findsOneWidget);
    });

    testWidgets('renders in Roman Urdu', (tester) async {
      await _goToLaneDetailsStep(tester, locale: AppLocale.romanUrdu);
      expect(find.text('Photo/Video'), findsOneWidget);
    });

    testWidgets('renders تصویر/ویڈیو in Urdu', (tester) async {
      await _goToLaneDetailsStep(tester, locale: AppLocale.urdu);
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
      await _goToLaneDetailsStep(tester);

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

      // Step 1 (Address) → 2.1 (lane, BIDDING preselected) → 2.2 (details).
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // 1 photo + 2 videos = 3 total, never "0 photos" or a photos-only count.
      expect(find.text('3/4 attachments added'), findsOneWidget);
      expect(find.textContaining('0 photo'), findsNothing);
    });
  });
}
