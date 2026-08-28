import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/location/location_availability.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/bookings/domain/entities/attachable_inspection_entity.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/presentation/providers/booking_providers.dart';
import 'package:handygo_app/features/categories/domain/entities/service_category_entity.dart';
import 'package:handygo_app/features/categories/domain/entities/standard_service_entity.dart';
import 'package:handygo_app/features/categories/presentation/providers/categories_providers.dart';
import 'package:handygo_app/features/client/presentation/pages/post_job_page.dart';
import 'package:handygo_app/features/saved_addresses/domain/entities/saved_address_entity.dart';
import 'package:handygo_app/features/saved_addresses/presentation/providers/saved_addresses_providers.dart';

import '../../support/l10n_test_app.dart';

/// Booking-form behavior covered here:
///  * Page 2 was split into two dedicated steps: 2.1 lane selection only,
///    2.2 the selected lane's detail form. Page 2.1 must never show
///    lane-specific fields, attachment controls or the inspection tagline.
///  * The INSPECTION details step follows the compact Page 3 reference layout
///    without changing its required-description validation.
///  * The attachment button's "Photo/Video" label overflowed on narrow
///    screens because the Text inside it wasn't Flexible.
///  * The attachment helper/counter text implied "4 photos plus a video"
///    instead of one combined cap of 4 photos-or-videos.

const _category = ServiceCategoryEntity(
  id: 'cat-1',
  name: 'Electrician',
  inspectionFee: 500,
);

const _standardServices = [
  StandardServiceEntity(
    id: 'service-1',
    categoryId: 'cat-1',
    name: 'Fan Installation',
    price: 2100,
  ),
  StandardServiceEntity(
    id: 'service-2',
    categoryId: 'cat-1',
    name: 'Socket Repair',
    price: 2600,
  ),
];

