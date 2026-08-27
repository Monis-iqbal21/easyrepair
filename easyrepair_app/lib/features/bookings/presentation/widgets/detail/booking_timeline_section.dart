import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n_extensions.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../domain/entities/booking_entity.dart';
import '../../utils/booking_timeline.dart';
import 'booking_detail_primitives.dart';

/// Vertical progress timeline for the Client Booking Detail page.
///
/// Connected dots, lane-specific wording, and no per-step timestamps. This is
/// a READ-ONLY view of the booking's existing status — it decides nothing and
/// exposes no control, because every step it draws is a transition the Ustaad
/// owns, not the client.
///
/// The five steps render for EVERY lane and EVERY status, including cancelled,
/// rejected and expired bookings: those freeze at the furthest progress they
/// actually reached, or show five pending steps if nothing happened at all.
/// A step is never faked to fill the column.
class BookingTimelineSection extends StatelessWidget {
  final BookingEntity booking;

  const BookingTimelineSection({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final steps = bookingTimelineSteps(context.l10n, booking);
    return BookingDetailCard(
      key: const Key('booking-timeline-section'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookingSectionHeading(
            label: context.l10n.bookingStatusTimeline,
            icon: Icons.timeline_rounded,
          ),
          const SizedBox(height: 14),
          // An open bidding job explains WHY every step below is still
          // pending, then shows them anyway.
          if (bookingTimelineAwaitsWorker(booking)) ...[
            const _AwaitingWorkerNotice(),
            const SizedBox(height: 16),
          ],
          for (var i = 0; i < steps.length; i++)
            _TimelineRow(
              step: steps[i],
              isFirst: i == 0,
              isLast: i == steps.length - 1,
              // The connector belongs to the gap ABOVE this row, so it is
              // "done" only when the step before it is done.
              connectorAbove: i == 0
                  ? null
                  : steps[i - 1].state == BookingTimelineStepState.complete,
            ),
        ],
      ),
    );
  }
}

/// The dot column plus its label.
///
/// [IntrinsicHeight] lets the outgoing connector stretch to whatever height
/// the label needs, so the line stays unbroken when a long step name wraps on
/// a narrow screen.
class _TimelineRow extends StatelessWidget {
  final BookingTimelineStep step;
  final bool isFirst;
  final bool isLast;
  final bool? connectorAbove;

  const _TimelineRow({
    required this.step,
    required this.isFirst,
    required this.isLast,
    required this.connectorAbove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final isComplete = step.state == BookingTimelineStepState.complete;
    final isCurrent = step.state == BookingTimelineStepState.current;

    final labelColor = switch (step.state) {
      BookingTimelineStepState.complete => colors.textPrimary,
      BookingTimelineStepState.current => colors.primary,
      BookingTimelineStepState.pending => colors.textSecondary,
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                // Connecting line into this dot, closing the gap left by the
                // row above. The first step has nothing above it.
                if (!isFirst)
                  SizedBox(
                    height: 10,
                    child: _Connector(done: connectorAbove ?? false),
                  ),
                _Dot(isComplete: isComplete, isCurrent: isCurrent),
                // Connecting line out of this dot, continuing to the next.
                if (!isLast)
                  Expanded(child: _Connector(done: isComplete)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: isFirst ? 0 : 10,
                bottom: isLast ? 0 : 14,
              ),
              child: Text(
                step.label,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.3,
                  color: labelColor,
                  fontWeight: isCurrent || isComplete
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool isComplete;
  final bool isCurrent;

  const _Dot({required this.isComplete, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    if (isComplete) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: colors.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.check_rounded, size: 13, color: colors.onPrimary),
      );
    }

    if (isCurrent) {
      // A ring rather than a fill, so "happening now" reads differently from
      // "already done" without relying on colour alone.
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: colors.softTeal,
          shape: BoxShape.circle,
          border: Border.all(color: colors.primary, width: 2.5),
        ),
      );
    }

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: colors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: colors.controlBorder, width: 1.5),
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  final bool done;

  const _Connector({required this.done});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Center(
      child: Container(
        width: 2,
        color: done ? colors.primary : colors.border,
      ),
    );
  }
}

/// BIDDING with nobody hired: explains why every step below is still pending.
/// The "Find Workers" CTA is unchanged and still lives in the action section.
class _AwaitingWorkerNotice extends StatelessWidget {
  const _AwaitingWorkerNotice();

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Container(
      key: const Key('booking-timeline-awaiting'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hourglass_empty_rounded, size: 18, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.timelineWaitingForUstaadTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.timelineWaitingForUstaadBody,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
