import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/categories/data/models/service_category_model.dart';
import 'package:handygo_app/features/categories/domain/entities/service_category_entity.dart';
import 'package:handygo_app/features/categories/presentation/providers/categories_providers.dart';
import 'package:handygo_app/features/client/presentation/pages/post_job_page.dart';
import 'package:handygo_app/features/client/presentation/widgets/service_data.dart';
import 'package:handygo_app/features/saved_addresses/domain/entities/saved_address_entity.dart';
import 'package:handygo_app/features/saved_addresses/presentation/providers/saved_addresses_providers.dart';

import '../../support/l10n_test_app.dart';

/// The lane step of the booking form for a LANE-RESTRICTED category.
///
/// Appliances Repair is BIDDING-only via `soleLane`: an appliance fault cannot
/// be quoted from a fixed-price catalog, and the platform does not sell a paid
/// inspection visit for it. The lanes it does not offer are not rendered at
/// all — a greyed-out card the client can never unlock is noise, and the
/// backend rejects those lanes outright anyway (`assertLaneAllowed`).
///
/// `soleLane` supersedes the legacy `inspectionOnly` boolean WITHOUT replacing
/// it. A category still restricted the old way keeps its original
/// presentation, greyed cards and all, so nothing about those rows changes.
///
/// Three regressions are guarded here: the empty lane page (the rule is a
/// property OF THE CATEGORY, so a missing category offers a retry instead of
/// guessing), blast radius on unrestricted categories, and
/// backward compatibility for legacy `inspectionOnly` rows.

const _romanUrdu = AppLocale.romanUrdu;

// Copy taken from app_ur_Latn.arb — the locale these tests render in.
const _fixedPriceLane = 'Fixed-price services';
const _inspectionLane = 'Inspection';
const _biddingLane = 'Custom Kaam';

ServiceCategoryEntity _category({
  required String name,
  double? inspectionFee,
  bool inspectionOnly = false,
  BookingLane? soleLane,
}) => ServiceCategoryEntity(
  id: 'cat-${name.toLowerCase().replaceAll(' ', '-')}',
  name: name,
  inspectionFee: inspectionFee,
  inspectionOnly: inspectionOnly,
  soleLane: soleLane,
);

/// The stored inspection fee is deliberately still present: `soleLane`, not
/// the fee, is what removes the inspection lane, and the test would pass for
/// the wrong reason if the fee were null.
final _appliances = _category(
  name: 'Appliances Repair',
  inspectionFee: 500,
  soleLane: BookingLane.bidding,
);

final _electrician = _category(name: 'Electrician', inspectionFee: 500);

/// A category still restricted the OLD way: the legacy boolean, no soleLane.
final _legacyInspectionOnly = _category(
  name: 'Legacy Inspection Only',
  inspectionFee: 500,
  inspectionOnly: true,
);

class _SavedAddressNotifier extends SavedAddressesNotifier {
  @override
  Future<List<SavedAddressEntity>> build() async => const [
    SavedAddressEntity(
      id: 'home',
      label: 'Home',
      normalizedLabel: 'home',
      addressLine: 'House 12, Street 5, Karachi',
      city: 'Karachi',
      latitude: 24.86,
      longitude: 67.01,
    ),
  ];
}