const _nextLabel = {
  AppLocale.english: 'Next',
  AppLocale.romanUrdu: 'Aage',
  AppLocale.urdu: 'آگے',
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

const _oldTaglineRomanUrdu =
    'Rate batane se pehle kuch nahi khulta — jo kaha, wohi liya.';

// Section-title markers unique to each lane's Page 2.2 content.
const _standardMarker = 'Fixed Price Services';
const _inspectionMarker = 'INSPECTION FEE';
const _biddingMarker = 'WHAT NEEDS TO BE DONE?';

ProviderScope _wrap(
  Widget child, {
  AppLocale locale = AppLocale.english,
  BookingEntity? editBooking,
  LatLng? previewPosition,
  ThemeData? theme,
  List<AttachableInspectionEntity> attachableInspections = const [],
  List<StandardServiceEntity> standardServices = const [],
  BookingAddressCoordinatesResolver? addressCoordinatesResolver,
  BookingAddressLabelResolver? addressLabelResolver,
  BookingCurrentLocationResolver? currentLocationResolver,
}) {
  return ProviderScope(
    overrides: [
      clientBookingCategoriesProvider.overrideWith((ref) async => [_category]),
      // Switching to STANDARD triggers this fetch — stub it so the test
      // never makes a real (never-resolving-in-test) network call.
      standardServicesProvider.overrideWith(
        (ref, categoryId) async => standardServices,
      ),
      savedAddressesProvider.overrideWith(_FakeSavedAddressesNotifier.new),
      bookingMapPreviewPositionProvider.overrideWith(
        (ref) async => previewPosition,
      ),
      if (addressCoordinatesResolver != null)
        bookingAddressCoordinatesResolverProvider.overrideWithValue(
          addressCoordinatesResolver,
        ),
      if (addressLabelResolver != null)
        bookingAddressLabelResolverProvider.overrideWithValue(
          addressLabelResolver,
        ),
      if (currentLocationResolver != null)
        bookingCurrentLocationResolverProvider.overrideWithValue(
          currentLocationResolver,
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
  List<BookingStandardServiceItemEntity> standardServiceItems = const [],
  String? title,
  String? description,
}) {
  return BookingEntity(
    id: 'booking-1',
    referenceId: '#HG-1',
    serviceCategory: 'Electrician',
    serviceEmoji: '⚡',
    title: title,
    description: description,
    status: BookingStatus.pending,
    urgency: BookingUrgency.normal,
    createdAt: DateTime(2026, 7, 1),
    lane: lane,
    address: 'House 1, Street 2, Lahore',
    city: 'Lahore',
    latitude: 31.5204,
    longitude: 74.3587,
    attachments: attachments,
    standardServiceItems: standardServiceItems,
  );
}

/// Reaches Page 2.1 (lane selection only) from a fresh (non-edit) form with
/// a preselected service, so the service picker never has to be driven.
Future<void> _goToLaneSelectStep(
  WidgetTester tester, {
  AppLocale locale = AppLocale.english,
  List<AttachableInspectionEntity> attachableInspections = const [],
  List<StandardServiceEntity> standardServices = const [],
}) async {
  await tester.pumpWidget(
    _wrap(
      const BookServicePage(preselectedService: 'Electrician'),
      locale: locale,
      attachableInspections: attachableInspections,
      standardServices: standardServices,
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
  List<StandardServiceEntity> standardServices = const [],
}) async {
  await _goToLaneSelectStep(
    tester,
    locale: locale,
    attachableInspections: attachableInspections,
    standardServices: standardServices,
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

    testWidgets('Inspection details fit at every target width', (tester) async {
      addTearDown(tester.view.reset);

      for (final width in [320.0, 360.0, 390.0, 430.0, 600.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;

        await _goToLaneDetailsStep(tester);
        expect(tester.takeException(), isNull, reason: 'Step 3 width=$width');
        await tester.enterText(
          find.byKey(const ValueKey('inspection-problem-field')),
          'Switchboard se sparks aa rahe hain',
        );
        await tester.tap(find.text(_nextLabel[AppLocale.english]!));
        await tester.pumpAndSettle();

        expect(find.text('Normal'), findsOneWidget);
        expect(find.text('Urgent'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Page 4 width=$width');
      }
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

    testWidgets(
      'resolved manual address becomes authoritative and enables Next',
      (tester) async {
        const resolved = LatLng(24.8732, 67.0721);
        await tester.pumpWidget(
          _wrap(
            const BookServicePage(preselectedService: 'Electrician'),
            addressCoordinatesResolver: (address) async => resolved,
            addressLabelResolver: (latitude, longitude) async =>
                '123 Test Street, Karachi',
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField).first,
          '123 Test Street',
        );
        await tester.pump(const Duration(milliseconds: 751));
        await tester.pumpAndSettle();

        final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
        expect(map.initialCameraPosition.target, resolved);
        expect(map.markers, hasLength(1));
        expect(find.text('123 Test Street, Karachi'), findsWidgets);

        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('Fixed-price services'), findsOneWidget);
      },
    );

    testWidgets('Current Location selection becomes authoritative', (
      tester,
    ) async {
      final position = Position(
        latitude: 24.9012,
        longitude: 67.1154,
        timestamp: DateTime(2026, 8, 26),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      await tester.pumpWidget(
        _wrap(
          const BookServicePage(preselectedService: 'Electrician'),
          currentLocationResolver: () async => LocationAvailabilityResult(
            LocationAvailability.available,
            position: position,
          ),
          addressLabelResolver: (latitude, longitude) async =>
              'Current Test Location, Karachi',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Current Location'));
      await tester.pumpAndSettle();

      final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(
        map.initialCameraPosition.target,
        LatLng(position.latitude, position.longitude),
      );
      expect(map.markers, hasLength(1));
      expect(find.text('Current Test Location, Karachi'), findsWidgets);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Fixed-price services'), findsOneWidget);
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

    testWidgets('confirmed map-picker location remains valid', (tester) async {
      await tester.pumpWidget(
        _wrap(const BookServicePage(preselectedService: 'Electrician')),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Home'));
      await tester.tap(find.text('Home'));
      await tester.pump();
      await tester.ensureVisible(find.text('Pick on Map'));
      await tester.tap(find.text('Pick on Map'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use This Location'));
      await tester.pumpAndSettle();

      expect(find.text('House 1, Street 2, Lahore'), findsWidgets);
      final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.markers, hasLength(1));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Fixed-price services'), findsOneWidget);
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
      expect(find.text(_inspectionMarker), findsNothing);
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

    testWidgets('empty inspection report picker uses contextual state copy', (
      tester,
    ) async {
      await _goToLaneDetailsStep(
        tester,
        laneOptionTitle: _customOption[AppLocale.english]!,
      );

      await tester.tap(find.byKey(const ValueKey('attach-inspection-report')));
      await tester.pumpAndSettle();

      expect(find.text('No inspection reports yet'), findsOneWidget);
      expect(
        find.text('No previous inspection reports available for this service.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
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
      expect(find.text('View Inspection Report'), findsOneWidget);
      expect(find.text('Change report'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);

      await tester.tap(find.text('Change report'));
      await tester.pumpAndSettle();
      expect(find.text('Loose neutral wire'), findsWidgets);
      await tester.tap(find.text('Loose neutral wire').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('inspection-report-attached')),
        findsOneWidget,
      );

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('inspection-report-attached')),
        findsNothing,
      );
      expect(find.text('Attach report'), findsOneWidget);
    });

    testWidgets('attached report View action opens the report route', (
      tester,
    ) async {
      final report = AttachableInspectionEntity(
        bookingId: 'inspection-1',
        categoryId: 'cat-1',
        categoryName: 'Electrician',
        inspectionDate: DateTime(2026, 7, 1),
        issueFound: 'Loose neutral wire',
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                const BookServicePage(preselectedService: 'Electrician'),
          ),
          GoRoute(
            path: '/client/booking/:id/inspection-report',
            builder: (_, state) =>
                Scaffold(body: Text('Viewing ${state.pathParameters['id']}')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clientBookingCategoriesProvider.overrideWith(
              (ref) async => [_category],
            ),
            standardServicesProvider.overrideWith(
              (ref, categoryId) async => [],
            ),
            savedAddressesProvider.overrideWith(
              _FakeSavedAddressesNotifier.new,
            ),
            bookingMapPreviewPositionProvider.overrideWith((ref) async => null),
            attachableInspectionsProvider.overrideWith(
              (ref, categoryId) async => [report],
            ),
          ],
          child: localizedRouterApp(router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Home'));
      await tester.tap(find.text('Home'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await _selectLane(tester, 'Custom Work');
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('attach-inspection-report')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Loose neutral wire'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View Inspection Report'));
      await tester.pumpAndSettle();

      expect(find.text('Viewing inspection-1'), findsOneWidget);
    });

    testWidgets('the lane cards themselves are gone on this page', (
      tester,
    ) async {
      await _goToLaneDetailsStep(tester);
      expect(find.text('Fixed-price services'), findsNothing);
      expect(find.text('Custom Work'), findsNothing);
    });
  });

  group('Page 3 — fixed-price lane reference layout', () {
    testWidgets('renders the reference hierarchy and English wording', (
      tester,
    ) async {
      await _goToLaneDetailsStep(
        tester,
        laneOptionTitle: _standardOption[AppLocale.english]!,
        standardServices: _standardServices,
      );

      expect(find.text('Fixed Price Services'), findsOneWidget);
      expect(find.text('Step 3 / 4 · Electrician'), findsOneWidget);
      expect(find.text('Fan Installation'), findsOneWidget);
      expect(find.text('Socket Repair'), findsOneWidget);
      expect(
        find.text('This price is final. It will not change at your door.'),
        findsOneWidget,
      );
      expect(find.text('Choose a standard service'), findsNothing);
      expect(find.text('You can choose more than one service.'), findsNothing);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Rs 0'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Back'), findsNothing);
      for (var index = 0; index < 4; index++) {
        expect(
          find.byKey(ValueKey('fixed-price-progress-$index')),
          findsOneWidget,
        );
      }
    });

    testWidgets('starts unselected and enables CTA from the real selections', (
      tester,
    ) async {
      await _goToLaneDetailsStep(
        tester,
        laneOptionTitle: _standardOption[AppLocale.english]!,
        standardServices: _standardServices,
      );

      var firstService = tester.widget<Semantics>(
        find.byKey(const ValueKey('fixed-price-service-service-1')),
      );
      var cta = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('fixed-price-next')),
      );
      expect(firstService.properties.selected, isFalse);
      expect(cta.onPressed, isNull);

      await tester.tap(find.text('Fan Installation'));
      await tester.pump(const Duration(milliseconds: 200));
      firstService = tester.widget<Semantics>(
        find.byKey(const ValueKey('fixed-price-service-service-1')),
      );
      cta = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('fixed-price-next')),
      );
      expect(firstService.properties.selected, isTrue);
      expect(cta.onPressed, isNotNull);
      expect(find.text('Rs 2,100'), findsNWidgets(2));

      await tester.tap(find.text('Socket Repair'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Rs 4,700'), findsOneWidget);

      await tester.tap(find.text('Fan Installation'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Rs 2,600'), findsNWidgets(2));
    });

    testWidgets('keeps only an actual wizard selection after back and return', (
      tester,
    ) async {
      await _goToLaneDetailsStep(
        tester,
        laneOptionTitle: _standardOption[AppLocale.english]!,
        standardServices: _standardServices,
      );
      await tester.tap(find.text('Socket Repair'));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pumpAndSettle();

      final firstService = tester.widget<Semantics>(
        find.byKey(const ValueKey('fixed-price-service-service-1')),
      );
      final secondService = tester.widget<Semantics>(
        find.byKey(const ValueKey('fixed-price-service-service-2')),
      );
      expect(firstService.properties.selected, isFalse);
      expect(secondService.properties.selected, isTrue);
      expect(find.text('Rs 2,600'), findsNWidgets(2));
    });

    testWidgets('restores persisted edit selections from the existing IDs', (
      tester,
    ) async {
      final booking = _editableBooking(
        lane: BookingLane.standard,
        standardServiceItems: const [
          BookingStandardServiceItemEntity(
            id: 'item-2',
            standardServiceId: 'service-2',
            nameSnapshot: 'Socket Repair',
            priceSnapshot: 2600,
          ),
        ],
      );
      await tester.pumpWidget(
        _wrap(
          BookServicePage(editBookingId: booking.id),
          editBooking: booking,
          standardServices: _standardServices,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pumpAndSettle();

      final firstService = tester.widget<Semantics>(
        find.byKey(const ValueKey('fixed-price-service-service-1')),
      );
      final secondService = tester.widget<Semantics>(
        find.byKey(const ValueKey('fixed-price-service-service-2')),
      );
      final cta = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('fixed-price-next')),
      );
      expect(firstService.properties.selected, isFalse);
      expect(secondService.properties.selected, isTrue);
      expect(cta.onPressed, isNotNull);
      expect(find.text('Rs 2,600'), findsNWidgets(2));
    });

    testWidgets('uses the reference wording in Roman Urdu + easy English', (
      tester,
    ) async {
      await _goToLaneDetailsStep(
        tester,
        locale: AppLocale.romanUrdu,
        laneOptionTitle: _standardOption[AppLocale.romanUrdu]!,
        standardServices: _standardServices,
      );

      expect(find.text('Fixed Price Services'), findsOneWidget);
      expect(find.text('Step 3 / 4 · Electrician'), findsOneWidget);
      expect(
        find.text('Ye rate final hai. Darwazay par nahi badlega.'),
        findsOneWidget,
      );
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Aage'), findsOneWidget);
    });

    testWidgets('does not overflow at small and normal mobile widths', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      for (final width in [320.0, 360.0, 390.0, 430.0, 600.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;

        await _goToLaneDetailsStep(
          tester,
          laneOptionTitle: _standardOption[AppLocale.english]!,
          standardServices: _standardServices,
        );

        expect(
          tester.takeException(),
          isNull,
          reason: 'Fixed-price Page 3 overflowed at $width px',
        );
      }
    });
  });

  group('Back/Next navigation between 2.1 and 2.2', () {
    testWidgets('Back from lane-details returns to lane-selection', (
      tester,
    ) async {
      await _goToLaneDetailsStep(tester);
      expect(find.text(_inspectionMarker), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
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

    testWidgets(
      'Page 1 and lane-specific Page 3 state survive full back/forward navigation',
      (tester) async {
        for (final lane in BookingLane.values) {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          final option = switch (lane) {
            BookingLane.standard => _standardOption[AppLocale.english]!,
            BookingLane.inspection => _inspectionOption[AppLocale.english]!,
            BookingLane.bidding => _customOption[AppLocale.english]!,
          };
          await _goToLaneDetailsStep(
            tester,
            laneOptionTitle: option,
            standardServices: _standardServices,
          );

          switch (lane) {
            case BookingLane.standard:
              await tester.tap(find.text('Socket Repair'));
            case BookingLane.inspection:
              await tester.enterText(
                find.byKey(const ValueKey('inspection-problem-field')),
                'Stateful inspection description',
              );
            case BookingLane.bidding:
              await tester.enterText(
                find.byType(TextFormField).first,
                'Stateful custom title',
              );
          }
          await tester.pump();

          await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
          await tester.pumpAndSettle();

          expect(find.text('House 1, Street 2, Lahore'), findsWidgets);
          final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
          expect(map.markers, hasLength(1));

          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
          final laneSemantics = tester.widget<Semantics>(
            find.byKey(ValueKey('booking-lane-${lane.name}')),
          );
          expect(laneSemantics.properties.selected, isTrue);
          await tester.tap(find.byType(ElevatedButton).last);
          await tester.pumpAndSettle();

          switch (lane) {
            case BookingLane.standard:
              final service = tester.widget<Semantics>(
                find.byKey(const ValueKey('fixed-price-service-service-2')),
              );
              expect(service.properties.selected, isTrue);
            case BookingLane.inspection:
              expect(
                find.text('Stateful inspection description'),
                findsOneWidget,
              );
            case BookingLane.bidding:
              expect(find.text('Stateful custom title'), findsOneWidget);
          }
        }
      },
    );

    testWidgets('Custom Kaam details fit at every target width', (
      tester,
    ) async {
      addTearDown(tester.view.reset);

      for (final width in [320.0, 360.0, 390.0, 430.0, 600.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;

        await _goToLaneDetailsStep(
          tester,
          laneOptionTitle: _customOption[AppLocale.english]!,
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'Custom Kaam Page 3 overflowed at $width px',
        );
      }
    });
  });

  group('Page 3 to current Page 4 navigation', () {
    testWidgets('STANDARD selection advances to Page 4', (tester) async {
      await _goToLaneDetailsStep(
        tester,
        laneOptionTitle: _standardOption[AppLocale.english]!,
        standardServices: _standardServices,
      );
      await tester.tap(find.text('Fan Installation'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('fixed-price-next')));
      await tester.pumpAndSettle();

      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Urgent'), findsOneWidget);
    });

    testWidgets('BIDDING with required title and voice advances to Page 4', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final booking = _editableBooking(
        lane: BookingLane.bidding,
        title: 'Repair kitchen tap',
        attachments: [
          BookingAttachmentEntity(
            id: 'voice-1',
            type: AttachmentType.audio,
            url: 'https://example.test/voice.m4a',
            createdAt: DateTime(2026, 7, 1),
          ),
        ],
      );
      await tester.pumpWidget(
        _wrap(BookServicePage(editBookingId: booking.id), editBooking: booking),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('custom-request-next')));
      await tester.pumpAndSettle();

      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Urgent'), findsOneWidget);
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
    testWidgets('INSPECTION requires description but not voice or photos', (
      tester,
    ) async {
      await _goToLaneDetailsStep(tester);

      await tester.tap(find.text(_nextLabel[AppLocale.english]!));
      await tester.pumpAndSettle();
      expect(find.text('Tell us the problem'), findsOneWidget);
      ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold).first),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('inspection-problem-field')),
        'Switchboard is sparking',
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('inspection-details-cta')),
          matching: find.byType(ElevatedButton),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Urgent'), findsOneWidget);
    });

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

      ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold).first),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Repair kitchen tap',
      );
      await tester.tap(find.text(_nextLabel[AppLocale.english]!));
      await tester.pumpAndSettle();

      expect(
        find.text('Add a voice note before continuing with Custom Kaam.'),
        findsOneWidget,
      );
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

    testWidgets('renders the Pure English reference hierarchy', (tester) async {
      await _goToLaneDetailsStep(tester);

      expect(find.text('Tell us the problem'), findsOneWidget);
      expect(find.text('Step 3 / 4 · Electrician'), findsOneWidget);
      expect(find.text('What do you see? · required'), findsOneWidget);
      expect(find.text('Voice note · optional'), findsOneWidget);
      expect(find.text('Add photo'), findsOneWidget);
      expect(find.text('0 / 4 attachments'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('inspection-step-progress')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('inspection-fee-card')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('inspection-problem-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('inspection-media-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('inspection-details-cta')),
        findsOneWidget,
      );
      expect(find.text('How inspection works'), findsNothing);
    });

    testWidgets('renders the clarified Roman Urdu wording', (tester) async {
      await _goToLaneDetailsStep(tester, locale: AppLocale.romanUrdu);

      expect(find.text('Masla bataein'), findsOneWidget);
      expect(find.text('Step 3 / 4 · Electrician'), findsOneWidget);
      expect(
        find.text('Aap ko kya nazar aa raha hai? · zaroori'),
        findsOneWidget,
      );
      expect(find.text('Bol kar bataein · marzi se'), findsOneWidget);
      expect(find.text('Photo daalein'), findsOneWidget);
    });

    testWidgets('keeps voice and attachments optional in Urdu', (tester) async {
      await _goToLaneDetailsStep(tester, locale: AppLocale.urdu);
      expect(find.text('وائس نوٹ · اختیاری'), findsOneWidget);
    });
  });

  group('Inspection attachment button label', () {
    testWidgets('renders in English', (tester) async {
      await _goToLaneDetailsStep(tester);
      expect(find.text('Add photo'), findsOneWidget);
    });

    testWidgets('renders in Roman Urdu', (tester) async {
      await _goToLaneDetailsStep(tester, locale: AppLocale.romanUrdu);
      expect(find.text('Photo daalein'), findsOneWidget);
    });

    testWidgets('renders in Urdu', (tester) async {
      await _goToLaneDetailsStep(tester, locale: AppLocale.urdu);
      expect(find.text('تصویر شامل کریں'), findsOneWidget);
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
      for (final label in ['Add photo', 'Photo daalein', 'تصویر شامل کریں']) {
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
      await _goToLaneDetailsStep(
        tester,
        laneOptionTitle: _customOption[AppLocale.english]!,
      );

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
