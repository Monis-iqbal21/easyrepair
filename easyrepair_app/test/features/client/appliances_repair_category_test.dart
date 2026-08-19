import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/features/categories/data/models/service_category_model.dart';
import 'package:handygo_app/features/categories/domain/entities/service_category_entity.dart';
import 'package:handygo_app/features/client/presentation/widgets/service_card.dart';

/// "Appliances Repair" — an INSPECTION-only category at Rs. 500.
///
/// The lane rule is owned by the backend (BookingsService rejects any lane but
/// INSPECTION for such a category, see inspection-only-category.spec.ts). What
/// these tests cover is the Flutter half of the contract: the flag survives the
/// wire, the fee shown is the one the backend sent, and the category is
/// bookable rather than locked.

ServiceCategoryEntity _fromApi(Map<String, dynamic> json) =>
    ServiceCategoryModel.fromJson(json).toEntity();

const _appliancesJson = {
  'id': 'cat-appliances',
  'name': 'Appliances Repair',
  'description': 'Washing machine, fridge, microwave & home appliance repair',
  'iconUrl': null,
  'inspectionFee': 500,
  'inspectionOnly': true,
};

const _electricianJson = {
  'id': 'cat-electrician',
  'name': 'Electrician',
  'description': 'Electrical wiring, fuse boards, fixtures & repairs',
  'iconUrl': null,
  'inspectionFee': 500,
  'inspectionOnly': false,
};

void main() {
  group('the inspectionOnly flag crosses the wire', () {
    test('Appliances Repair arrives as inspection-only', () {
      final category = _fromApi(_appliancesJson);

      expect(category.name, 'Appliances Repair');
      expect(category.inspectionOnly, isTrue);
    });

    test('every other category arrives unchanged, with all lanes', () {
      expect(_fromApi(_electricianJson).inspectionOnly, isFalse);
    });

    test('a payload with no inspectionOnly field keeps all lanes — an older '
        'backend, or a cached response written before the field existed, must '
        'not silently lose the Standard and Bidding lanes', () {
      final legacy = Map<String, dynamic>.from(_electricianJson)
        ..remove('inspectionOnly');

      expect(_fromApi(legacy).inspectionOnly, isFalse);
    });
  });

  group('the inspection fee is the backend value, never a local literal', () {
    test('Appliances Repair carries Rs. 500 straight from the API payload', () {
      // The UI reads exactly this field (post_job_page's inspectionFee is
      // resolved from the fetched category), and the backend snapshots the
      // same column into inspectionFeeSnapshot/estimatedPrice at create time —
      // so what is displayed and what is charged cannot diverge.
      expect(_fromApi(_appliancesJson).inspectionFee, 500);
    });

    test('the fee is whatever the backend says, not a constant in the app', () {
      final repriced = Map<String, dynamic>.from(_appliancesJson)
        ..['inspectionFee'] = 750;

      expect(_fromApi(repriced).inspectionFee, 750,
          reason: 'changing the category record must move the app with it');
    });

    test('an inspection-only category without a fee is still surfaced as such '
        'rather than crashing', () {
      final feeless = Map<String, dynamic>.from(_appliancesJson)
        ..['inspectionFee'] = null;

      final category = _fromApi(feeless);
      expect(category.inspectionFee, isNull);
      expect(category.inspectionOnly, isTrue);
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
