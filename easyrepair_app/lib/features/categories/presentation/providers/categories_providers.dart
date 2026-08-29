import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/datasources/categories_remote_datasource.dart';
import '../../domain/entities/service_category_entity.dart';
import '../../domain/entities/standard_service_entity.dart';

// ── Remote data source provider ───────────────────────────────────────────────

final categoriesRemoteDataSourceProvider =
    Provider<CategoriesRemoteDataSource>((ref) {
  return CategoriesRemoteDataSourceImpl(ref.watch(dioProvider));
});

// ── All active categories from backend (no whitelist) ─────────────────────────
// Used by homepage and booking form to always show what backend has.

final allCategoriesProvider =
    FutureProvider<List<ServiceCategoryEntity>>((ref) async {
  final dataSource = ref.watch(categoriesRemoteDataSourceProvider);
  try {
    final models = await dataSource.getCategories();
    if (models.isNotEmpty) {
      return models.map((m) => m.toEntity()).toList();
    }
  } catch (_) {}
  return _buildFallback();
});

// ── Client booking form categories (all active, no whitelist) ─────────────────
// Alias of allCategoriesProvider — kept as separate symbol so post_job_page
// can import it without changing its reference.

final clientBookingCategoriesProvider =
    FutureProvider<List<ServiceCategoryEntity>>((ref) async {
  return ref.watch(allCategoriesProvider.future);
});

// ── Standard services catalog for a category (STANDARD booking lane) ─────────
// Always fetched fresh from backend — never hardcoded — so admin price/name
// changes show up immediately for new bookings.

final standardServicesProvider = FutureProvider.autoDispose
    .family<List<StandardServiceEntity>, String>((ref, categoryId) async {
  final dataSource = ref.watch(categoriesRemoteDataSourceProvider);
  final models = await dataSource.getStandardServices(categoryId);
  return models.map((m) => m.toEntity()).toList();
});

// ── Fallback stubs (used when API is unreachable) ─────────────────────────────

/// Names only — these stubs exist so the picker is not empty when
/// `/categories` cannot be reached. They carry no id and no fee, so nothing
/// can actually be booked from them; the real records replace them as soon as
/// the request succeeds.
const _kFallbackNames = [
  'AC Technician',
  'Electrician',
  'Plumber',
  'Handyman',
  'Cleaner',
  'Painter',
  'Carpenter',
  'Pest Control',
  'Car Wash',
  'Gardener',
];

/// Categories whose LANE RULE must survive even the offline stub, so an
/// inspection-only category can never be rendered with Standard/Bidding just
/// because the category request failed. The fee still comes from the backend.
const _kFallbackInspectionOnlyNames = ['Appliances Repair'];

List<ServiceCategoryEntity> _buildFallback() {
  return [
    for (final name in _kFallbackNames)
      ServiceCategoryEntity(id: '', name: name),
    for (final name in _kFallbackInspectionOnlyNames)
      ServiceCategoryEntity(id: '', name: name, inspectionOnly: true),
  ];
}
