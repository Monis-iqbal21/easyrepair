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
