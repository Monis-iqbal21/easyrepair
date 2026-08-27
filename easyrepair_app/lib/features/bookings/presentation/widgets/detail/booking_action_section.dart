import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/errors/failure_messages.dart';
import '../../../../../core/l10n/l10n_extensions.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../domain/entities/booking_entity.dart';
import '../../pages/choose_ustaad_page.dart';
import '../../pages/track_worker_page.dart';
import '../../pages/worker_discovery_map_page.dart';
import '../../providers/booking_providers.dart';
import '../client_cancel_reason_sheet.dart';
import 'booking_detail_primitives.dart';

/// Everything the client can DO right now.
///
/// EN_ROUTE / ARRIVED / IN_PROGRESS are worker-owned transitions, so no
/// control here mutates them — where the job has reached is stated once, by
/// the timeline above. Every action maps to an endpoint the client is
/// authorised to call, gated by the same predicate the Bookings tab uses.
class BookingActionSection extends ConsumerWidget {
  final BookingEntity booking;

  const BookingActionSection({super.key, required this.booking});

  /// Whether this booking has any action to render. Purely synchronous, so
  /// the page can lay out around it without building it first.
  static bool hasContentFor(BookingEntity booking) {
    final canHire =
        booking.status == BookingStatus.pending &&
        booking.assignedWorker == null;
    return canHire || booking.canClientTrackWorker || booking.canClientCancel;
  }

  /// Where "View Inspection Report" should navigate for this booking.
  ///
  /// A booking that merely LINKS to (a repair spawned by Find Other Ustaad)
  /// or ATTACHES (a bidding job carrying a past report as context) an
  /// inspection is never the place to decide on it — acting there would
  /// mutate a DIFFERENT booking's inspection. Read-only mode is passed
  /// explicitly rather than relying on the report's decisionStatus happening
  /// not to be pending.
  static String inspectionReportRoute(BookingEntity booking) =>
      booking.ownsLiveInspectionReport
      ? '/client/booking/${booking.id}/inspection-report'
      : '/client/booking/${booking.id}/inspection-report?readOnly=1';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = <Widget>[];

    // ── Hiring ─────────────────────────────────────────────────────────────
    if (booking.status == BookingStatus.pending &&
        booking.assignedWorker == null) {
      children.add(_hireAction(context));
    }

