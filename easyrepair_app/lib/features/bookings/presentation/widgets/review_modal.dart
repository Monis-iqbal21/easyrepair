import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/update_booking_request.dart';
import '../providers/booking_providers.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/errors/failure_messages.dart';

const _kGreen = Color(0xFFDB6234);
const _kDark = Color(0xFF1A1A1A);
const _kGray = Color(0xFF6B7280);
const _kLight = Color(0xFF94A3B8);
const _kBorder = Color(0xFFE2E8F0);
const _kRed = Color(0xFFDC2626);

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

  const ReviewModal({
    super.key,
    required this.booking,
    this.mandatory = false,
  });

  @override
  ConsumerState<ReviewModal> createState() => _ReviewModalState();
}

class _ReviewModalState extends ConsumerState<ReviewModal> {
  int _selectedRating = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Single-flight guard: a second tap that races past the disabled button
    // must never send a duplicate review.
    if (_submitting) return;

    if (_selectedRating == 0) {
      _snack('Barah-e-karam rating select karein.', _kRed);
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(reviewNotifierProvider.notifier).submit(
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
        Navigator.of(context).pop(true);
        _snack('Shukriya! Aap ka review submit ho gaya.', _kGreen);
      }
    } catch (e) {
      // Deliberately stays open — in mandatory mode this is what prevents
      // navigating on to the bidding page without a review.
      if (mounted) {
        _snack(
          failureMessage(context.l10n, e, fallback: context.l10n.reviewSubmitFailed),
          _kRed,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String message, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final worker =
        widget.booking.inspectingWorker ?? widget.booking.assignedWorker;

    return PopScope(
      // Mandatory reviews cannot be dismissed with the Android back button
      // or an iOS back gesture.
      canPop: !widget.mandatory,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (worker != null) ...[
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _kGreen,
                      shape: BoxShape.circle,
                    ),
                    child: worker.avatarUrl != null
                        ? ClipOval(
                            child: Image.network(
                              worker.avatarUrl!,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _Initials(worker.initials),
                            ),
                          )
                        : _Initials(worker.initials),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    worker.fullName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  widget.mandatory
                      ? context.l10n.reviewPromptBeforeContinuing
                      : context.l10n.reviewHowWasWork,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: _kGray),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (i) => GestureDetector(
                      onTap: () => setState(() => _selectedRating = i + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(
                          Icons.star_rounded,
                          size: 34,
                          color: i < _selectedRating
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _commentCtrl,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13, color: _kDark),
                  decoration: InputDecoration(
                    hintText: context.l10n.reviewCommentHint,
                    hintStyle: const TextStyle(fontSize: 13, color: _kLight),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kGreen),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kGreen,
                      disabledBackgroundColor: _kGreen.withValues(alpha: 0.5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            context.l10n.reviewSubmit,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
                // No escape hatch in mandatory mode — the review must be
                // submitted before the flow may continue.
                if (!widget.mandatory) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        context.l10n.reviewLater,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: _kGray,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  final String initials;
  const _Initials(this.initials);

  @override
  Widget build(BuildContext context) => Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      );
}
