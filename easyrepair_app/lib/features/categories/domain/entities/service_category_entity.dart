class ServiceCategoryEntity {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  /// Fixed inspection-visit fee for this category, fetched from backend.
  /// Null means the inspection lane is not offered for this category.
  final double? inspectionFee;

  const ServiceCategoryEntity({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    this.inspectionFee,
  });

  /// Returns the emoji that represents this category for display.
  String get emoji {
    return switch (name.toLowerCase()) {
      'ac technician' || 'ac' => '❄️',
      'electrician' => '⚡',
      'plumber' || 'plumbing' => '🔧',
      'handyman' => '🔨',
      'painter' || 'painting' => '🎨',
      'carpenter' || 'carpentry' => '🪚',
      'cleaner' || 'cleaning' || 'deep cleaning' => '🧹',
      _ => '🛠️',
    };
  }
}