/// Pumps the booking form straight onto its lane step for [service].
Future<void> _pumpLaneStep(
  WidgetTester tester, {
  required String service,
  required List<ServiceCategoryEntity> categories,
  String? categoryId,
}) async {
  tester.view.physicalSize = const Size(320, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allCategoriesProvider.overrideWith((ref) async => categories),
        savedAddressesProvider.overrideWith(_SavedAddressNotifier.new),
      ],
      child: localizedApp(
        BookServicePage(
          preselectedService: service,
          preselectedCategoryId: categoryId,
        ),
        locale: _romanUrdu,
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Home'));
  await tester.pump();

  await tester.ensureVisible(find.text('Aage'));
  await tester.tap(find.text('Aage'));
  await tester.pumpAndSettle();
}

void main() {
  group('stable category identity', () {
    testWidgets('resolves the Home selection by ID when display copy differs', (
      tester,
    ) async {
      await _pumpLaneStep(
        tester,
        service: 'Localized appliance label',
        categoryId: _appliances.id,
        categories: [_electrician, _appliances],
      );

      expect(find.byKey(const ValueKey('booking-lane-bidding')), findsOneWidget);
      expect(find.byKey(const ValueKey('booking-lane-standard')), findsNothing);
      expect(find.byKey(const ValueKey('booking-lane-inspection')), findsNothing);
    });
  });

  group('Appliances Repair — bidding only', () {
    testWidgets('soleLane keeps Bidding enabled even with a stale legacy flag', (
      tester,
    ) async {
      final category = _category(
        name: 'Appliances Repair',
        inspectionFee: 500,
        inspectionOnly: true,
        soleLane: BookingLane.bidding,
      );
      await _pumpLaneStep(
        tester,
        service: category.name,
        categoryId: category.id,
        categories: [category],
      );
      final bidding = tester.widget<Semantics>(
        find.byKey(const ValueKey('booking-lane-bidding')),
      );
      expect(bidding.properties.enabled, isTrue);
      expect(find.byKey(const ValueKey('booking-lane-standard')), findsNothing);
      expect(find.byKey(const ValueKey('booking-lane-inspection')), findsNothing);
    });

    testWidgets('offers the Bidding lane', (tester) async {
      await _pumpLaneStep(
        tester,
        service: 'Appliances Repair',
        categories: [_appliances, _electrician, _legacyInspectionOnly],
      );

      expect(find.text(_biddingLane), findsOneWidget);
      expect(find.byKey(const ValueKey('booking-lane-bidding')), findsOneWidget);
    });

    testWidgets('the Bidding card is enabled and starts unselected — the '
        'client still confirms what they are booking', (tester) async {
      await _pumpLaneStep(
        tester,
        service: 'Appliances Repair',
        categories: [_appliances, _electrician, _legacyInspectionOnly],
      );

      final bidding = tester.widget<Semantics>(
        find.byKey(const ValueKey('booking-lane-bidding')),
      );
      expect(bidding.properties.enabled, isTrue);
      expect(bidding.properties.selected, isFalse);
    });

    testWidgets('hides the Standard lane entirely — not merely greyed out', (
      tester,
    ) async {
      await _pumpLaneStep(
        tester,
        service: 'Appliances Repair',
        categories: [_appliances, _electrician, _legacyInspectionOnly],
      );

      expect(find.text(_fixedPriceLane), findsNothing);
      expect(find.byKey(const ValueKey('booking-lane-standard')), findsNothing);
    });

    testWidgets('hides the Inspection lane entirely, even though the category '
        'still carries a stored inspection fee', (tester) async {
      await _pumpLaneStep(
        tester,
        service: 'Appliances Repair',
        categories: [_appliances, _electrician, _legacyInspectionOnly],
      );

      expect(find.text(_inspectionLane), findsNothing);
      expect(
        find.byKey(const ValueKey('booking-lane-inspection')),
        findsNothing,
      );
    });

    testWidgets('the old OR divider is not rendered', (tester) async {
      await _pumpLaneStep(
        tester,
        service: 'Appliances Repair',
        categories: [_appliances, _electrician, _legacyInspectionOnly],
      );

      expect(find.text('ya'), findsNothing);
    });
  });

  group('other categories are untouched', () {
    testWidgets('a normal category still offers all three lanes', (
      tester,
    ) async {
      await _pumpLaneStep(
        tester,
        service: 'Electrician',
        categories: [_appliances, _electrician, _legacyInspectionOnly],
      );

      expect(find.text(_fixedPriceLane), findsOneWidget);
      expect(find.text(_inspectionLane), findsOneWidget);
      expect(find.text(_biddingLane), findsOneWidget);
      expect(find.text('ya'), findsNothing);
    });

    testWidgets('a normal category leaves every lane enabled and unselected', (
      tester,
    ) async {
      await _pumpLaneStep(
        tester,
        service: 'Electrician',
        categories: [_appliances, _electrician, _legacyInspectionOnly],
      );

      for (final lane in ['standard', 'inspection', 'bidding']) {
        final semantics = tester.widget<Semantics>(
          find.byKey(ValueKey('booking-lane-$lane')),
        );
        expect(semantics.properties.enabled, isTrue, reason: lane);
        expect(semantics.properties.selected, isFalse, reason: lane);
      }
    });

    testWidgets('a normal category with NO inspection fee still shows the '
        'inspection card, disabled — the pre-existing rule, unchanged', (
      tester,
    ) async {
      final cleaning = _category(name: 'Cleaning');

      await _pumpLaneStep(
        tester,
        service: 'Cleaning',
        categories: [_appliances, _electrician, _legacyInspectionOnly, cleaning],
      );

      expect(find.text(_inspectionLane), findsOneWidget);
      expect(
        tester
            .widget<Semantics>(
              find.byKey(const ValueKey('booking-lane-inspection')),
            )
            .properties
            .enabled,
        isFalse,
      );
    });
  });

  group('legacy inspectionOnly categories behave exactly as before', () {
    testWidgets('all three cards are still rendered — the legacy row keeps its '
        'original presentation rather than adopting the soleLane one', (
      tester,
    ) async {
      await _pumpLaneStep(
        tester,
        service: 'Legacy Inspection Only',
        categories: [_appliances, _electrician, _legacyInspectionOnly],
      );

      expect(find.text(_fixedPriceLane), findsOneWidget);
      expect(find.text(_inspectionLane), findsOneWidget);
      expect(find.text(_biddingLane), findsOneWidget);
    });

    testWidgets('Standard and Custom stay greyed out, and Inspection stays '
        'enabled — byte for byte the pre-soleLane behaviour', (tester) async {
      await _pumpLaneStep(
        tester,
        service: 'Legacy Inspection Only',
        categories: [_appliances, _electrician, _legacyInspectionOnly],
      );

      bool enabledOf(String lane) => tester
          .widget<Semantics>(find.byKey(ValueKey('booking-lane-$lane')))
          .properties
          .enabled!;

      expect(enabledOf('standard'), isFalse);
      expect(enabledOf('bidding'), isFalse);
      expect(enabledOf('inspection'), isTrue);
    });

    test('the legacy flag alone still resolves to INSPECTION-only', () {
      expect(
        _legacyInspectionOnly.effectiveSoleLane,
        BookingLane.inspection,
      );
      expect(_legacyInspectionOnly.allowsLane(BookingLane.inspection), isTrue);
      expect(_legacyInspectionOnly.allowsLane(BookingLane.standard), isFalse);
      expect(_legacyInspectionOnly.allowsLane(BookingLane.bidding), isFalse);
    });
  });

  group('an unresolvable category never guesses', () {
    testWidgets('a category missing from the backend list offers a retry '
        'instead of a blank section or guessed lanes', (tester) async {
      await _pumpLaneStep(
        tester,
        service: 'Appliances Repair',
        // Backend has not been seeded with the category yet.
        categories: [_electrician],
      );

      expect(find.text(_fixedPriceLane), findsNothing);
      expect(find.text(_inspectionLane), findsNothing);
      expect(find.text(_biddingLane), findsNothing);
      expect(find.text('ya'), findsNothing);
      expect(
        find.text('Services load nahi ho sakin. Wapas jaa kar dobara koshish karein.'),
        findsOneWidget,
      );
      expect(find.text('Dobara koshish karein'), findsOneWidget);
    });
  });

  group('category configuration drives the rule, not the name', () {
    test('soleLane is what the UI reads — any category may be restricted to '
        'any lane without a Flutter change', () {
      final restricted = _category(
        name: 'Some Future Category',
        inspectionFee: 1200,
        soleLane: BookingLane.standard,
      );

      expect(restricted.allowsLane(BookingLane.standard), isTrue);
      expect(restricted.allowsLane(BookingLane.inspection), isFalse);
      expect(restricted.allowsLane(BookingLane.bidding), isFalse);
    });

    test('an unrestricted category allows every lane', () {
      expect(_electrician.effectiveSoleLane, isNull);
      for (final lane in BookingLane.values) {
        expect(_electrician.allowsLane(lane), isTrue, reason: lane.name);
      }
    });

    test('soleLane wins over the legacy flag when a stale row sets both', () {
      final contradictory = _category(
        name: 'Contradictory',
        inspectionFee: 500,
        inspectionOnly: true,
        soleLane: BookingLane.bidding,
      );

      expect(contradictory.effectiveSoleLane, BookingLane.bidding);
      expect(contradictory.allowsLane(BookingLane.bidding), isTrue);
      expect(contradictory.allowsLane(BookingLane.inspection), isFalse);
    });

    test('a payload carrying ONLY the legacy flag still restricts to '
        'INSPECTION — an older backend that does not send soleLane yet must '
        'keep working', () {
      final parsed = ServiceCategoryModel.fromJson(const {
        'id': 'cat-legacy',
        'name': 'Legacy Inspection Only',
        'description': null,
        'iconUrl': null,
        'inspectionFee': 500,
        'inspectionOnly': true,
      }).toEntity();

      expect(parsed.soleLane, isNull);
      expect(parsed.inspectionOnly, isTrue);
      expect(parsed.effectiveSoleLane, BookingLane.inspection);
      expect(parsed.allowsLane(BookingLane.inspection), isTrue);
      expect(parsed.allowsLane(BookingLane.bidding), isFalse);
    });

    test('Appliances Repair arrives as BIDDING-only straight from the API '
        'payload', () {
      final parsed = ServiceCategoryModel.fromJson(const {
        'id': 'cat-appliances',
        'name': 'Appliances Repair',
        'description': null,
        'iconUrl': null,
        'inspectionFee': 500,
        'soleLane': 'BIDDING',
      }).toEntity();

      expect(parsed.soleLane, BookingLane.bidding);
      // The legacy flag rides along in the response and is false here, so an
      // older APK reading only that field sees an unrestricted category.
      expect(parsed.inspectionOnly, isFalse);
      expect(parsed.allowsLane(BookingLane.bidding), isTrue);
      expect(parsed.allowsLane(BookingLane.standard), isFalse);
      expect(parsed.allowsLane(BookingLane.inspection), isFalse);
    });

    test('a payload with no soleLane leaves the category unrestricted — an '
        'older backend, or a response cached before the field existed, must '
        'not silently lose lanes', () {
      final parsed = ServiceCategoryModel.fromJson(const {
        'id': 'cat-electrician',
        'name': 'Electrician',
        'description': null,
        'iconUrl': null,
        'inspectionFee': 500,
      }).toEntity();

      expect(parsed.soleLane, isNull);
      expect(parsed.inspectionOnly, isFalse);
      for (final lane in BookingLane.values) {
        expect(parsed.allowsLane(lane), isTrue, reason: lane.name);
      }
    });

    test('an unrecognised soleLane is treated as unrestricted rather than '
        'guessing a restriction', () {
      final parsed = ServiceCategoryModel.fromJson(const {
        'id': 'cat-future',
        'name': 'Future Lane Category',
        'description': null,
        'iconUrl': null,
        'inspectionFee': null,
        'soleLane': 'SOMETHING_NEW',
      }).toEntity();

      expect(parsed.soleLane, isNull);
      expect(parsed.allowsLane(BookingLane.bidding), isTrue);
    });

    test('an unrecognised soleLane still falls through to the legacy flag '
        'rather than skipping the restriction entirely', () {
      final parsed = ServiceCategoryModel.fromJson(const {
        'id': 'cat-future',
        'name': 'Future Lane Category',
        'description': null,
        'iconUrl': null,
        'inspectionFee': 500,
        'inspectionOnly': true,
        'soleLane': 'SOMETHING_NEW',
      }).toEntity();

      expect(parsed.soleLane, isNull);
      expect(parsed.effectiveSoleLane, BookingLane.inspection);
    });

    test('the offline stub keeps the lane rule even when /categories fails, '
        'so the fallback can never re-expose Standard or Inspection', () {
      const offline = ServiceCategoryEntity(
        id: '',
        name: 'Appliances Repair',
        soleLane: BookingLane.bidding,
      );

      expect(offline.allowsLane(BookingLane.bidding), isTrue);
      expect(offline.allowsLane(BookingLane.standard), isFalse);
      expect(offline.allowsLane(BookingLane.inspection), isFalse);
    });

    test('a category with neither field set is unrestricted, not restricted '
        'to nothing', () {
      const bare = ServiceCategoryEntity(id: '', name: 'Bare');

      expect(bare.effectiveSoleLane, isNull);
      for (final lane in BookingLane.values) {
        expect(bare.allowsLane(lane), isTrue, reason: lane.name);
      }
    });
  });

  group('artwork', () {
    test('Appliances Repair resolves to the appliance asset, not carpenter '
        'and not a placeholder', () {
      final path = imagePathForCategory('Appliances Repair');

      expect(path, 'assets/images/appliance.png');
      expect(path, isNot(contains('carpenter')));
    });

    test('existing categories keep the artwork they already had', () {
      expect(imagePathForCategory('AC Technician'), 'assets/images/ac.jpg');
      expect(imagePathForCategory('Carpenter'), 'assets/images/carpenter.jpg');
    });
  });
}
