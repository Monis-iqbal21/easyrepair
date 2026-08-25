import '../../../bookings/domain/entities/booking_entity.dart';

class BookingWizardInitialState {
  final BookingLane? lane;
  final BookingUrgency? urgency;
  final DateTime? date;
  final TimeSlot? timeSlot;
  final UrgentWindow? urgentWindow;

  const BookingWizardInitialState({
    this.lane,
    this.urgency,
    this.date,
    this.timeSlot,
    this.urgentWindow,
  });

  factory BookingWizardInitialState.fresh({required bool urgentEntry}) {
    return BookingWizardInitialState(
      urgency: urgentEntry ? BookingUrgency.urgent : null,
    );
  }
}

DateTime scheduledAtForTimeSlot(DateTime date, TimeSlot slot) {
  final hour = switch (slot) {
    TimeSlot.morning => 9,
    TimeSlot.afternoon => 12,
    TimeSlot.evening => 16,
    TimeSlot.night => 20,
  };
  return DateTime(date.year, date.month, date.day, hour);
}

enum BookingLaneDetailIssue {
  standardServiceRequired,
  inspectionDescriptionRequired,
  customTitleRequired,
  customVoiceRequired,
}

BookingLaneDetailIssue? validateBookingLaneDetails({
  required BookingLane? lane,
  required int standardServiceCount,
  required String inspectionDescription,
  required String customTitle,
  required bool hasVoiceNote,
}) {
  if (lane == BookingLane.standard && standardServiceCount == 0) {
    return BookingLaneDetailIssue.standardServiceRequired;
  }
  if (lane == BookingLane.inspection && inspectionDescription.trim().isEmpty) {
    return BookingLaneDetailIssue.inspectionDescriptionRequired;
  }
  if (lane == BookingLane.bidding && customTitle.trim().length <= 3) {
    return BookingLaneDetailIssue.customTitleRequired;
  }
  if (lane == BookingLane.bidding && !hasVoiceNote) {
    return BookingLaneDetailIssue.customVoiceRequired;
  }
  return null;
}