    // ── Live job actions ───────────────────────────────────────────────────
    if (booking.canClientTrackWorker) {
      children.add(
        BookingPrimaryButton(
          key: const Key('track-worker-button'),
          label: context.l10n.bookingTrackWorker,
          icon: Icons.navigation_rounded,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TrackWorkerPage(bookingId: booking.id),
            ),
          ),
        ),
      );
    }

    // ── Editing ────────────────────────────────────────────────────────────
    if (booking.status == BookingStatus.pending &&
        booking.assignedWorker == null) {
      children.add(
        BookingSecondaryButton(
          key: const Key('edit-booking-button'),
          label: context.l10n.postJobEditBooking,
          icon: Icons.edit_outlined,
          onPressed: () =>
              context.push('/client/post-job?editId=${booking.id}'),
        ),
      );
    }

    // ── Cancellation ───────────────────────────────────────────────────────
    // Eligibility is unchanged and backend-authoritative (PENDING or
    // ACCEPTED only) — the redesign moves the button, never the rule.
    if (booking.canClientCancel) {
      children.add(
        BookingSecondaryButton(
          key: const Key('cancel-booking-button'),
          label: context.l10n.bookingCancelBooking,
          icon: Icons.close_rounded,
          destructive: true,
          onPressed: () => _confirmCancel(context, ref),
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          children[i],
        ],
      ],
    );
  }

  /// One hiring CTA per lane — never both.
  ///
  /// BIDDING (including a "Find Other Ustaad" child job) goes to the bids /
  /// worker-discovery flow; STANDARD and INSPECTION go to direct selection,
  /// which is the only shape `POST /bookings/:id/assign` accepts.
  Widget _hireAction(BuildContext context) {
    final useBiddingFlow =
        booking.lane == BookingLane.bidding ||
        booking.isOpenForFindOtherUstaadBidding;

    if (useBiddingFlow) {
      return BookingPrimaryButton(
        key: const Key('find-workers-button'),
        label: context.l10n.cardFindWorkers,
        icon: Icons.groups_2_outlined,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => WorkerDiscoveryMapPage(booking: booking),
          ),
        ),
      );
    }

    return BookingPrimaryButton(
      key: const Key('choose-ustaad-button'),
      label: context.l10n.bookingChooseUstaad,
      icon: Icons.person_search_rounded,
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChooseUstaadPage(booking: booking),
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    try {
      final reason = await showClientCancelReasonSheet(
        context: context,
        hasAssignedWorker: booking.assignedWorker != null,
        onSubmit: (reason) => ref
            .read(bookingsNotifierProvider.notifier)
            .cancelBooking(booking.id, reason),
      );
      if (reason == null || !context.mounted) return;
      context.pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failureMessage(
              context.l10n,
              e,
              fallback: context.l10n.bookingCancelFailed,
            ),
          ),
          backgroundColor: context.semanticColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

/// EXPIRED — nobody was hired inside the live window.
class BookingExpiredSection extends ConsumerWidget {
  final String bookingId;

  const BookingExpiredSection({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(relistBookingNotifierProvider).isLoading;
    return BookingStateBanner(
      icon: Icons.hourglass_bottom_rounded,
      title: context.l10n.bookingJobExpired,
      body: context.l10n.bookingExpiredExplanation,
      tone: BookingBannerTone.attention,
      action: BookingPrimaryButton(
        key: const Key('make-live-again-button'),
        label: context.l10n.bookingMakeLiveAgain,
        icon: Icons.refresh_rounded,
        loading: isLoading,
        onPressed: () => _relist(context, ref),
      ),
    );
  }

  Future<void> _relist(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(relistBookingNotifierProvider.notifier).relist(bookingId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failureMessage(
              context.l10n,
              e,
              fallback: context.l10n.bookingMakeLiveFailed,
            ),
          ),
          backgroundColor: context.semanticColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

/// The assigned Ustaad cancelled and the booking is terminally CANCELLED —
/// the client may reopen it and hire someone else.
///
/// The cancelling Ustaad is excluded server-side (a BookingWorkerExclusion row
/// written by the cancel itself), and that exclusion is enforced by
/// nearby-worker search, the bids query AND `POST /bookings/:id/assign`, which
/// rejects an excluded worker outright. Nothing here re-implements it.
class BookingWorkerCancelledSection extends ConsumerWidget {
  final BookingEntity booking;

  const BookingWorkerCancelledSection({super.key, required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref
        .watch(reopenAfterWorkerCancellationNotifierProvider)
        .isLoading;
    final reason = booking.cancellationReason?.trim();

    return BookingStateBanner(
      key: const Key('worker-cancelled-section'),
      icon: Icons.person_off_outlined,
      title: context.l10n.bookingUstaadCancelledJob,
      body: reason != null && reason.isNotEmpty
          ? context.l10n.bookingReasonPrefix(reason)
          : null,
      tone: BookingBannerTone.critical,
      action: BookingPrimaryButton(
        key: const Key('hire-new-ustaad-button'),
        label: context.l10n.bookingHireNewUstaad,
        icon: Icons.person_search_rounded,
        loading: isLoading,
        onPressed: () => _reopen(context, ref),
      ),
    );
  }

  Future<void> _reopen(BuildContext context, WidgetRef ref) async {
    try {
      final updated = await ref
          .read(reopenAfterWorkerCancellationNotifierProvider.notifier)
          .reopen(booking.id);
      if (!context.mounted) return;
      // Same lane rule the action section uses for a fresh PENDING booking.
      final useBiddingFlow =
          updated.lane == BookingLane.bidding ||
          updated.isOpenForFindOtherUstaadBidding;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => useBiddingFlow
              ? WorkerDiscoveryMapPage(booking: updated)
              : ChooseUstaadPage(booking: updated),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failureMessage(
              context.l10n,
              e,
              fallback: context.l10n.bookingFindAnotherUstaadFailed,
            ),
          ),
          backgroundColor: context.semanticColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

/// A booking that ended without the work happening — cancelled by the client,
/// or rejected — with the reason that was recorded.
///
/// The worker-cancelled case has its own section with a rehire CTA
/// ([BookingWorkerCancelledSection]) and is deliberately not handled here.
class BookingCancelledNotice extends StatelessWidget {
  final BookingEntity booking;

  const BookingCancelledNotice({super.key, required this.booking});

  /// Terminal without work, and not the worker-cancelled shape.
  static bool hasContentFor(BookingEntity booking) {
    final isCancelledShape =
        booking.status == BookingStatus.cancelled ||
        booking.status == BookingStatus.rejected;
    return isCancelledShape &&
        booking.cancelledByRole != CancelledByRole.worker;
  }

  @override
  Widget build(BuildContext context) {
    final reason = booking.cancellationReason?.trim();
    return BookingStateBanner(
      key: const Key('booking-cancelled-notice'),
      icon: Icons.cancel_outlined,
      title: context.l10n.workerFilterCancelled,
      body: reason != null && reason.isNotEmpty
          ? context.l10n.bookingReasonPrefix(reason)
          : null,
      tone: BookingBannerTone.critical,
    );
  }
}

/// The previously-assigned Ustaad cancelled and the backend already put the
/// booking back to PENDING. The hire CTA is the ordinary one in
/// [BookingActionSection]; this only explains why the booking is open again.
class BookingPreviousUstaadCancelledNotice extends StatelessWidget {
  final String reason;
  final String? workerName;

  const BookingPreviousUstaadCancelledNotice({
    super.key,
    required this.reason,
    this.workerName,
  });

  @override
  Widget build(BuildContext context) {
    final name = workerName?.trim();
    return BookingStateBanner(
      key: const Key('previous-ustaad-cancelled-notice'),
      icon: Icons.info_outline_rounded,
      title: name != null && name.isNotEmpty
          ? context.l10n.bookingPreviousUstaadCancelledNamed(name)
          : context.l10n.bookingPreviousUstaadCancelled,
      body: reason,
      tone: BookingBannerTone.attention,
    );
  }
}
