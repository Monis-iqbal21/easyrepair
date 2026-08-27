import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/booking_entity.dart';
import '../providers/booking_providers.dart';
import 'detail/booking_detail_primitives.dart';

/// Compact state strip for an INSPECTION-lane booking, shown on the client's
/// Booking Detail / Track Worker pages.
///
/// Computed purely from [BookingEntity] fields — no network call — so it
/// renders instantly. No bidding wording ("Bid Accepted"/"Offer Accepted")
/// ever appears here.
class InspectionStatusStrip extends StatelessWidget {
  final BookingEntity booking;

  const InspectionStatusStrip({super.key, required this.booking});

  /// Whether this booking has a strip at all — INSPECTION lane, and in a
  /// state the strip has wording for. Lets the page decide layout without
  /// building the widget first.
  static bool hasContentFor(BookingEntity booking) {
    if (booking.lane != BookingLane.inspection) return false;
    return booking.status == BookingStatus.completed ||
        booking.inspectionDecisionStatus ==
            InspectionDecisionStatus.acceptedRepair ||
        booking.status == BookingStatus.inProgress ||
        booking.assignedWorker != null ||
        booking.status == BookingStatus.pending;
  }

  @override
  Widget build(BuildContext context) {
    if (booking.lane != BookingLane.inspection) return const SizedBox.shrink();

    final (text, icon, tone) = _stripFor(booking, context.l10n);
    if (text == null) return const SizedBox.shrink();

    return BookingStateBanner(
      key: const Key('inspection-status-strip'),
      icon: icon,
      title: text,
      tone: tone,
    );
  }

  (String?, IconData, BookingBannerTone) _stripFor(
    BookingEntity b,
    AppLocalizations l10n,
  ) {
    if (b.status == BookingStatus.completed) {
      if (b.inspectionDecisionStatus ==
          InspectionDecisionStatus.closedAfterInspection) {
        final fee = b.inspectionFeeSnapshot;
        return (
          // The fee is a formatted PKR amount, so it stays a placeholder
          // rather than being concatenated onto a translated sentence.
          fee != null
              ? l10n.inspStripClosedFeeOnlyWithAmount(formatPkr(fee))
              : l10n.inspStripClosedFeeOnly,
          Icons.info_outline_rounded,
          BookingBannerTone.info,
        );
      }
      return (
        l10n.inspStripRepairCompletedFeeWaived,
        Icons.check_circle_outline_rounded,
        BookingBannerTone.positive,
      );
    }
    if (b.inspectionDecisionStatus == InspectionDecisionStatus.acceptedRepair) {
      return (
        l10n.inspStripQuoteAcceptedFeeWaived,
        Icons.build_circle_outlined,
        BookingBannerTone.info,
      );
    }
    if (b.status == BookingStatus.inProgress) {
      if (b.inspectionReportSubmitted) {
        return (
          l10n.inspStripReportSubmitted,
          Icons.assignment_turned_in_outlined,
          BookingBannerTone.info,
        );
      }
      return (
        l10n.trackStepInspectionInProgress,
        Icons.search_rounded,
        BookingBannerTone.info,
      );
    }
    if (b.assignedWorker != null) {
      return (
        l10n.inspStripUstaadHired,
        Icons.handshake_outlined,
        BookingBannerTone.info,
      );
    }
    if (b.status == BookingStatus.pending) {
      return (
        l10n.inspStripBookedChooseUstaad,
        Icons.event_available_outlined,
        BookingBannerTone.info,
      );
    }
    return (null, Icons.info_outline_rounded, BookingBannerTone.info);
  }
}

/// "View Inspection Report" — shown wherever a report might exist (client
/// booking detail, track worker, worker job detail). Navigates to the
/// dedicated report page instead of duplicating diagnosis, parts and labour
/// inline. Renders nothing while no report has been submitted (an expected
/// 404), so callers can offer it unconditionally.
///
/// [route] carries whether the destination is the LIVE decision page or a
/// read-only view — the caller decides that explicitly; this widget never
/// infers it.
class ViewInspectionReportButton extends ConsumerWidget {
  final String bookingId;
  final String route;

  /// Overrides the shared "View Inspection Report" wording. Left null
  /// everywhere today — it cannot default to a translation because defaults
  /// must be const, so the fallback is resolved in [build] instead.
  final String? label;

  const ViewInspectionReportButton({
    super.key,
    required this.bookingId,
    required this.route,
    this.label,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(inspectionReportProvider(bookingId));
    final buttonLabel = label ?? context.l10n.discoveryViewInspectionReport;

    return reportAsync.when(
      data: (_) => BookingSecondaryButton(
        key: const Key('view-inspection-report-button'),
        label: buttonLabel,
        icon: Icons.description_outlined,
        onPressed: () => context.push(route),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
