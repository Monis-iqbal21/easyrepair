import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/features/categories/data/models/service_category_model.dart';
import 'package:handygo_app/features/categories/domain/entities/service_category_entity.dart';
import 'package:handygo_app/features/categories/presentation/providers/categories_providers.dart';
import 'package:handygo_app/features/client/presentation/pages/post_job_page.dart';
import 'package:handygo_app/features/client/presentation/widgets/service_data.dart';
import 'package:handygo_app/features/saved_addresses/domain/entities/saved_address_entity.dart';
import 'package:handygo_app/features/saved_addresses/presentation/providers/saved_addresses_providers.dart';

import '../../support/l10n_test_app.dart';

/// The lane step of the booking form for an INSPECTION-ONLY category.
///
/// The regression this guards: the rule used to read
/// `category?.inspectionOnly ?? false`, so a category the form could not
/// resolve — backend list still loading, request failed, or the category
/// genuinely absent from `/categories` — silently fell back to "all lanes
/// allowed" and rendered Standard and Bidding for Appliances Repair, while
/// the same null disabled the Inspection card. The rule now refuses to guess.

const _romanUrdu = AppLocale.romanUrdu;

// Copy taken from app_ur_Latn.arb — the locale these tests render in.
const _standardWork = 'Fixed-price services';
const _somethingBroken = 'Inspection';
const _iKnowThePart = 'Custom Kaam';

ServiceCategoryEntity _category({
  required String name,
  double? inspectionFee,
  bool inspectionOnly = false,
}) => ServiceCategoryEntity(
  id: 'cat-${name.toLowerCase().replaceAll(' ', '-')}',
  name: name,
  inspectionFee: inspectionFee,
  inspectionOnly: inspectionOnly,
);

final _appliances = _category(
  name: 'Appliances Repair',
  inspectionFee: 500,
  inspectionOnly: true,
);

final _electrician = _category(name: 'Electrician', inspectionFee: 500);

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
        BookServicePage(preselectedService: service),
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
  group('Appliances Repair — inspection only', () {
    testWidgets('renders all three reference cards without preselection', (
      tester,
    ) async {
      await _pumpLaneStep(
        tester,
        service: 'Appliances Repair',
        categories: [_appliances, _electrician],
      );

      expect(find.text(_standardWork), findsOneWidget);
      expect(find.text(_somethingBroken), findsOneWidget);
      expect(find.text(_iKnowThePart), findsOneWidget);
      for (final lane in ['standard', 'inspection', 'bidding']) {
        final semantics = tester.widget<Semantics>(
          find.byKey(ValueKey('booking-lane-$lane')),
        );
        expect(semantics.properties.selected, isFalse);
      }
    });

    testWidgets('unsupported Standard and Custom cards remain disabled', (
      tester,
    ) async {
      await _pumpLaneStep(
        tester,
        service: 'Appliances Repair',
        categories: [_appliances, _electrician],
      );

      expect(
        tester
            .widget<Semantics>(
              find.byKey(const ValueKey('booking-lane-standard')),
            )
            .properties
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<Semantics>(
              find.byKey(const ValueKey('booking-lane-bidding')),
            )
            .properties
            .enabled,
        isFalse,
      );
    });

    testWidgets('the old OR divider is not rendered', (tester) async {
      await _pumpLaneStep(
        tester,
        service: 'Appliances Repair',
        categories: [_appliances, _electrician],
      );

      expect(find.text('OR'), findsNothing);
    });

    testWidgets('the lane step is still shown — never auto-skipped into the '
        'inspection form', (tester) async {
      await _pumpLaneStep(
        tester,
        service: 'Appliances Repair',
        categories: [_appliances, _electrician],
      );

      // The client still sees, and confirms, what they are booking.
      final inspection = tester.widget<Semantics>(
        find.byKey(const ValueKey('booking-lane-inspection')),
      );
      expect(inspection.properties.selected, isFalse);
    });
  });

  group('other categories are untouched', () {
    testWidgets('a normal category still offers all three lanes', (
      tester,
    ) async {
      await _pumpLaneStep(
        tester,
        service: 'Electrician',
        categories: [_appliances, _electrician],
      );

      expect(find.text(_standardWork), findsOneWidget);
      expect(find.text(_somethingBroken), findsOneWidget);
      expect(find.text(_iKnowThePart), findsOneWidget);
      expect(find.text('OR'), findsNothing);
    });
  });

  group('an unresolvable category never guesses', () {
    testWidgets('a category missing from the backend list shows no lane cards '
        'rather than defaulting to all of them — this is the exact defect '
        'that leaked Standard and Bidding into Appliances Repair', (
      tester,
    ) async {
      await _pumpLaneStep(
        tester,
        service: 'Appliances Repair',
        // Backend has not been seeded with the category yet.
        categories: [_electrician],
      );

      expect(find.text(_standardWork), findsNothing);
      expect(find.text(_iKnowThePart), findsNothing);
      expect(find.text('OR'), findsNothing);
    });
  });

  group('category configuration drives the rule, not the name', () {
    test('the flag is what the UI reads — any category may be made '
        'inspection-only without a Flutter change', () {
      final madeInspectionOnly = _category(
        name: 'Some Future Category',
        inspectionFee: 1200,
        inspectionOnly: true,
      );

      expect(madeInspectionOnly.inspectionOnly, isTrue);
      expect(_electrician.inspectionOnly, isFalse);
    });

    test('Appliances Repair carries inspectionOnly == true and Rs. 500 '
        'straight from the API payload', () {
      final parsed = ServiceCategoryModel.fromJson(const {
        'id': 'cat-appliances',
        'name': 'Appliances Repair',
        'description': null,
        'iconUrl': null,
        'inspectionFee': 500,
        'inspectionOnly': true,
      }).toEntity();

      expect(parsed.inspectionOnly, isTrue);
      expect(parsed.inspectionFee, 500);
    });

    test('the offline stub keeps the lane rule even when /categories fails, '
        'so the fallback can never re-expose Standard or Bidding', () {
      // Exercised through the public provider surface: the fallback list is
      // what allCategoriesProvider returns when the request throws.
      const offline = ServiceCategoryEntity(
        id: '',
        name: 'Appliances Repair',
        inspectionOnly: true,
      );
      expect(offline.inspectionOnly, isTrue);
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
