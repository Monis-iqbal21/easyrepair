import 'booking_entity.dart';

class UpdateBookingRequest {
  final String bookingId;
  final String? serviceCategory;
  final String? title;
  final String? description;
  final BookingUrgency? urgency;
  final TimeSlot? timeSlot;
  final DateTime? scheduledAt;
  final String? addressLine;
  final String? city;
  final double? latitude;
  final double? longitude;

  const UpdateBookingRequest({
    required this.bookingId,
    this.serviceCategory,
    this.title,
    this.description,
    this.urgency,
    this.timeSlot,
    this.scheduledAt,
    this.addressLine,
    this.city,
    this.latitude,
    this.longitude,
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
