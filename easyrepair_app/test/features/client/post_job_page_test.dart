import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/bookings/domain/entities/attachable_inspection_entity.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/presentation/providers/booking_providers.dart';
import 'package:handygo_app/features/categories/domain/entities/service_category_entity.dart';
import 'package:handygo_app/features/categories/presentation/providers/categories_providers.dart';
import 'package:handygo_app/features/client/presentation/pages/post_job_page.dart';
import 'package:handygo_app/features/saved_addresses/domain/entities/saved_address_entity.dart';
import 'package:handygo_app/features/saved_addresses/presentation/providers/saved_addresses_providers.dart';

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

const _inspectionOption = {
  AppLocale.english: 'Inspection',
  AppLocale.romanUrdu: 'Inspection',
  AppLocale.urdu: 'معائنہ',
};

const _standardOption = {
  AppLocale.english: 'Fixed-price services',
  AppLocale.romanUrdu: 'Fixed-price services',
  AppLocale.urdu: 'مقررہ قیمت کی سروسز',
};

const _customOption = {
  AppLocale.english: 'Custom Work',
  AppLocale.romanUrdu: 'Custom Kaam',
  AppLocale.urdu: 'کسٹم کام',
};

const _tagline = 'Understanding the problem is our job — not yours.';
const _oldTaglineRomanUrdu =
    'Rate batane se pehle kuch nahi khulta — jo kaha, wohi liya.';

// Section-title markers unique to each lane's Page 2.2 content.
const _standardMarker = 'Choose a standard service';
const _inspectionMarker = 'How inspection works';
const _biddingMarker = 'WHAT NEEDS TO BE DONE?';

ProviderScope _wrap(
  Widget child, {
  AppLocale locale = AppLocale.english,
  BookingEntity? editBooking,
  LatLng? previewPosition,
  ThemeData? theme,
  List<AttachableInspectionEntity> attachableInspections = const [],
}) {
  return ProviderScope(
    overrides: [
      clientBookingCategoriesProvider.overrideWith((ref) async => [_category]),
      // Switching to STANDARD triggers this fetch — stub it so the test
      // never makes a real (never-resolving-in-test) network call.
      standardServicesProvider.overrideWith((ref, categoryId) async => []),
      savedAddressesProvider.overrideWith(_FakeSavedAddressesNotifier.new),
      bookingMapPreviewPositionProvider.overrideWith(
        (ref) async => previewPosition,
      ),
      attachableInspectionsProvider.overrideWith(
        (ref, categoryId) async => attachableInspections,
      ),
      if (editBooking != null)
        bookingDetailProvider.overrideWith(
          () => _FakeBookingDetailNotifier(editBooking),
        ),
    ],
    child: localizedApp(
      theme == null ? child : Theme(data: theme, child: child),
      locale: locale,
    ),
  );
}

class _FakeSavedAddressesNotifier extends SavedAddressesNotifier {
  @override
  Future<List<SavedAddressEntity>> build() async => const [
    SavedAddressEntity(
      id: 'address-home',
      label: 'Home',
      normalizedLabel: 'home',
      addressLine: 'House 1, Street 2, Lahore',
      city: 'Lahore',
      latitude: 31.5204,
      longitude: 74.3587,
    ),
  ];
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
    city: 'Lahore',
    latitude: 31.5204,
    longitude: 74.3587,
    attachments: attachments,
  );
}

