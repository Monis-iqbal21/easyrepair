class ServiceCategoryEntity {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  /// Fixed inspection-visit fee for this category, fetched from backend.
  /// Null means the inspection lane is not offered for this category.
  final double? inspectionFee;

  /// True when this category offers the INSPECTION lane and nothing else.
  ///
  /// The complement of [inspectionFee]'s rule: a null fee means "inspection
  /// not offered", this means "only inspection offered". The client hides the
  /// lane picker for such a category; the backend rejects any other lane, so
  /// this flag is a UI convenience over a server-owned rule, never the rule
  /// itself.
  final bool inspectionOnly;

  const ServiceCategoryEntity({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    this.inspectionFee,
    this.inspectionOnly = false,
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
      'appliances repair' || 'appliances' => '🧺',
      _ => '🛠️',
    };
  }
}
