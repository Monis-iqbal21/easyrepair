import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../domain/entities/booking_entity.dart';
import '../utils/booking_labels.dart';
import 'status_badge.dart';

/// One shared Client Bookings card shell for STANDARD, INSPECTION and BIDDING.
/// Lane-specific content is limited to the main description, lane label and
/// canonical price already owned by [BookingEntity].
class BookingCard extends StatelessWidget {
  final BookingEntity booking;
  final VoidCallback onTap;
  final VoidCallback? onCancel;
  final VoidCallback? onChat;
  final VoidCallback? onEdit;
  final VoidCallback? onFindWorkers;
  final VoidCallback? onTrackWorker;

  const BookingCard({
    super.key,
    required this.booking,
    required this.onTap,
    this.onCancel,
    this.onChat,
    this.onEdit,
    this.onFindWorkers,
    this.onTrackWorker,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final waitingForQuote =
        booking.lane == BookingLane.inspection &&
        booking.inspectionReportSubmitted &&
        booking.inspectionDecisionStatus ==
            InspectionDecisionStatus.pendingClientDecision;

    return Semantics(
      button: true,
      label: '${booking.referenceId}, $_mainDescription',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopRow(booking: booking, waitingForQuote: waitingForQuote),
                  const SizedBox(height: 12),
                  Text(
                    _mainDescription,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                      height: 1.28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _laneAndSchedule(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12.5,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_showPaymentRow) ...[
                    const SizedBox(height: 10),
                    _PaymentRow(booking: booking),
                  ],
                  const SizedBox(height: 14),
                  Divider(color: colors.divider),
                  const SizedBox(height: 12),
                  _WorkerRow(booking: booking),
                  if (_hasActions) ...[
                    const SizedBox(height: 14),
                    _ActionArea(
                      booking: booking,
                      onCancel: onCancel,
                      onChat: onChat,
                      onEdit: onEdit,
                      onFindWorkers: _canFindWorkers ? onFindWorkers : null,
                      onTrackWorker: _canTrackWorker ? onTrackWorker : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _mainDescription {
    switch (booking.lane) {
      case BookingLane.standard:
        final names = booking.standardServiceItems
            .where((item) => item.nameSnapshot.trim().isNotEmpty)
            .map(
              (item) => item.quantity > 1
                  ? '${item.nameSnapshot.trim()} ×${item.quantity}'
                  : item.nameSnapshot.trim(),
            )
            .toList();
        if (names.isNotEmpty) return names.join(', ');
        final snapshot = booking.standardServiceNameSnapshot?.trim();
        if (snapshot != null && snapshot.isNotEmpty) return snapshot;
        return _firstNonEmpty([booking.title, booking.serviceCategory]);
      case BookingLane.inspection:
        return _firstNonEmpty([
          booking.description,
          booking.title,
          booking.serviceCategory,
        ]);
      case BookingLane.bidding:
        return _firstNonEmpty([
          booking.title,
          booking.description,
          booking.serviceCategory,
        ]);
    }
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return booking.serviceCategory;
  }

  String _laneAndSchedule(BuildContext context) {
    final parts = <String>[_laneLabel(context)];
    final scheduledDate = booking.scheduledDate;
    if (scheduledDate != null) {
      final now = DateTime.now();
      final isToday =
          scheduledDate.year == now.year &&
          scheduledDate.month == now.month &&
          scheduledDate.day == now.day;
      parts.add(
        isToday
            ? context.l10n.commonToday
            : DateFormat('d MMM').format(scheduledDate),
      );
    }
    if (booking.urgency == BookingUrgency.urgent) {
      parts.add(
        booking.urgentWindow == null
            ? context.l10n.filterUrgentOption.replaceFirst('⚡ ', '')
            : urgentWindowLabel(context.l10n, booking.urgentWindow!),
      );
    } else if (booking.timeSlot != null) {
      parts.add(timeSlotLabel(context.l10n, booking.timeSlot!));
    }
    return parts.join(' · ');
  }

  String _laneLabel(BuildContext context) => switch (booking.lane) {
    BookingLane.standard => context.l10n.workerLevelStandard,
    BookingLane.inspection => context.l10n.postJobLaneInspectionTitle,
    BookingLane.bidding => context.l10n.bookingCardLaneBidding,
  };

  bool get _showPaymentRow {
    final isPaymentFreeTerminal =
        booking.status == BookingStatus.cancelled ||
        booking.status == BookingStatus.rejected ||
        booking.status == BookingStatus.expired;
    return !isPaymentFreeTerminal ||
        booking.receivedAmount != null ||
        booking.expectedAmount != null;
  }

  bool get _hasQuickActions {
    final canCancel = booking.canClientCancel;
    return (canCancel && onCancel != null) ||
        (booking.assignedWorker != null && onChat != null) ||
        (booking.status == BookingStatus.pending &&
            booking.assignedWorker == null &&
            onEdit != null);
  }

  bool get _canFindWorkers =>
      booking.assignedWorker == null &&
      booking.status != BookingStatus.completed &&
      booking.status != BookingStatus.cancelled &&
      booking.status != BookingStatus.rejected;

  bool get _canTrackWorker =>
      booking.assignedWorker != null &&
      booking.status != BookingStatus.completed &&
      booking.status != BookingStatus.cancelled &&
      booking.status != BookingStatus.rejected;

  bool get _hasActions =>
      _hasQuickActions ||
      (_canFindWorkers && onFindWorkers != null) ||
      (_canTrackWorker && onTrackWorker != null);
}

class _TopRow extends StatelessWidget {
  final BookingEntity booking;
  final bool waitingForQuote;

  const _TopRow({required this.booking, required this.waitingForQuote});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Row(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 110),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: StatusBadge(
              status: booking.status,
              small: true,
              detailedClientWording: true,
              waitingForQuote: waitingForQuote,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            booking.referenceId,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (booking.canonicalPrice != null) ...[
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                formatPkr(booking.canonicalPrice!),
                maxLines: 1,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final BookingEntity booking;

  const _PaymentRow({required this.booking});

  @override
  Widget build(BuildContext context) {
    final (icon, label, foreground) = _content(context);
    return Row(
      children: [
        Icon(icon, size: 15, color: foreground),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              height: 1.25,
              fontWeight:
                  booking.paymentDisplayStatus == PaymentDisplayStatus.paid
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  (IconData, String, Color) _content(BuildContext context) {
    final colors = context.semanticColors;
    switch (booking.paymentDisplayStatus) {
      case PaymentDisplayStatus.paid:
        return (
          Icons.check_circle_rounded,
          '✓ ${context.l10n.earningStatusPaid}',
          colors.success,
        );
      case PaymentDisplayStatus.partial:
        final received = booking.receivedAmount;
        final remaining = booking.remainingAmount;
        final label = received != null && remaining != null
            ? context.l10n.bookingCardPartialPayment(
                formatPkr(received),
                formatPkr(remaining),
              )
            : context.l10n.bookingCardPaymentPending;
        return (Icons.payments_outlined, label, colors.warning);
      case PaymentDisplayStatus.unpaid:
        final isCancelled =
            booking.status == BookingStatus.cancelled ||
            booking.status == BookingStatus.rejected ||
            booking.status == BookingStatus.expired;
        if (isCancelled && booking.receivedAmount == 0) {
          return (
            Icons.money_off_rounded,
            context.l10n.bookingCardNoPaymentTaken,
            colors.textSecondary,
          );
        }
        if (booking.status != BookingStatus.completed) {
          return (
            Icons.payments_outlined,
            context.l10n.bookingCardPaymentAfterWork,
            colors.textSecondary,
          );
        }
        return (
          Icons.schedule_rounded,
          booking.receivedAmount == 0
              ? context.l10n.bookingCardNothingPaid
              : context.l10n.bookingCardPaymentPending,
          colors.warning,
        );
    }
  }
}

class _WorkerRow extends StatelessWidget {
  final BookingEntity booking;

  const _WorkerRow({required this.booking});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final worker = booking.assignedWorker;
    final showSearching =
        worker == null &&
        booking.status != BookingStatus.completed &&
        booking.status != BookingStatus.cancelled &&
        booking.status != BookingStatus.rejected &&
        booking.status != BookingStatus.expired;

    return Row(
      children: [
        if (worker != null) ...[
          _WorkerAvatar(worker: worker),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              worker.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ] else if (showSearching) ...[
          Icon(Icons.search_rounded, size: 18, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.cardSearchingWorkers,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.primary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ] else
          const Spacer(),
        const SizedBox(width: 10),
        Text(
          context.l10n.bookingCardDetails,
          style: TextStyle(
            color: colors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _WorkerAvatar extends StatelessWidget {
  final AssignedWorkerEntity worker;

  const _WorkerAvatar({required this.worker});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final hasImage = worker.avatarUrl?.trim().isNotEmpty ?? false;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(
              worker.avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _Initials(worker.initials),
            )
          : _Initials(worker.initials),
    );
  }
}

class _Initials extends StatelessWidget {
  final String initials;

  const _Initials(this.initials);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: context.semanticColors.onPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ActionArea extends StatelessWidget {
  final BookingEntity booking;
  final VoidCallback? onCancel;
  final VoidCallback? onChat;
  final VoidCallback? onEdit;
  final VoidCallback? onFindWorkers;
  final VoidCallback? onTrackWorker;

  const _ActionArea({
    required this.booking,
    this.onCancel,
    this.onChat,
    this.onEdit,
    this.onFindWorkers,
    this.onTrackWorker,
  });

  @override
  Widget build(BuildContext context) {
    final quickActions = <Widget>[];
    if (booking.assignedWorker != null && onChat != null) {
      quickActions.add(
        _CompactActionButton(
          label: context.l10n.chatTitleFallback,
          icon: Icons.chat_bubble_outline_rounded,
          kind: _ActionKind.brand,
          onTap: onChat!,
        ),
      );
    }
    if (booking.status == BookingStatus.pending &&
        booking.assignedWorker == null &&
        onEdit != null) {
      quickActions.add(
        _CompactActionButton(
          label: context.l10n.cardEdit,
          icon: Icons.edit_outlined,
          kind: _ActionKind.neutral,
          onTap: onEdit!,
        ),
      );
    }
    if (booking.canClientCancel && onCancel != null) {
      quickActions.add(
        _CompactActionButton(
          label: context.l10n.commonCancel,
          icon: Icons.close_rounded,
          kind: _ActionKind.danger,
          onTap: onCancel!,
        ),
      );
    }

    return Column(
      children: [
        if (quickActions.isNotEmpty)
          Row(
            children: [
              for (var i = 0; i < quickActions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: quickActions[i]),
              ],
            ],
          ),
        if (onFindWorkers != null) ...[
          if (quickActions.isNotEmpty) const SizedBox(height: 8),
          _PrimaryActionButton(
            label: booking.lane == BookingLane.bidding
                ? context.l10n.cardFindWorkers
                : context.l10n.bookingChooseUstaad,
            icon: Icons.manage_search_rounded,
            onTap: onFindWorkers!,
          ),
        ],
        if (onTrackWorker != null) ...[
          if (quickActions.isNotEmpty) const SizedBox(height: 8),
          _PrimaryActionButton(
            label: context.l10n.bookingTrackWorker,
            icon: Icons.location_on_outlined,
            onTap: onTrackWorker!,
          ),
        ],
      ],
    );
  }
}

enum _ActionKind { brand, neutral, danger }

class _CompactActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final _ActionKind kind;
  final VoidCallback onTap;

  const _CompactActionButton({
    required this.label,
    required this.icon,
    required this.kind,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final (foreground, background) = switch (kind) {
      _ActionKind.brand => (colors.primary, colors.softTeal),
      _ActionKind.neutral => (colors.textPrimary, colors.surfaceSubtle),
      _ActionKind.danger => (colors.error, colors.errorSoft),
    };
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Material(
      color: colors.primary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: colors.onPrimary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
