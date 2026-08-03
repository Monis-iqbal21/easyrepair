import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/booking_entity.dart';
import '../providers/booking_providers.dart';

const _kPrimary = Color(0xFFDB6234);
const _kGray = Color(0xFF6B7280);
const _kSuccess = Color(0xFF22C55E);

/// Compact status strip shown at the top of the client's booking detail /
/// track-worker page for an INSPECTION-lane booking. Computed purely from
/// [BookingEntity] fields — no network call — so it renders instantly.
/// No bidding wording ("Bid Accepted"/"Offer Accepted") ever appears here.
class InspectionStatusStrip extends StatelessWidget {
  final BookingEntity booking;
  const InspectionStatusStrip({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    if (booking.lane != BookingLane.inspection) return const SizedBox.shrink();

    final (text, icon, color) = _stripFor(booking, context.l10n);
    if (text == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  (String?, IconData, Color) _stripFor(BookingEntity b, AppLocalizations l10n) {
    if (b.status == BookingStatus.completed) {
      if (b.inspectionDecisionStatus == InspectionDecisionStatus.closedAfterInspection) {
        final fee = b.inspectionFeeSnapshot;
        return (
          // The fee is a formatted PKR amount, so it stays a placeholder rather
          // than being concatenated onto a translated sentence.
          fee != null
              ? l10n.inspStripClosedFeeOnlyWithAmount(formatPkr(fee))
              : l10n.inspStripClosedFeeOnly,
          Icons.info_outline_rounded,
          const Color(0xFF2563EB),
        );
      }
      return (l10n.inspStripRepairCompletedFeeWaived, Icons.check_circle_outline_rounded, _kSuccess);
    }
    if (b.inspectionDecisionStatus == InspectionDecisionStatus.acceptedRepair) {
      return (l10n.inspStripQuoteAcceptedFeeWaived, Icons.build_circle_outlined, _kPrimary);
    }
    if (b.status == BookingStatus.inProgress) {
      if (b.inspectionReportSubmitted) {
        return (
          l10n.inspStripReportSubmitted,
          Icons.assignment_turned_in_outlined,
          _kPrimary,
        );
      }
      return (l10n.trackStepInspectionInProgress, Icons.search_rounded, _kPrimary);
    }
    if (b.assignedWorker != null) {
      return (l10n.inspStripUstaadHired, Icons.handshake_outlined, _kPrimary);
    }
    if (b.status == BookingStatus.pending) {
      return (l10n.inspStripBookedChooseUstaad, Icons.event_available_outlined, _kGray);
    }
    return (null, Icons.info_outline_rounded, _kGray);
  }
}

/// "View Inspection Report" button — shown wherever a report might exist
/// (client booking detail, track worker, worker job detail). Navigates to the
/// dedicated [InspectionReportPage] instead of rendering the report inline.
/// Renders nothing while no report has been submitted yet (an expected 404).
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
      data: (_) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 16),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.push(route),
            icon: const Icon(Icons.description_outlined, size: 17),
            label: Text(buttonLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kPrimary,
              side: const BorderSide(color: _kPrimary),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
