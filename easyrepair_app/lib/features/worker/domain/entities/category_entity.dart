enum ServiceAvailabilityStatus {
  active,
  inactive,
  soon;

  static ServiceAvailabilityStatus fromApi(String? value) {
    return switch (value) {
      null || 'ACTIVE' => ServiceAvailabilityStatus.active,
      'INACTIVE' => ServiceAvailabilityStatus.inactive,
      'SOON' => ServiceAvailabilityStatus.soon,
      // Unknown future states fail closed for new Worker selection.
      _ => ServiceAvailabilityStatus.inactive,
    };
  }
}

class CategoryEntity {
  final String id;
  final String name;
  final String? iconUrl;
  final ServiceAvailabilityStatus availabilityStatus;

  const CategoryEntity({
    required this.id,
    required this.name,
    this.iconUrl,
    this.availabilityStatus = ServiceAvailabilityStatus.active,
  });
}
