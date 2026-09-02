import '../../../bookings/domain/entities/booking_entity.dart' show BookingLane;

class ServiceCategoryEntity {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  /// Fixed inspection-visit fee for this category, fetched from backend.
  /// Null means the inspection lane is not offered for this category.
  final double? inspectionFee;

  /// LEGACY restriction: this category offers the INSPECTION lane and nothing
  /// else. Superseded by [soleLane] but still sent by the backend, so an older
  /// APK keeps working. Consulted only when [soleLane] is null.
  final bool inspectionOnly;

  /// The ONE lane this category offers, when it is restricted to a single
  /// lane. Null means fall through to [inspectionOnly].
  ///
  /// Backend truth (`ServiceCategory.soleLane`). The client renders only the
  /// resolved lane, but the backend rejects any other lane outright, so this
  /// is a UI convenience over a server-owned rule and never the rule itself.
  final BookingLane? soleLane;

  const ServiceCategoryEntity({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    this.inspectionFee,
    this.inspectionOnly = false,
    this.soleLane,
  });

  /// The single lane this category is restricted to, or null when it is not
  /// restricted at all.
  ///
  /// Mirrors the server's `resolveSoleLane` exactly:
  ///
  ///   1. [soleLane] set      → that lane, and nothing else.
  ///   2. else [inspectionOnly] → INSPECTION only (legacy behaviour).
  ///   3. else                → unrestricted.
  BookingLane? get effectiveSoleLane {
    if (soleLane != null) return soleLane;
    if (inspectionOnly) return BookingLane.inspection;
    return null;
  }

  /// Mirrors the server's `assertLaneAllowed`: an unrestricted category allows
  /// every lane, a restricted one allows only its [effectiveSoleLane].
  ///
  /// This is the whole restriction rule. Whether INSPECTION is offered on an
  /// UNrestricted category still comes from [inspectionFee], and whether
  /// STANDARD is, from its fixed-price catalog — exactly as before.
  bool allowsLane(BookingLane lane) {
    final sole = effectiveSoleLane;
    return sole == null || sole == lane;
  }

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
