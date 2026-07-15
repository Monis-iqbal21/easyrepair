import 'booking_entity.dart';

class UpdateBookingRequest {
  final String bookingId;
  final String? serviceCategory;
  final String? title;
  final String? description;
  final BookingUrgency? urgency;
  final TimeSlot? timeSlot;
  final UrgentWindow? urgentWindow;
  final DateTime? scheduledAt;
  final String? addressLine;
  final String? city;
  final double? latitude;
  final double? longitude;
  final bool? inspection;
  /// Replaces the STANDARD-lane sub-service selection. Only meaningful when
  /// the booking being edited is already STANDARD lane — the backend rejects
  /// this on any other lane.
  final List<String>? standardServiceIds;

  const UpdateBookingRequest({
    required this.bookingId,
    this.serviceCategory,
    this.title,
    this.description,
    this.urgency,
    this.timeSlot,
    this.urgentWindow,
    this.scheduledAt,
    this.addressLine,
    this.city,
    this.latitude,
    this.longitude,
    this.inspection,
    this.standardServiceIds,
  });
}

class ReviewRequest {
  final String bookingId;
  final int rating;
  final String? comment;

  const ReviewRequest({
    required this.bookingId,
    required this.rating,
    this.comment,
  });
}
