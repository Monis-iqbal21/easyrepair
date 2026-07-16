import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/inspection_report_entity.dart';
import '../providers/booking_providers.dart';

const _kPrimary = Color(0xFFDB6234);
const _kPrimaryLight = Color(0xFFF5E8E0);
const _kDark = Color(0xFF1A1A1A);
const _kGray = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kSuccess = Color(0xFF22C55E);
const _kError = Color(0xFFEF4444);

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
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }

  (String?, IconData, Color) _stripFor(BookingEntity b) {
    if (b.status == BookingStatus.completed) {
      if (b.inspectionDecisionStatus == InspectionDecisionStatus.closedAfterInspection) {
        return ('Closed after inspection', Icons.info_outline_rounded, const Color(0xFF2563EB));
      }
      return ('Completed', Icons.check_circle_outline_rounded, _kSuccess);
    }
    if (b.inspectionDecisionStatus == InspectionDecisionStatus.acceptedRepair) {
      return ('Quote accepted — repair in progress', Icons.build_circle_outlined, _kPrimary);
    }
    if (b.status == BookingStatus.inProgress) {
      if (b.inspectionReportSubmitted) {
        return ('Report submitted — awaiting your decision', Icons.assignment_turned_in_outlined, _kPrimary);
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

/// Full inspection report view + client decision buttons. Fetches the report
/// via [inspectionReportProvider]; renders nothing while no report has been
/// submitted yet (a 404 from the backend, expected during inspection).
class InspectionReportSection extends ConsumerWidget {
  final String bookingId;
  const InspectionReportSection({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(inspectionReportProvider(bookingId));

    return reportAsync.when(
      data: (report) => _ReportCard(bookingId: bookingId, report: report),
      loading: () => const SizedBox.shrink(),
      // No report submitted yet is an expected 404 — render nothing rather
      // than an error screen.
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _ReportCard extends ConsumerWidget {
  final String bookingId;
  final InspectionReportEntity report;
  const _ReportCard({required this.bookingId, required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPending = report.decisionStatus == InspectionDecisionStatus.pendingClientDecision;
    final isDeciding = ref.watch(inspectionDecisionNotifierProvider).isLoading;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_turned_in_rounded, size: 18, color: _kSuccess),
              const SizedBox(width: 8),
              const Text(
                'Report Submitted',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kDark),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _row('Issue found', report.issueFound),
          _row('Recommended repair', report.recommendedRepair),
          if (report.notes != null && report.notes!.isNotEmpty)
            _row('Notes', report.notes!),
          if (report.photos.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Photos', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _kGray)),
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: report.photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(report.photos[i].url, width: 72, height: 72, fit: BoxFit.cover),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (report.partsNeeded && report.parts.isNotEmpty) ...[
            const Text('Parts', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _kGray)),
            const SizedBox(height: 6),
            ...report.parts.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${p.name} x${p.quantity}${p.warranty != null && p.warranty!.isNotEmpty ? ' · ${p.warranty}' : ''}',
                        style: const TextStyle(fontSize: 13, color: _kDark),
                      ),
                    ),
                    Text('Rs ${p.lineTotal.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kDark)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _kPrimaryLight, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _summaryLine('Parts total', report.partsTotal),
                _summaryLine('Labour', report.labourCost),
                if (report.inspectionFeeSnapshot != null)
                  _summaryLine('Inspection fee already paid', report.inspectionFeeSnapshot!, muted: true),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Repair quote', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _kDark)),
                    Text('Rs ${report.repairQuoteTotal.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _kPrimary)),
                  ],
                ),
                if (report.inspectionFeeSnapshot != null) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Total if you continue repair = Rs ${(report.repairQuoteTotal + report.inspectionFeeSnapshot!).toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 11.5, color: _kGray),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isPending) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isDeciding ? null : () => _decide(context, ref, accept: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: isDeciding
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Accept Quote & Continue Repair', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: isDeciding ? null : () => _decide(context, ref, accept: false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPrimary,
                  side: const BorderSide(color: _kPrimary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Close After Inspection', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kGray)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13.5, color: _kDark, height: 1.4)),
        ],
      ),
    );
  }

  Widget _summaryLine(String label, double value, {bool muted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: muted ? _kSuccess : _kGray)),
          Text(
            'Rs ${value.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: muted ? _kSuccess : _kDark),
          ),
        ],
      ),
    );
  }

  Future<void> _decide(BuildContext context, WidgetRef ref, {required bool accept}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          accept ? 'Accept quote & continue repair?' : 'Close after inspection?',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          accept
              ? 'The same Ustaad will continue the repair. The final amount will include the repair quote.'
              : 'Only the inspection fee will be charged. The job will be marked completed.',
          style: const TextStyle(color: _kGray, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _kGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final notifier = ref.read(inspectionDecisionNotifierProvider.notifier);
      if (accept) {
        await notifier.acceptQuote(bookingId);
      } else {
        await notifier.closeAfterInspection(bookingId);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'Quote accepted — repair in progress.' : 'Closed after inspection.'),
            backgroundColor: _kPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is Failure ? e.message : 'Action failed. Try again.'),
            backgroundColor: _kError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
