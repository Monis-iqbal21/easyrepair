class ServiceCategoryEntity {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;

  const ServiceCategoryEntity({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
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
      'cleaner' || 'cleaning' => '🧹',
      _ => '🛠️',
    };
  }
}
