import '../../../../l10n/app_localizations.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../domain/entities/worker_profile_entity.dart';
import '../providers/worker_job_providers.dart';

/// Display text for the Ustaad-facing enums.
///
/// These used to be `label` / `helperText` / `successMessage` getters on the
/// domain entities. The enum values and every raw API string are untouched —
/// only the words an Ustaad reads moved here, because those depend on the
/// selected language.

// ── Availability ────────────────────────────────────────────────────────────

String availabilityLabel(AppLocalizations l10n, AvailabilityStatus status) =>
    switch (status) {
      AvailabilityStatus.offline => l10n.workerOffline,
      AvailabilityStatus.online => l10n.workerOnline,
      AvailabilityStatus.busy => l10n.workerBusy,
    };

String availabilityHelper(AppLocalizations l10n, AvailabilityStatus status) =>
    switch (status) {
      AvailabilityStatus.offline => l10n.workerOfflineHelper,
      AvailabilityStatus.online => l10n.workerOnlineHelper,
      AvailabilityStatus.busy => l10n.workerBusyHelper,
    };

// ── Lifecycle actions (STANDARD / BIDDING lanes) ────────────────────────────

String lifecycleActionLabel(
  AppLocalizations l10n,
  WorkerLifecycleAction action,
) =>
    switch (action) {
      WorkerLifecycleAction.onMyWay => l10n.workerActionOnMyWay,
      WorkerLifecycleAction.arrived => l10n.workerActionArrived,
      WorkerLifecycleAction.start => l10n.workerActionStartJob,
      WorkerLifecycleAction.complete => l10n.workerActionCompleteJob,
    };

/// Shown in the success snackbar immediately after the action succeeds.
String lifecycleActionSuccess(
  AppLocalizations l10n,
  WorkerLifecycleAction action,
) =>
    switch (action) {
      WorkerLifecycleAction.onMyWay => l10n.workerSuccessOnTheWay,
      WorkerLifecycleAction.arrived => l10n.workerSuccessArrived,
      WorkerLifecycleAction.start => l10n.workerSuccessJobStarted,
      WorkerLifecycleAction.complete => l10n.workerSuccessJobCompleted,
    };

// ── Inspection-lane actions ─────────────────────────────────────────────────

String inspectionActionLabel(
  AppLocalizations l10n,
  InspectionWorkerAction action,
) =>
    switch (action) {
      InspectionWorkerAction.onMyWay => l10n.workerActionOnMyWay,
      InspectionWorkerAction.arrived => l10n.workerActionArrived,
      InspectionWorkerAction.startInspection => l10n.workerActionStartInspection,
      InspectionWorkerAction.startWork => l10n.workerActionStartWork,
      InspectionWorkerAction.fillReport => l10n.workerActionFillReport,
      InspectionWorkerAction.waitingForDecision =>
        l10n.workerActionWaitingForClient,
      InspectionWorkerAction.complete => l10n.workerActionCompleteJob,
    };

/// Empty for the two actions that navigate instead of completing in place.
String inspectionActionSuccess(
  AppLocalizations l10n,
  InspectionWorkerAction action,
) =>
    switch (action) {
      InspectionWorkerAction.onMyWay => l10n.workerSuccessOnTheWay,
      InspectionWorkerAction.arrived => l10n.workerSuccessArrived,
      InspectionWorkerAction.startInspection =>
        l10n.workerSuccessInspectionStarted,
      InspectionWorkerAction.startWork => l10n.workerSuccessWorkStarted,
      InspectionWorkerAction.fillReport => '',
      InspectionWorkerAction.waitingForDecision => '',
      InspectionWorkerAction.complete => l10n.workerSuccessJobCompleted,
    };

// ── Ongoing job status ──────────────────────────────────────────────────────

/// [rawStatus] is the backend token (ACCEPTED, EN_ROUTE, …). Anything the app
/// does not recognise is returned untouched rather than machine-translated.
String ongoingJobStatusLabel(AppLocalizations l10n, String rawStatus) =>
    switch (rawStatus.toUpperCase()) {
      'ACCEPTED' => l10n.bookingStatusAssigned,
      'EN_ROUTE' => l10n.workerStatusOnTheWay,
      'IN_PROGRESS' => l10n.jobStatusInProgress,
      _ => rawStatus,
    };

// ── Inspection fee ──────────────────────────────────────────────────────────

/// Null when no inspection is involved, so callers render nothing.
String? workerInspectionFeeLabel(AppLocalizations l10n, bool? feePaid) =>
    switch (feePaid) {
      true => l10n.inspectionFeePaid,
      false => l10n.inspectionFeeNotPaid,
      null => null,
    };

// ── Job-list filters ────────────────────────────────────────────────────────

String workerJobFilterLabel(AppLocalizations l10n, WorkerJobFilter filter) =>
    switch (filter) {
      WorkerJobFilter.all => l10n.filterAll,
      WorkerJobFilter.active => l10n.workerActive,
      // Same "My Offers" wording NewJobFilter.myBids already uses — same
      // concept (jobs this worker placed a bid/offer on).
      WorkerJobFilter.applied => l10n.workerFilterMyOffers,
      WorkerJobFilter.completed => l10n.bookingStatusCompleted,
      WorkerJobFilter.cancelled => l10n.workerFilterCancelled,
    };

String newJobFilterLabel(AppLocalizations l10n, NewJobFilter filter) =>
    switch (filter) {
      NewJobFilter.all => l10n.workerFilterAllWork,
      NewJobFilter.myBids => l10n.workerFilterMyOffers,
      NewJobFilter.notBidYet => l10n.workerFilterNoOfferSent,
    };
