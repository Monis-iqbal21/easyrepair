import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/booking_entity.dart';

/// Backend status enums → localized display text.
///
/// Lives in the presentation layer on purpose: `BookingStatus.raw` is the API
/// contract and must never change, while what the user reads depends entirely
/// on the language they picked. Keeping the mapping here is what stops a
/// translated string from leaking into a request body.

/// Client-facing label. Several backend states deliberately collapse into one
/// word — a client does not care whether the Ustaad is EN_ROUTE or ARRIVED,
/// only that the job is assigned.
String bookingStatusLabel(AppLocalizations l10n, BookingStatus status) {
  return switch (status) {
    BookingStatus.pending => l10n.bookingStatusLive,
    BookingStatus.accepted => l10n.bookingStatusAssigned,
    BookingStatus.enRoute => l10n.bookingStatusAssigned,
    BookingStatus.arrived => l10n.bookingStatusAssigned,
    BookingStatus.inProgress => l10n.bookingStatusLive,
    BookingStatus.completed => l10n.bookingStatusCompleted,
    BookingStatus.rejected => l10n.workerFilterCancelled,
    BookingStatus.cancelled => l10n.workerFilterCancelled,
    BookingStatus.expired => l10n.bookingStatusExpired,
  };
}

/// Badge for a job in the Ustaad's New Jobs list.
///
/// A PENDING job nobody has taken yet reads as "Live" (open for bids) rather
/// than "Pending", which would suggest the Ustaad is waiting on someone else.
String newJobStatusLabel(
  AppLocalizations l10n,
  BookingStatus status, {
  required bool hasAssignedWorker,
}) {
  if (status == BookingStatus.pending && !hasAssignedWorker) {
    return l10n.bookingStatusLive;
  }
  return workerJobStatusLabel(l10n, status);
}

/// Ustaad-facing label — the full lifecycle, since the worker acts on each step.
String workerJobStatusLabel(AppLocalizations l10n, BookingStatus status) {
  return switch (status) {
    BookingStatus.pending => l10n.bidStatusPending,
    BookingStatus.accepted => l10n.bookingStatusAssigned,
    BookingStatus.enRoute => l10n.jobStatusEnRoute,
    BookingStatus.arrived => l10n.workerActionArrived,
    BookingStatus.inProgress => l10n.jobStatusInProgress,
    BookingStatus.completed => l10n.bookingStatusCompleted,
    BookingStatus.rejected => l10n.bidStatusRejected,
    BookingStatus.cancelled => l10n.workerFilterCancelled,
    BookingStatus.expired => l10n.bookingStatusExpired,
  };
}
