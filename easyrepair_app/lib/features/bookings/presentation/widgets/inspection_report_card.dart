import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/currency_utils.dart';
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

    final (text, icon, color) = _stripFor(booking);
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

  (String?, IconData, Color) _stripFor(BookingEntity b) {
    if (b.status == BookingStatus.completed) {
      if (b.inspectionDecisionStatus == InspectionDecisionStatus.closedAfterInspection) {
        final fee = b.inspectionFeeSnapshot;
        return (
          'Closed after inspection — client pays inspection fee only'
              '${fee != null ? ': ${formatPkr(fee)}' : '.'}',
          Icons.info_outline_rounded,
          const Color(0xFF2563EB),
        );
      }
      return ('Repair completed — inspection fee waived.', Icons.check_circle_outline_rounded, _kSuccess);
    }
    if (b.inspectionDecisionStatus == InspectionDecisionStatus.acceptedRepair) {
      return ('Quote accepted — inspection fee waived. Repair in progress.', Icons.build_circle_outlined, _kPrimary);
    }
    if (b.status == BookingStatus.inProgress) {
      if (b.inspectionReportSubmitted) {
        return (
          'Inspection report submitted — review quote to continue repair or close after inspection.',
          Icons.assignment_turned_in_outlined,
          _kPrimary,
        );
      }
      return ('Inspection in progress', Icons.search_rounded, _kPrimary);
    }
    if (b.assignedWorker != null) {
      return ('Ustaad hired', Icons.handshake_outlined, _kPrimary);
    }
    if (b.status == BookingStatus.pending) {
      return ('Inspection booked — choose an Ustaad', Icons.event_available_outlined, _kGray);
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

  const ViewInspectionReportButton({
    super.key,
    required this.bookingId,
    required this.route,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(inspectionReportProvider(bookingId));

    return reportAsync.when(
      data: (_) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 16),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.push(route),
            icon: const Icon(Icons.description_outlined, size: 17),
            label: const Text('View Inspection Report'),
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
