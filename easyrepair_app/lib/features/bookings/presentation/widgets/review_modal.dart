import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/update_booking_request.dart';
import '../providers/booking_providers.dart';
import 'detail/booking_detail_primitives.dart';

/// Rate-and-comment modal for a completed booking's Ustaad.
///
/// Extracted from booking_detail_page.dart so the app shell (and the
/// Find-Other-Ustaad flow) can open it without importing a page. Fields,
/// rating API and business rules are unchanged.
///
/// Pops with `true` only after a confirmed successful submission; a failed
/// submission keeps the modal open and pops nothing.
///
/// In [mandatory] mode (the inspection → linked-bidding transition) there is
/// no "Baad mein" escape, the barrier is not dismissible and `PopScope`
/// blocks the system back gesture — the review genuinely cannot be bypassed.
class ReviewModal extends ConsumerStatefulWidget {
  final BookingEntity booking;
  final bool mandatory;

  const ReviewModal({super.key, required this.booking, this.mandatory = false});

  @override
  ConsumerState<ReviewModal> createState() => _ReviewModalState();
}

class _ReviewModalState extends ConsumerState<ReviewModal> {
  int _selectedRating = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  /// Set only when submit was pressed with no star chosen. Shown inline under
  /// the stars rather than as a snack, so the message sits beside the control
  /// it is about. Cleared as soon as a star is picked.
  bool _showRatingError = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _selectRating(int rating) => setState(() {
    _selectedRating = rating;
    _showRatingError = false;
  });

  Future<void> _submit() async {
    // Single-flight guard: a second tap that races past the disabled button
    // must never send a duplicate review.
    if (_submitting) return;

    // Validation is unchanged — a rating is required, a comment never is.
    // Only where the message appears has moved.
    if (_selectedRating == 0) {
      setState(() => _showRatingError = true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref
          .read(reviewNotifierProvider.notifier)
          .submit(
            ReviewRequest(
              bookingId: widget.booking.id,
              rating: _selectedRating,
              comment: _commentCtrl.text.trim().isEmpty
                  ? null
                  : _commentCtrl.text.trim(),
            ),
          );
      // submit() already pushes the updated booking into
      // bookingDetailProvider / bookingsNotifierProvider, so any screen
      // behind this modal refreshes as soon as it closes.
      if (mounted) {
        final colors = context.semanticColors;
        final message = context.l10n.reviewSubmitSuccess;
        Navigator.of(context).pop(true);
        _snack(message, colors.success);
      }
    } catch (e) {
      // Deliberately stays open — in mandatory mode this is what prevents
      // navigating on to the bidding page without a review.
      if (mounted) {
        _snack(
          failureMessage(
            context.l10n,
            e,
            fallback: context.l10n.reviewSubmitFailed,
          ),
          context.semanticColors.error,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String message, Color background) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final worker =
        widget.booking.inspectingWorker ?? widget.booking.assignedWorker;

    return PopScope(
      // Mandatory reviews cannot be dismissed with the Android back button
      // or an iOS back gesture.
      canPop: !widget.mandatory,
      child: Dialog(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        // A dialog is a card: hairline, radius 16, no shadow.
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.reviewHowWasWork,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              if (widget.mandatory) ...[
                const SizedBox(height: 6),
                Text(
                  context.l10n.reviewPromptBeforeContinuing,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: colors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _JobContextCard(booking: widget.booking, worker: worker),
              const SizedBox(height: 18),
              _StarRating(
                rating: _selectedRating,
                onChanged: _submitting ? null : _selectRating,
              ),
              if (_showRatingError) ...[
                const SizedBox(height: 8),
                Text(
                  context.l10n.reviewSelectRating,
                  key: const Key('review-rating-error'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: colors.error,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              TextField(
                key: const Key('review-comment-field'),
                controller: _commentCtrl,
                enabled: !_submitting,
                minLines: 3,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: context.l10n.reviewCommentHint,
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: colors.textSecondary,
                  ),
                  filled: true,
                  fillColor: colors.surfaceSubtle,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              BookingPrimaryButton(
                key: const Key('review-submit-button'),
                label: context.l10n.reviewSubmit,
                icon: Icons.check_rounded,
                loading: _submitting,
                onPressed: _submit,
              ),
              // No escape hatch in mandatory mode — the review must be
              // submitted before the flow may continue.
              if (!widget.mandatory) ...[
                const SizedBox(height: 6),
                SizedBox(
                  height: 48,
                  child: TextButton(
                    key: const Key('review-later-button'),
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      context.l10n.reviewLater,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Who is being rated, and for which job — a review prompt can surface hours
/// after the work, so it never asks the client to guess which job it means.
class _JobContextCard extends StatelessWidget {
  final BookingEntity booking;
  final AssignedWorkerEntity? worker;

  const _JobContextCard({required this.booking, this.worker});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final service =
        booking.standardServiceNameSnapshot ?? booking.serviceCategory;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          _Avatar(worker: worker, emoji: booking.serviceEmoji),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  worker?.fullName ?? service,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  worker == null
                      ? booking.referenceId
                      : '$service · ${booking.referenceId}',
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

class _Avatar extends StatelessWidget {
  final AssignedWorkerEntity? worker;
  final String emoji;

  const _Avatar({required this.worker, required this.emoji});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final avatarUrl = worker?.avatarUrl;

    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: worker == null ? colors.softTeal : colors.primary,
        shape: BoxShape.circle,
      ),
      child: avatarUrl != null
          ? Image.network(
              avatarUrl,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _Initials(worker!.initials),
            )
          : worker == null
          ? Text(emoji, style: const TextStyle(fontSize: 24))
          : _Initials(worker!.initials),
    );
  }
}

class _Initials extends StatelessWidget {
  final String initials;
  const _Initials(this.initials);

  @override
  Widget build(BuildContext context) => Text(
    initials,
    style: TextStyle(
      color: context.semanticColors.onPrimary,
      fontSize: 19,
      fontWeight: FontWeight.w700,
    ),
  );
}

/// The 1–5 input. Each star owns a 48×48 target regardless of the glyph size,
/// so the row stays comfortably tappable for a client standing outdoors.
class _StarRating extends StatelessWidget {
  final int rating;
  final ValueChanged<int>? onChanged;

  const _StarRating({required this.rating, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          Semantics(
            button: true,
            selected: rating == i,
            label: '$i / 5',
            excludeSemantics: true,
            child: InkResponse(
              onTap: onChanged == null ? null : () => onChanged!(i),
              radius: 26,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  // Always the filled glyph: colour, not shape, carries the
                  // selection, so the row does not jitter as it is dragged
                  // through.
                  Icons.star_rounded,
                  size: 36,
                  color: i <= rating ? colors.warning : colors.border,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
