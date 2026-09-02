import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/categories/data/models/service_category_model.dart';
import 'package:handygo_app/features/categories/domain/entities/service_category_entity.dart';
import 'package:handygo_app/features/client/presentation/widgets/service_card.dart';

/// "Appliances Repair" — a BIDDING-only category.
///
/// The lane rule is owned by the backend (`assertLaneAllowed` rejects any lane
/// but the category's `soleLane`, see category-lane-rules.spec.ts). What these
/// tests cover is the Flutter half of the contract: the rule survives the
/// wire, any fee shown is the one the backend sent, and the category is
/// bookable rather than locked.

ServiceCategoryEntity _fromApi(Map<String, dynamic> json) =>
    ServiceCategoryModel.fromJson(json).toEntity();

const _appliancesJson = {
  'id': 'cat-appliances',
  'name': 'Appliances Repair',
  'description': 'Washing machine, fridge, microwave & home appliance repair',
  'iconUrl': null,
  'inspectionFee': 500,
  'soleLane': 'BIDDING',
};

const _electricianJson = {
  'id': 'cat-electrician',
  'name': 'Electrician',
  'description': 'Electrical wiring, fuse boards, fixtures & repairs',
  'iconUrl': null,
  'inspectionFee': 500,
  'soleLane': null,
};

void main() {
  group('the soleLane rule crosses the wire', () {
    test('Appliances Repair arrives as bidding-only', () {
      final category = _fromApi(_appliancesJson);

      expect(category.name, 'Appliances Repair');
      expect(category.soleLane, BookingLane.bidding);
      expect(category.allowsLane(BookingLane.bidding), isTrue);
      expect(category.allowsLane(BookingLane.standard), isFalse);
      expect(category.allowsLane(BookingLane.inspection), isFalse);
    });

    test('every other category arrives unchanged, with all lanes', () {
      final electrician = _fromApi(_electricianJson);

      expect(electrician.soleLane, isNull);
      for (final lane in BookingLane.values) {
        expect(electrician.allowsLane(lane), isTrue, reason: lane.name);
      }
    });

    test('a payload with no soleLane field keeps all lanes — an older '
        'backend, or a cached response written before the field existed, must '
        'not silently lose the Standard and Inspection lanes', () {
      final legacy = Map<String, dynamic>.from(_electricianJson)
        ..remove('soleLane');

      expect(_fromApi(legacy).soleLane, isNull);
    });
  });

  group('the inspection fee is the backend value, never a local literal', () {
    test('the stored fee still crosses the wire untouched — soleLane, not the '
        'fee, is what removes the inspection lane', () {
      // The UI reads exactly this field (post_job_page's inspectionFee is
      // resolved from the fetched category), and the backend snapshots the
      // same column into inspectionFeeSnapshot/estimatedPrice at create time —
      // so what is displayed and what is charged cannot diverge. On a
      // bidding-only category the fee is simply inert.
      expect(_fromApi(_appliancesJson).inspectionFee, 500);
    });

    test('the fee is whatever the backend says, not a constant in the app', () {
      final repriced = Map<String, dynamic>.from(_appliancesJson)
        ..['inspectionFee'] = 750;

      expect(_fromApi(repriced).inspectionFee, 750,
          reason: 'changing the category record must move the app with it');
    });

    test('a lane-restricted category without a fee is still surfaced as such '
        'rather than crashing', () {
      final feeless = Map<String, dynamic>.from(_appliancesJson)
        ..['inspectionFee'] = null;

      final category = _fromApi(feeless);
      expect(category.inspectionFee, isNull);
      expect(category.soleLane, BookingLane.bidding);
    });
  });

  group('client availability', () {
    test('Appliances Repair is launch-approved, so it books rather than '
        'rendering as a locked "Coming Soon" tile', () {
      expect(
        kLaunchActiveServiceCategories.contains('Appliances Repair'),
        isTrue,
      );
    });

    test('the launch allowlist still contains every category it did before', () {
      expect(
        kLaunchActiveServiceCategories,
        containsAll(<String>[
          'AC Technician',
          'Electrician',
          'Plumber',
          'Carpenter',
        ]),
      );
    });

    test('it has its own emoji rather than the generic tool fallback', () {
      expect(_fromApi(_appliancesJson).emoji, isNot('🛠️'));
      expect(_fromApi(_appliancesJson).emoji, '🧺');
    });

    test('existing categories keep the emoji they already had', () {
      expect(_fromApi(_electricianJson).emoji, '⚡');
    });
  });
}
