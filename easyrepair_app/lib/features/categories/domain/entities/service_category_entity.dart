import '../../../bookings/domain/entities/booking_entity.dart' show BookingLane;

class ServiceCategoryEntity {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  /// Fixed inspection-visit fee for this category, fetched from backend.
  /// Null means the inspection lane is not offered for this category.
  final double? inspectionFee;

  /// The ONE lane this category offers, when it is restricted to a single
  /// lane. Null means unrestricted, and the lanes are decided the way they
  /// always were.
  ///
  /// Backend truth (`ServiceCategory.soleLane`). The client renders only this
  /// lane, but the backend rejects any other lane outright, so this is a UI
  /// convenience over a server-owned rule and never the rule itself.
  final BookingLane? soleLane;

  const ServiceCategoryEntity({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    this.inspectionFee,
    this.soleLane,
  });

  /// Mirrors the server's `assertLaneAllowed`: an unrestricted category allows
  /// every lane, a restricted one allows only its [soleLane].
  ///
  /// This is the whole restriction rule. Whether INSPECTION is offered on an
  /// UNrestricted category still comes from [inspectionFee], and whether
  /// STANDARD is, from its fixed-price catalog — exactly as before.
  bool allowsLane(BookingLane lane) => soleLane == null || soleLane == lane;

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