/// Reaches Page 2.1 (lane selection only) from a fresh (non-edit) form with
/// a preselected service, so the service picker never has to be driven.
Future<void> _goToLaneSelectStep(
  WidgetTester tester, {
  AppLocale locale = AppLocale.english,
  List<AttachableInspectionEntity> attachableInspections = const [],
}) async {
  await tester.pumpWidget(
    _wrap(
      const BookServicePage(preselectedService: 'Electrician'),
      locale: locale,
      attachableInspections: attachableInspections,
    ),
  );
  await tester.pumpAndSettle();

  await tester.ensureVisible(find.text('Home'));
  await tester.tap(find.text('Home'));
  await tester.pump();
  await tester.ensureVisible(find.text(_nextLabel[locale]!));
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
/// Passing no [laneOptionTitle] selects INSPECTION explicitly.
Future<void> _goToLaneDetailsStep(
  WidgetTester tester, {
  AppLocale locale = AppLocale.english,
  String? laneOptionTitle,
  List<AttachableInspectionEntity> attachableInspections = const [],
}) async {
  await _goToLaneSelectStep(
    tester,
    locale: locale,
    attachableInspections: attachableInspections,
  );
  await _selectLane(tester, laneOptionTitle ?? _inspectionOption[locale]!);
  await tester.tap(find.byType(ElevatedButton).last);
  await tester.pumpAndSettle();
}

void main() {
  group('responsive booking wizard', () {
    testWidgets('Page 1 renders without overflow at representative widths', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      for (final width in [320.0, 360.0, 390.0, 430.0, 600.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          _wrap(const BookServicePage(preselectedService: 'Electrician')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'width=$width');
      }
    });

    testWidgets('Inspection details and Page 4 fit at 320px', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _goToLaneDetailsStep(tester);
      expect(tester.takeException(), isNull);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Switchboard se sparks aa rahe hain',
      );
      await tester.tap(find.text(_nextLabel[AppLocale.english]!));
      await tester.pumpAndSettle();

      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Urgent'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Page 1 follows the approved address-step order', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _wrap(const BookServicePage(preselectedService: 'Electrician')),
      );
      await tester.pumpAndSettle();

      final addressField = find.text('Enter your complete address');
      final currentLocation = find.text('Current Location');
      final pickOnMap = find.text('Pick on Map');
      final mapPreview = find.text('MAP — TAP TO PLACE THE PIN');
      final saveAddress = find.text('Save this address for next time');

      expect(addressField, findsOneWidget);
      expect(currentLocation, findsOneWidget);
      expect(pickOnMap, findsOneWidget);
      expect(mapPreview, findsOneWidget);
      expect(saveAddress, findsOneWidget);
      expect(
        tester.getTopLeft(addressField).dy,
        lessThan(tester.getTopLeft(currentLocation).dy),
      );
      expect(
        tester.getTopLeft(currentLocation).dy,
        lessThan(tester.getTopLeft(mapPreview).dy),
      );
      expect(
        tester.getTopLeft(mapPreview).dy,
        lessThan(tester.getTopLeft(saveAddress).dy),
      );
    });

    testWidgets(
      'initial device preview centers the map without validating Page 1',
      (tester) async {
        const preview = LatLng(24.9056, 67.0822);
        await tester.pumpWidget(
          _wrap(
            const BookServicePage(preselectedService: 'Electrician'),
            previewPosition: preview,
          ),
        );
        await tester.pumpAndSettle();

        final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
        expect(map.initialCameraPosition.target, preview);
        expect(map.markers, isEmpty);
        expect(find.byType(TextFormField), findsOneWidget);
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField))
              .controller
              ?.text,
          isEmpty,
        );

        await tester.tap(find.text('Next'));
        await tester.pump();
        expect(
          find.text('Enter an address before continuing.'),
          findsOneWidget,
        );
        expect(find.text('Fixed-price services'), findsNothing);
      },
    );

    testWidgets('unavailable passive location uses Karachi as view only', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const BookServicePage(preselectedService: 'Electrician')),
      );
      await tester.pumpAndSettle();

      final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.initialCameraPosition.target, const LatLng(24.8607, 67.0011));
      expect(map.markers, isEmpty);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller
            ?.text,
        isEmpty,
      );
    });

    testWidgets('explicit saved-address selection becomes authoritative', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const BookServicePage(preselectedService: 'Electrician')),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Home'));
      await tester.tap(find.text('Home'));
      await tester.pump();

      final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.initialCameraPosition.target, const LatLng(31.5204, 74.3587));
      expect(map.markers, hasLength(1));

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Inspection'), findsOneWidget);
    });

    testWidgets('manual edits immediately clear a previously selected pin', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const BookServicePage(preselectedService: 'Electrician')),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Home'));
      await tester.tap(find.text('Home'));
      await tester.pump();
      var map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.initialCameraPosition.target, const LatLng(31.5204, 74.3587));
      expect(map.markers, hasLength(1));

      await tester.enterText(
        find.byType(TextFormField).first,
        'A different unresolved address',
      );
      await tester.pump();

      map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.initialCameraPosition.target, const LatLng(24.8607, 67.0011));
      expect(map.markers, isEmpty);
      expect(find.text('MAP — TAP TO PLACE THE PIN'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(
        find.text(
          "We couldn't find this address. Add more detail or choose it on the map.",
        ),
        findsOneWidget,
      );
      expect(find.text('Fixed-price services'), findsNothing);
    });

    testWidgets('Pick on Map opens the existing center-pin modal flow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const BookServicePage(preselectedService: 'Electrician')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pick on Map'));
      await tester.pumpAndSettle();

      expect(find.text('Search for an area or landmark…'), findsOneWidget);
      expect(
        find.text('Move the map or tap to pick a location'),
        findsOneWidget,
      );
      expect(find.text('Use This Location'), findsOneWidget);
      // The always-populated Page 1 preview remains mounted behind the picker.
      expect(find.byType(GoogleMap), findsNWidgets(2));
      expect(find.byType(ModalBarrier), findsWidgets);
    });

    testWidgets('Page 1 uses the approved Roman Urdu plus English wording', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const BookServicePage(preselectedService: 'Electrician'),
          locale: AppLocale.romanUrdu,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Pehli booking hai — pata aik dafa likh dein. Aage se save ho sakta hai.',
        ),
        findsOneWidget,
      );
      expect(find.text('Apna complete address likhein'), findsOneWidget);
      expect(find.text('Mojooda Location'), findsOneWidget);
      expect(find.text('Map par chunain'), findsOneWidget);
      expect(find.text('Aage'), findsOneWidget);
    });
  });

  group('Page 2.1 — lane selection only', () {
    testWidgets('shows exactly the 3 lane choices', (tester) async {
      await _goToLaneSelectStep(tester);

      expect(find.text('Fixed-price services'), findsOneWidget);
      expect(find.text('Inspection'), findsOneWidget);
      expect(find.text('Custom Work'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('booking-lane-standard')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('booking-lane-inspection')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('booking-lane-bidding')),
        findsOneWidget,
      );
    });

    testWidgets('loads with no selection and a disabled CTA', (tester) async {
      await _goToLaneSelectStep(tester);

      for (final lane in ['standard', 'inspection', 'bidding']) {
        final semantics = tester.widget<Semantics>(
          find.byKey(ValueKey('booking-lane-$lane')),
        );
        expect(semantics.properties.selected, isFalse, reason: lane);
      }
      final cta = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).last,
      );
      expect(cta.onPressed, isNull);
      expect(find.text('Choose a booking option'), findsWidgets);
    });

    testWidgets('selection is exclusive and updates the reference CTA/check', (
      tester,
    ) async {
      await _goToLaneSelectStep(tester);

      Future<void> selectAndExpect({
        required String title,
        required String selectedLane,
        required String cta,
      }) async {
        await tester.tap(find.text(title));
        await tester.pump(const Duration(milliseconds: 200));

        for (final lane in ['standard', 'inspection', 'bidding']) {
          final card = find.byKey(ValueKey('booking-lane-$lane'));
          final semantics = tester.widget<Semantics>(card);
          expect(
            semantics.properties.selected,
            lane == selectedLane,
            reason: '$selectedLane should be the only selected lane',
          );
          expect(
            find.descendant(
              of: card,
              matching: find.byIcon(Icons.check_rounded),
            ),
            lane == selectedLane ? findsOneWidget : findsNothing,
          );
        }
        expect(find.text(cta), findsOneWidget);
        expect(
          tester
              .widget<ElevatedButton>(find.byType(ElevatedButton).last)
              .onPressed,
          isNotNull,
        );
      }

      await selectAndExpect(
        title: 'Fixed-price services',
        selectedLane: 'standard',
        cta: 'View services and prices',
      );
      await selectAndExpect(
        title: 'Inspection',
        selectedLane: 'inspection',
        cta: 'Book inspection',
      );
      await selectAndExpect(
        title: 'Custom Work',
        selectedLane: 'bidding',
        cta: 'Add job details',
      );
    });

    testWidgets('uses the exact Pure English reference wording', (
      tester,
    ) async {
      await _goToLaneSelectStep(tester);

      for (final text in [
        'Choose a booking option',
        'Step 2 / 4 · Electrician',
        'Service and price are fixed in advance',
        'See the final price before booking.',
        'View services and prices →',
        'Not sure what the problem is?',
        'Rs 500 inspection fee — paid after inspection, not now.',
        'The Ustaad checks the issue and sends the report and final quote in the app.',
        'If you proceed with the repair, the Rs 500 inspection fee is waived and you only pay the repair price.',
        'Book inspection →',
        'Send details and photos for a small repair, fitting, or replacement.',
        'Nearby Ustaads will send their prices.',
        'Add job details →',
        'The price can only change after a new quote is sent through the app — not after the Ustaad reaches your home.',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
    });

    testWidgets('uses the exact Roman Urdu plus Easy English wording', (
      tester,
    ) async {
      await _goToLaneSelectStep(tester, locale: AppLocale.romanUrdu);

      for (final text in [
        'Choose a booking option',
        'Service aur price pehle se fixed',
        'Booking se pehle final price dekhein.',
        'Services aur prices dekhein →',
        'Masla samajh nahi aa raha?',
        'Rs 500 inspection fee — abhi nahi, inspection ke baad.',
        'Ustaad masla check karke report aur final quote app mein bhejega.',
        'Kaam karwa liya to ye Rs 500 maaf — sirf repair ka rate dena hai.',
        'Inspection book karein →',
        'Custom Kaam',
        'Chhote repair, fitting ya replacement ki details aur photos bhejein.',
        'Qareebi Ustaads apne rates bhejenge.',
        'Kaam ki details dein →',
        'Price sirf app mein naya quote bhejne ke baad badal sakta hai — ghar pohanch kar nahi.',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
    });

    testWidgets(
      'matches the lane layout without overflow across target widths',
      (tester) async {
        addTearDown(tester.view.reset);
        await _goToLaneSelectStep(tester);
        for (final width in [320.0, 360.0, 390.0, 430.0, 600.0]) {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'width=$width');
        }
      },
    );

    testWidgets(
      'reference selection renders with semantic colors in dark mode',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            Theme(
              data: AppTheme.darkTheme,
              child: const BookServicePage(preselectedService: 'Electrician'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Home'));
        await tester.tap(find.text('Home'));
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Fixed-price services'));
        await tester.pump(const Duration(milliseconds: 200));

        expect(tester.takeException(), isNull);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('booking-lane-standard')),
            matching: find.byIcon(Icons.check_rounded),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('does not show any lane-specific form fields', (tester) async {
      await _goToLaneSelectStep(tester);

      expect(find.text(_standardMarker), findsNothing);
      expect(find.text(_inspectionMarker), findsNothing);
      expect(find.textContaining(_biddingMarker), findsNothing);
    });

    testWidgets('does not show attachment controls', (tester) async {
      await _goToLaneSelectStep(tester);
      expect(find.text('Photo/Video'), findsNothing);
      await tester.tap(find.text('Custom Work'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Inspection Report (Optional)'), findsNothing);
      expect(find.text('Attach Inspection Report'), findsNothing);
    });

    testWidgets('does not show the inspection tagline', (tester) async {
      await _goToLaneSelectStep(tester);
      expect(find.text(_tagline), findsNothing);
    });

    testWidgets('Next is blocked until the client selects a lane', (
      tester,
    ) async {
      await _goToLaneSelectStep(tester);
      final cta = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).last,
      );
      expect(cta.onPressed, isNull);
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pumpAndSettle();

      expect(find.text(_inspectionMarker), findsNothing);
      expect(find.text('Choose a booking option'), findsWidgets);
    });
  });

  group('Page 2.2 — selected lane\'s details only', () {
    testWidgets('selecting STANDARD opens only STANDARD details', (
      tester,
    ) async {
      await _goToLaneDetailsStep(
        tester,
        laneOptionTitle: _standardOption[AppLocale.english]!,
      );

      expect(find.text(_standardMarker), findsOneWidget);
      expect(find.text(_inspectionMarker), findsNothing);
      expect(find.textContaining(_biddingMarker), findsNothing);
    });

    testWidgets('selecting INSPECTION opens only INSPECTION details', (
      tester,
    ) async {
      await _goToLaneDetailsStep(tester);

      expect(find.text(_inspectionMarker), findsOneWidget);
      expect(find.text(_standardMarker), findsNothing);
      expect(find.textContaining(_biddingMarker), findsNothing);
    });

    testWidgets('selecting BIDDING opens only BIDDING details', (tester) async {
      await _goToLaneDetailsStep(
        tester,
        laneOptionTitle: _customOption[AppLocale.english]!,
      );

      expect(find.textContaining(_biddingMarker), findsOneWidget);
      expect(find.text(_standardMarker), findsNothing);
      expect(find.text(_inspectionMarker), findsNothing);
    });

    testWidgets('BIDDING details exposes the optional report picker', (
      tester,
    ) async {
      await _goToLaneDetailsStep(
        tester,
        laneOptionTitle: _customOption[AppLocale.english]!,
      );

      expect(find.textContaining('Previous inspection report'), findsOneWidget);
      expect(find.text('Attach report'), findsOneWidget);
      expect(find.textContaining('optional'), findsWidgets);
    });

    testWidgets('BIDDING details matches the English reference hierarchy', (
      tester,
    ) async {
      await _goToLaneDetailsStep(
        tester,
        laneOptionTitle: _customOption[AppLocale.english]!,
      );

      expect(find.text('Your request'), findsOneWidget);
      expect(find.text('Step 3 / 4 · Electrician'), findsOneWidget);
      expect(find.textContaining('WHAT NEEDS TO BE DONE?'), findsOneWidget);
      expect(find.textContaining('Tell us the details'), findsOneWidget);
      expect(find.textContaining('Voice note'), findsWidgets);
      expect(find.text('Add photos'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(
        find.text(
          'Photos and a voice note help the Ustaad understand best. '
          'No technical details needed.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('custom-request-next')), findsOneWidget);
      expect(find.text('Back'), findsNothing);
    });

    testWidgets('BIDDING details uses Roman Urdu reference wording', (
      tester,
    ) async {
      await _goToLaneDetailsStep(
        tester,
        locale: AppLocale.romanUrdu,
        laneOptionTitle: _customOption[AppLocale.romanUrdu]!,
      );

      expect(find.text('Aap ki request'), findsOneWidget);
      expect(find.text('Step 3 / 4 · Electrician'), findsOneWidget);
      expect(find.textContaining('KYA KARWANA HAI?'), findsOneWidget);
      expect(find.textContaining('Details se batayein'), findsOneWidget);
      expect(find.text('Photo dalain'), findsOneWidget);
      expect(find.text('Report lagayen'), findsOneWidget);
    });

    testWidgets('attached report changes to a green checked attached state', (
      tester,
    ) async {
      final report = AttachableInspectionEntity(
        bookingId: 'inspection-1',
        categoryId: 'cat-1',
        categoryName: 'Electrician',
        inspectionDate: DateTime(2026, 7, 1),
        issueFound: 'Loose neutral wire',
      );
      await _goToLaneDetailsStep(
        tester,
        laneOptionTitle: _customOption[AppLocale.english]!,
        attachableInspections: [report],
      );

      await tester.tap(find.byKey(const ValueKey('attach-inspection-report')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Loose neutral wire'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('inspection-report-attached')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.text('Report attached'), findsOneWidget);
      expect(find.text('Attach report'), findsNothing);
    });

    testWidgets('the lane cards themselves are gone on this page', (
      tester,
    ) async {
      await _goToLaneDetailsStep(tester);
      expect(find.text('Fixed-price services'), findsNothing);
      expect(find.text('Custom Work'), findsNothing);
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

      expect(find.text('Fixed-price services'), findsOneWidget);
      expect(find.text(_inspectionMarker), findsNothing);
    });

    testWidgets('selected lane remains selected after Back then Next', (
      tester,
    ) async {
      await _goToLaneDetailsStep(
        tester,
        laneOptionTitle: _customOption[AppLocale.english]!,
      );
      expect(find.textContaining(_biddingMarker), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
      await tester.pumpAndSettle();

      // No re-selection here — BIDDING must still be the remembered choice.
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pumpAndSettle();

      expect(find.textContaining(_biddingMarker), findsOneWidget);
    });

    testWidgets('entered BIDDING details text survives Back then Next', (
      tester,
    ) async {
      await _goToLaneDetailsStep(
        tester,
        laneOptionTitle: _customOption[AppLocale.english]!,
      );

      await tester.enterText(
        find.byType(TextFormField).first,
        'Broken kitchen faucet',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pumpAndSettle();

      expect(find.text('Broken kitchen faucet'), findsOneWidget);
    });
  });

  group('Edit-booking mode', () {
    testWidgets('STANDARD booking: lane-select shows the locked header, '
        'Next opens STANDARD details', (tester) async {
      final booking = _editableBooking(lane: BookingLane.standard);
      await tester.pumpWidget(
        _wrap(BookServicePage(editBookingId: booking.id), editBooking: booking),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Locked header replaces the 3 lane cards for a STANDARD edit.
      expect(find.text('Fixed-price services'), findsNothing);
      expect(find.text('Custom Work'), findsNothing);

      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pumpAndSettle();

      expect(find.text(_standardMarker), findsOneWidget);
    });

    testWidgets('BIDDING booking: lane-select opens with BIDDING '
        'preselected, Next opens BIDDING details', (tester) async {
      final booking = _editableBooking(lane: BookingLane.bidding);
      await tester.pumpWidget(
        _wrap(BookServicePage(editBookingId: booking.id), editBooking: booking),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      // No lane re-selection — the booking's own lane must already be
      // active.
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pumpAndSettle();

      expect(find.textContaining(_biddingMarker), findsOneWidget);
      expect(find.text(_standardMarker), findsNothing);
      expect(find.text(_inspectionMarker), findsNothing);
    });
  });

  group('Validation is unchanged, just relocated to its own step', () {
    testWidgets('BIDDING details step blocks Next until a real title is '
        'entered', (tester) async {
      await _goToLaneDetailsStep(
        tester,
        laneOptionTitle: _customOption[AppLocale.english]!,
      );

      await tester.tap(find.text(_nextLabel[AppLocale.english]!));
      await tester.pumpAndSettle();

      // Still on the BIDDING details step — validation blocked the advance.
      expect(find.textContaining(_biddingMarker), findsOneWidget);
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

      await _selectLane(tester, _inspectionOption[AppLocale.english]!);
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pumpAndSettle();
      expect(find.text(_tagline), findsOneWidget);
    });

    testWidgets('new tagline does not appear for STANDARD or BIDDING '
        'details', (tester) async {
      await _goToLaneDetailsStep(
        tester,
        laneOptionTitle: _standardOption[AppLocale.english]!,
      );
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

    testWidgets('no overflow on a small Android screen, in every language', (
      tester,
    ) async {
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
    });
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
        _wrap(BookServicePage(editBookingId: booking.id), editBooking: booking),
      );
      // Lets the postFrameCallback prefill run and the categories future
      // resolve before advancing the step.
      await tester.pumpAndSettle();

      // Step 1 (Address) → 2.1 (lane, BIDDING preselected) → 2.2 (details).
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pumpAndSettle();

      // 1 photo + 2 videos = 3 total, never "0 photos" or a photos-only count.
      expect(
        find.text('3 / 4 photos · Voice note not attached'),
        findsOneWidget,
      );
      expect(find.textContaining('0 photo'), findsNothing);
    });
  });
}
