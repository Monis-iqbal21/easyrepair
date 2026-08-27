import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/booking_entity.dart';

/// Display labels for booking enums.
///
/// These used to be `label` getters on the domain enums. The enum values and
/// their `raw` API forms are untouched — only the words shown to a user moved
/// here, because those depend on the selected language.

String timeSlotLabel(AppLocalizations l10n, TimeSlot slot) => switch (slot) {
  TimeSlot.morning => l10n.slotMorning,
  TimeSlot.afternoon => l10n.slotAfternoon,
  TimeSlot.evening => l10n.slotEvening,
  TimeSlot.night => l10n.slotNight,
};

/// Client-facing lane name. Shared by the Bookings card and Booking Detail so
/// a booking is never called "Bidding" on one screen and something else on
/// the other.
String bookingLaneLabel(AppLocalizations l10n, BookingLane lane) =>
    switch (lane) {
      BookingLane.standard => l10n.workerLevelStandard,
      BookingLane.inspection => l10n.postJobLaneInspectionTitle,
      BookingLane.bidding => l10n.bookingCardLaneBidding,
    };

/// THE schedule sentence for a booking — one rule, two verbosities.
///
/// URGENT bookings are described by their arrival window and never by a date;
/// NORMAL bookings by their date plus time slot. Booking Detail shows the full
/// weekday-and-year form, the Bookings card a compact one, but both take the
/// same branch for the same booking, so they can never tell different stories
/// about when the Ustaad is coming.
///
/// Returns null only when a NORMAL booking has no date at all — callers show
/// their own "not scheduled yet" wording.
String? bookingScheduleLabel(
  AppLocalizations l10n,
  BookingEntity booking, {
  bool compact = false,
}) {
  if (booking.urgency == BookingUrgency.urgent) {
    final window = booking.urgentWindow;
    return window == null
        ? l10n.postJobUrgent
        : urgentWindowLabel(l10n, window);
  }

  final date = booking.scheduledDate;
  if (date == null) return null;

  final now = DateTime.now();
  final isToday =
      date.year == now.year && date.month == now.month && date.day == now.day;
  final datePart = compact
      ? (isToday ? l10n.commonToday : DateFormat('d MMM').format(date))
      : DateFormat('EEE, d MMM yyyy').format(date);

  // Same separator the Bookings card has always used, so the compact form is
  // byte-identical to what that card rendered before this helper existed.
  final slot = booking.timeSlot;
  return slot == null ? datePart : '$datePart · ${timeSlotLabel(l10n, slot)}';
}

String urgentWindowLabel(AppLocalizations l10n, UrgentWindow window) =>
    switch (window) {
      UrgentWindow.within1Hour => l10n.urgentWithin1Hour,
      UrgentWindow.within2Hours => l10n.urgentWithin2Hours,
      UrgentWindow.within4Hours => l10n.urgentWithin4Hours,
    };

String bookingTabLabel(
  AppLocalizations l10n,
  BookingTab tab, {
  bool romanUrdu = false,
}) => switch (tab) {
  BookingTab.all => l10n.filterAll,
  BookingTab.live =>
    romanUrdu ? l10n.bookingCardRomanActiveFilter : l10n.workerActive,
  BookingTab.assigned => l10n.bookingStatusAssigned,
  BookingTab.completed =>
    romanUrdu ? l10n.workerComplete : l10n.bookingStatusCompleted,
  BookingTab.cancelled => l10n.workerFilterCancelled,
};

/// Badge derived from how many jobs an Ustaad has completed.
String workerLevelBadge(AppLocalizations l10n, int completedJobs) {
  if (completedJobs > 70) return l10n.workerLevelMaster;
  if (completedJobs > 50) return l10n.workerLevelElite;
  if (completedJobs > 30) return l10n.workerLevelProUstaad;
  if (completedJobs > 10) return l10n.workerLevelPro;
  return l10n.workerLevelStandard;
}

/// Client-facing inspection-fee wording.
///
/// Null when no inspection is involved, so callers render nothing. Mirrors
/// [BookingEntity.inspectionFeePaid], which the backend derives solely from
/// the ORIGINAL inspection work unit reaching COMPLETED.
String? inspectionFeeStatusLabel(AppLocalizations l10n, bool? feePaid) =>
    switch (feePaid) {
      true => l10n.inspectionFeePaid,
      false => l10n.inspectionFeeNotPaid,
      null => null,
    };
