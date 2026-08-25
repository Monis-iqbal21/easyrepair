import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/client/presentation/providers/booking_wizard_rules.dart';

void main() {
  group('fresh booking wizard', () {
    test('has no lane or scheduling selection', () {
      final state = BookingWizardInitialState.fresh(urgentEntry: false);

      expect(state.lane, isNull);
      expect(state.urgency, isNull);
      expect(state.date, isNull);
      expect(state.timeSlot, isNull);
      expect(state.urgentWindow, isNull);
    });

    test('24/7 entry selects only urgent, not an urgent window', () {
      final state = BookingWizardInitialState.fresh(urgentEntry: true);

      expect(state.urgency, BookingUrgency.urgent);
      expect(state.lane, isNull);
      expect(state.date, isNull);
      expect(state.timeSlot, isNull);
      expect(state.urgentWindow, isNull);
    });
  });

  group('lane detail rules', () {
    test('Inspection requires a problem description', () {
      expect(
        validateBookingLaneDetails(
          lane: BookingLane.inspection,
          standardServiceCount: 0,
          inspectionDescription: '   ',
          customTitle: '',
          hasVoiceNote: false,
        ),
        BookingLaneDetailIssue.inspectionDescriptionRequired,
      );
    });

    test('Custom Kaam requires title and then voice, but not photos', () {
      expect(
        validateBookingLaneDetails(
          lane: BookingLane.bidding,
          standardServiceCount: 0,
          inspectionDescription: '',
          customTitle: 'Leak',
          hasVoiceNote: false,
        ),
        BookingLaneDetailIssue.customVoiceRequired,
      );
      expect(
        validateBookingLaneDetails(
          lane: BookingLane.bidding,
          standardServiceCount: 0,
          inspectionDescription: '',
          customTitle: 'Leak',
          hasVoiceNote: true,
        ),
        isNull,
      );
    });
  });

  test('normal scheduling persists the selected date and slot start', () {
    final date = DateTime(2026, 8, 24);

    expect(
      scheduledAtForTimeSlot(date, TimeSlot.afternoon),
      DateTime(2026, 8, 24, 12),
    );
    expect(
      scheduledAtForTimeSlot(date, TimeSlot.evening),
      DateTime(2026, 8, 24, 16),
    );
  });
}
