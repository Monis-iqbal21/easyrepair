import 'booking_entity.dart';

/// Input model for creating a new booking.
/// Keeps the domain layer free from JSON/Dio dependencies.
class CreateBookingRequest {
  final String serviceCategory;
  final BookingUrgency urgency;
  final TimeSlot? timeSlot;
  final UrgentWindow? urgentWindow;
  final DateTime? scheduledAt;
  final String? title;
  final String? description;
  final String addressLine;
  final String? city;
  final double? latitude;
  final double? longitude;
  final bool inspection;
  final BookingLane lane;
  final String? standardServiceId;
  final List<String> standardServiceIds;

  /// Optional: the id of one of this client's OWN previously completed
  /// inspection bookings, whose report they chose to attach to this new
  /// BIDDING job as read-only context for bidders. Fully re-validated
  /// server-side (ownership, completion, category); omitting it leaves
  /// booking creation behaving exactly as before.
  final String? attachedInspectionBookingId;

  const CreateBookingRequest({
    required this.serviceCategory,
    required this.urgency,
    this.timeSlot,
    this.urgentWindow,
    this.scheduledAt,
    this.title,
    this.description,
    required this.addressLine,
    this.city,
    this.latitude,
    this.longitude,
    this.inspection = false,
    this.lane = BookingLane.bidding,
    this.standardServiceId,
    this.standardServiceIds = const [],
    this.attachedInspectionBookingId,
  });
}
