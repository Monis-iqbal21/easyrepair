import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/booking_entity.dart';

/// How far along a single timeline step is.
enum BookingTimelineStepState {
  /// Already happened.
  complete,

  /// Happening right now — exactly one step can be current, and only while
  /// the job is actually running.
  current,

  /// Has not happened yet.
  pending,
}

/// One rendered row of the Booking Detail progress timeline.
class BookingTimelineStep {
  final String label;
  final BookingTimelineStepState state;

  const BookingTimelineStep({required this.label, required this.state});
}

/// How many of the five lifecycle steps this booking has actually passed.
///
/// PURELY PRESENTATIONAL: it reads the status and the lifecycle timestamps the
/// backend already records, and decides nothing. No booking rule, transition
/// or eligibility check lives here.
///
/// A cancelled/rejected/expired booking no longer carries its progress in
/// `status`, so those cases fall back to the `acceptedAt` / `enRouteAt` /
/// `arrivedAt` / `startedAt` stamps to freeze the timeline exactly where the
/// job stopped. The stamps are never displayed — the timeline has no
/// per-step timestamps.
int bookingTimelineReachedSteps(BookingEntity booking) {
  // COMPLETED, AWAITING_CONFIRMATION and SETTLED all mean the work is done —
  // the same completed family the Bookings tab and the status badge use.
  if (booking.status.tab == BookingTab.completed) return 5;

  return switch (booking.status) {
    BookingStatus.inProgress => 4,
    BookingStatus.arrived => 3,
    BookingStatus.enRoute => 2,
    BookingStatus.accepted => 1,
    BookingStatus.pending => 0,
    // Terminal without completing: frozen wherever it actually got to.
    BookingStatus.cancelled ||
    BookingStatus.rejected ||
    BookingStatus.expired => booking.startedAt != null
        ? 4
        : booking.arrivedAt != null
        ? 3
        : booking.enRouteAt != null
        ? 2
        : booking.acceptedAt != null
        ? 1
        : 0,
    // Already handled by the completed-family check above.
    BookingStatus.completed ||
    BookingStatus.awaitingConfirmation ||
    BookingStatus.settled => 5,
  };
}

/// Whether an explanatory "waiting for an Ustaad" note belongs above the
/// steps.
///
/// An OPEN bidding job has nobody hired, so its five steps are all pending and
/// the note says why. It is deliberately not shown once the booking is over —
/// a cancelled or expired job is not waiting for anyone, and its own banner
/// already explains the outcome.
///
/// The steps themselves are ALWAYS rendered, in every lane and every status,
/// so the timeline never disappears from a booking.
bool bookingTimelineAwaitsWorker(BookingEntity booking) =>
    booking.lane == BookingLane.bidding &&
    booking.assignedWorker == null &&
    booking.status.tab != BookingTab.cancelled &&
    bookingTimelineReachedSteps(booking) == 0;

/// The five lane-specific step labels, in order.
///
/// STANDARD and BIDDING both describe repair work but name their first step
/// differently — a STANDARD job is confirmed at a fixed price, a BIDDING job
/// begins when an Ustaad is hired. INSPECTION says "inspection" throughout,
/// because that is genuinely all that happens on that booking.
List<String> bookingTimelineLabels(
  AppLocalizations l10n,
  BookingLane lane,
) {
  final first = switch (lane) {
    BookingLane.standard => l10n.timelineStepWorkConfirmed,
    BookingLane.inspection => l10n.timelineStepInspectionConfirmed,
    BookingLane.bidding => l10n.timelineStepUstaadHired,
  };
  final started = lane == BookingLane.inspection
      ? l10n.timelineStepInspectionStarted
      : l10n.timelineStepWorkStarted;
  final completed = lane == BookingLane.inspection
      ? l10n.timelineStepInspectionCompleted
      : l10n.timelineStepWorkCompleted;

  return [
    first,
    // Reuses the wording the Bookings card and the worker app already show
    // for these two states, so one job is never "On the way" in one place
    // and something else in another.
    l10n.bookingCardStatusOnTheWay,
    l10n.workerActionArrived,
    started,
    completed,
  ];
}

/// The timeline rows for a booking.
///
/// A step is `complete` once the booking has passed it, `current` for the one
/// it is sitting on, and `pending` otherwise. A booking that stopped without
/// finishing has NO current step — nothing is in progress on a cancelled job —
/// and a finished one has no current step either, because every step is done.
/// Later steps are never marked complete on the strength of an earlier one.
List<BookingTimelineStep> bookingTimelineSteps(
  AppLocalizations l10n,
  BookingEntity booking,
) {
  final labels = bookingTimelineLabels(l10n, booking.lane);
  final reached = bookingTimelineReachedSteps(booking);
  final hasCurrent =
      reached > 0 &&
      reached < labels.length &&
      booking.status.tab != BookingTab.cancelled;

  return [
    for (var i = 0; i < labels.length; i++)
      BookingTimelineStep(
        label: labels[i],
        state: i < reached - (hasCurrent ? 1 : 0)
            ? BookingTimelineStepState.complete
            : hasCurrent && i == reached - 1
            ? BookingTimelineStepState.current
            : BookingTimelineStepState.pending,
      ),
  ];
}
