import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/datasources/categories_remote_datasource.dart';
import '../../domain/entities/service_category_entity.dart';

// ── Client-facing whitelist ───────────────────────────────────────────────────
// Only these 4 are shown on the Book a Service form right now.
// Remove this list (or make it empty) to show all active categories.
const _kClientBookingCategories = [
  'Plumber',
  'Electrician',
  'AC Technician',
  'Handyman',
];

// ── Color lookup for service cards ───────────────────────────────────────────

Color categoryBgColor(String name) {
  return switch (name.toLowerCase()) {
    'ac technician' => const Color(0xFFE8F4F8),
    'electrician'   => const Color(0xFFFFF8E1),
    'plumber'       => const Color(0xFFE8F5E9),
    'handyman'      => const Color(0xFFF3E5F5),
    'painter'       => const Color(0xFFFCE4EC),
    'carpenter'     => const Color(0xFFFFF3E0),
    'cleaner'       => const Color(0xFFE0F7FA),
    _               => const Color(0xFFF0F0F0),
  };
}

Color categoryEmojiBgColor(String name) {
  return switch (name.toLowerCase()) {
    'ac technician' => const Color(0xFFB2DFF0),
    'electrician'   => const Color(0xFFFFECB3),
    'plumber'       => const Color(0xFFC8E6C9),
    'handyman'      => const Color(0xFFE1BEE7),
    'painter'       => const Color(0xFFF8BBD9),
    'carpenter'     => const Color(0xFFFFCC80),
    'cleaner'       => const Color(0xFFB2EBF2),
    _               => const Color(0xFFDDDDDD),
  };
}

// ── Remote data source provider ───────────────────────────────────────────────

final categoriesRemoteDataSourceProvider =
    Provider<CategoriesRemoteDataSource>((ref) {
  return CategoriesRemoteDataSourceImpl(ref.watch(dioProvider));
});

// ── Client booking form categories (filtered to the 4 shown for now) ─────────
// Single flat FutureProvider — fetches from backend and filters to the
// whitelisted names in declared order. Falls back to stubs if the API
// is unreachable. No chained providers to avoid async ref.watch issues.

final clientBookingCategoriesProvider =
    FutureProvider<List<ServiceCategoryEntity>>((ref) async {
  final dataSource = ref.watch(categoriesRemoteDataSourceProvider);

  List<ServiceCategoryEntity> all;
  try {
    final models = await dataSource.getCategories();
    all = models.isNotEmpty
        ? models.map((m) => m.toEntity()).toList()
        : _buildFallback();
  } catch (_) {
    all = _buildFallback();
  }

  // Build an index by lowercase name for fast lookup.
  final byName = <String, ServiceCategoryEntity>{
    for (final c in all) c.name.toLowerCase(): c,
  };

  // Return whitelisted categories in declared order; fall back to a
  // stub (id='') for any name not yet found in the backend response.
  return _kClientBookingCategories.map((name) {
    return byName[name.toLowerCase()] ??
        ServiceCategoryEntity(id: '', name: name);
  }).toList();
});

// ── Hardcoded fallback (used when API is unreachable) ─────────────────────────

List<ServiceCategoryEntity> _buildFallback() {
  return _kClientBookingCategories
      .map((name) => ServiceCategoryEntity(id: '', name: name))
      .toList();
}
