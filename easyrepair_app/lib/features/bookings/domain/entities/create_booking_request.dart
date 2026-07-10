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
  });
}
