import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/inspection_report_entity.dart';
import '../providers/booking_providers.dart';
import '../widgets/media_attachment_widgets.dart';

const _kPrimary = Color(0xFFDB6234);
const _kPrimaryLight = Color(0xFFF5E8E0);
const _kDark = Color(0xFF1A1A1A);
const _kGray = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kSuccess = Color(0xFF22C55E);
const _kError = Color(0xFFEF4444);
const _kBg = Color(0xFFF9FAFB);

/// Full inspection report view — issue found, recommended repair, parts,
/// labour, repair quote total, photos, notes. Reused for both the client
/// (with Accept/Close decision buttons while pending) and the assigned
/// worker (read-only, [showDecisionButtons] false) via role-aware routing.
///
/// Repair quote total = labour + parts only — the inspection fee is
/// deliberately never shown here: it's either waived (quote accepted) or
/// charged alone (closed after inspection), never combined with the repair
/// quote, so showing it inside the report would be misleading.
class InspectionReportPage extends ConsumerWidget {
  final String bookingId;
  final bool showDecisionButtons;

  const InspectionReportPage({
    super.key,
    required this.bookingId,
    required this.showDecisionButtons,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(inspectionReportProvider(bookingId));

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _kDark,
        title: const Text(
          'Inspection Report',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: SafeArea(
        child: reportAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.description_outlined, size: 40, color: _kGray),
                  const SizedBox(height: 12),
                  Text(
                    err is Failure ? err.message : 'Report not available yet.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _kGray, fontSize: 13.5),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(inspectionReportProvider(bookingId)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kPrimary,
                      side: const BorderSide(color: _kPrimary),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (report) => _ReportBody(
            bookingId: bookingId,
            report: report,
            showDecisionButtons: showDecisionButtons,
          ),
        ),
      ),
    );
  }
}

class _ReportBody extends ConsumerWidget {
  final String bookingId;
  final InspectionReportEntity report;
  final bool showDecisionButtons;

  const _ReportBody({
    required this.bookingId,
    required this.report,
    required this.showDecisionButtons,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPending = report.decisionStatus == InspectionDecisionStatus.pendingClientDecision;
    final isDeciding = ref.watch(inspectionDecisionNotifierProvider).isLoading;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DecisionBadge(decisionStatus: report.decisionStatus),
          const SizedBox(height: 14),
          if ((report.issueFound != null && report.issueFound!.isNotEmpty) ||
              (report.recommendedRepair != null && report.recommendedRepair!.isNotEmpty) ||
              (report.notes != null && report.notes!.isNotEmpty))
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (report.issueFound != null && report.issueFound!.isNotEmpty)
                    _row('Issue found', report.issueFound!),
                  if (report.recommendedRepair != null && report.recommendedRepair!.isNotEmpty)
                    _row('Recommended repair', report.recommendedRepair!),
                  if (report.notes != null && report.notes!.isNotEmpty)
                    _row('Notes', report.notes!, isLast: true),
                ],
              ),
            ),
          if (report.voiceNoteUrl != null) ...[
            const SizedBox(height: 12),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ustaad Voice Note',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _kGray),
                  ),
                  const SizedBox(height: 10),
                  WhatsAppVoiceNotePlayer(url: report.voiceNoteUrl),
                ],
              ),
            ),
          ],
          if (report.photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Photos', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _kGray)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 88,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: report.photos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(report.photos[i].url, width: 88, height: 88, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (report.partsNeeded && report.parts.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Parts', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _kGray)),
                  const SizedBox(height: 8),
                  ...report.parts.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${p.name} x${p.quantity}${p.warranty != null && p.warranty!.isNotEmpty ? ' · ${p.warranty}' : ''}',
                              style: const TextStyle(fontSize: 13.5, color: _kDark),
                            ),
                          ),
                          Text(formatPkr(p.lineTotal),
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _kDark)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Repair quote total = labour + parts only. The inspection fee is
          // never shown here — see file-level doc comment for why.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _kPrimaryLight, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                _summaryLine('Parts total', report.partsTotal),
                _summaryLine('Labour', report.labourCost),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Repair quote total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _kDark)),
                    Text(formatPkr(report.repairQuoteTotal),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: _kPrimary)),
                  ],
                ),
              ],
            ),
          ),
          if (showDecisionButtons && isPending) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isDeciding ? null : () => _decide(context, ref, accept: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
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
                  padding: const EdgeInsets.symmetric(vertical: 15),
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

  Widget _row(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kGray)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontSize: 14, color: _kDark, height: 1.45)),
        ],
      ),
    );
  }

  Widget _summaryLine(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: _kGray)),
          Text(
            formatPkr(value),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kDark),
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
              ? 'The same Ustaad will continue the repair. Inspection fee is waived — you\'ll only pay the repair quote.'
              : 'You\'ll only be charged the inspection fee. The job will be marked completed.',
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
        Navigator.of(context).pop();
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

class _DecisionBadge extends StatelessWidget {
  final InspectionDecisionStatus decisionStatus;
  const _DecisionBadge({required this.decisionStatus});

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (decisionStatus) {
      InspectionDecisionStatus.pendingClientDecision =>
        ('Report submitted — awaiting decision', _kPrimary),
      InspectionDecisionStatus.acceptedRepair =>
        ('Quote accepted — repair in progress', _kSuccess),
      InspectionDecisionStatus.closedAfterInspection =>
        ('Closed after inspection', const Color(0xFF2563EB)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assignment_turned_in_rounded, size: 15, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: child,
    );
  }
}
