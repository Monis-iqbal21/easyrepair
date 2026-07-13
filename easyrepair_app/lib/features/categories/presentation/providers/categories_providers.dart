import 'package:flutter/material.dart';
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

List<ServiceCategoryEntity> _buildFallback() {
  return _kFallbackNames
      .map((name) => ServiceCategoryEntity(id: '', name: name))
      .toList();
}

// ── Color lookup helpers (kept for post_job_page compatibility) ───────────────

Color categoryBgColor(String name) {
  return switch (name.toLowerCase()) {
    'ac technician' => const Color(0xFFE8F4F8),
    'electrician'   => const Color(0xFFFFF8E1),
    'plumber'       => const Color(0xFFE8F5E9),
    'handyman'      => const Color(0xFFF3E5F5),
    'painter'       => const Color(0xFFFCE4EC),
    'carpenter'     => const Color(0xFFEFEBE9),
    'cleaner' || 'cleaning' => const Color(0xFFFFF3E0),
    'pest control'          => const Color(0xFFE8F5E9),
    'car wash'              => const Color(0xFFE3F2FD),
    'gardener'              => const Color(0xFFE8F5E9),
    _                       => const Color(0xFFF0F0F0),
  };
}

Color categoryEmojiBgColor(String name) {
  return switch (name.toLowerCase()) {
    'ac technician'         => const Color(0xFFB2DFF0),
    'electrician'           => const Color(0xFFFFECB3),
    'plumber'               => const Color(0xFFC8E6C9),
    'handyman'              => const Color(0xFFE1BEE7),
    'painter'               => const Color(0xFFF8BBD0),
    'carpenter'             => const Color(0xFFD7CCC8),
    'cleaner' || 'cleaning' => const Color(0xFFFFE0B2),
    'pest control'          => const Color(0xFFC8E6C9),
    'car wash'              => const Color(0xFFBBDEFB),
    'gardener'              => const Color(0xFFA5D6A7),
    _                       => const Color(0xFFDDDDDD),
  };
}
