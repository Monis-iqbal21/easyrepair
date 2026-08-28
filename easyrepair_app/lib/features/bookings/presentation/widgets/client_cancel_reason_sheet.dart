import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../l10n/app_localizations.dart';
import 'detail/booking_detail_primitives.dart';

/// Free-text limit for the "Dusri wajah" field. The backend's
/// CancelBookingDto allows 500, so this stays comfortably inside it.
const int kClientCancelReasonMaxLength = 300;

/// Preset cancellation reasons, in display order.
///
/// Each option carries two separate things, and conflating them is the bug
/// this enum exists to prevent:
///
///  * [storedValue] — what the backend receives and what an Ustaad, an admin
///    or a support agent later reads on the booking. It is language-independent
///    and **must never change**: these strings are already persisted against
///    live bookings, so translating them would make old and new cancellations
///    incomparable.
///  * [label] — what the client sees, in whichever language they picked.
///
/// [other] is the free-text sentinel: selecting it reveals the required text
/// field, and the typed text (never the label, never [storedValue]) is stored.
enum ClientCancelReason {
  noLongerNeeded('Ab service ki zarurat nahi'),
  bookedByMistake('Booking ghalti se ho gayi'),
  problemSolved('Masla khud hal ho gaya'),
  timingNotSuitable('Waqt ya tareekh munasib nahi'),
  priceNotSuitable('Qeemat ya budget munasib nahi'),
  // Worker-related: hidden until an Ustaad is actually assigned — offering
  // "the Ustaad is running very late" on a booking with no Ustaad is nonsense.
  cannotReachUstaad('Ustaad se rabta nahi ho raha', workerRelated: true),
  ustaadRunningLate('Ustaad bohat dair kar raha hai', workerRelated: true),
  other('Dusri wajah');

  const ClientCancelReason(this.storedValue, {this.workerRelated = false});

  /// Sent to the backend. Stable across languages and releases.
  final String storedValue;

  /// Only offered once a booking has an assigned Ustaad.
  final bool workerRelated;

  /// Shown to the client, in the app's current language.
  String label(AppLocalizations l10n) => switch (this) {
    ClientCancelReason.noLongerNeeded => l10n.cancelReasonNoLongerNeeded,
    ClientCancelReason.bookedByMistake => l10n.cancelReasonBookedByMistake,
    ClientCancelReason.problemSolved => l10n.cancelReasonProblemSolved,
    ClientCancelReason.timingNotSuitable => l10n.cancelReasonTimingNotSuitable,
    ClientCancelReason.priceNotSuitable => l10n.cancelReasonPriceNotSuitable,
    ClientCancelReason.cannotReachUstaad => l10n.cancelReasonCannotReachUstaad,
    ClientCancelReason.ustaadRunningLate => l10n.cancelReasonUstaadRunningLate,
    ClientCancelReason.other => l10n.cancelReasonOther,
  };
}

/// Cancellation-reason sheet, shared by every lane and by both client entry
/// points (booking detail + My Bookings list).
///
/// Purely a reason collector: it is only ever opened once the caller has
/// already decided cancellation is allowed. It changes nothing about *when*
/// cancelling is permitted, and there is no cancellation fee in this product
/// to warn about.
///
/// Pops with the reason string to store (the preset [ClientCancelReason
/// .storedValue], or the trimmed custom text for "Dusri wajah"), or null when
/// the client backs out.
class ClientCancelReasonSheet extends StatefulWidget {
  /// Hides the worker-related presets when no Ustaad is assigned yet.
  final bool hasAssignedWorker;

  /// Performs the cancellation. Returning normally closes the sheet;
  /// throwing keeps it open with the error shown, so the client can retry.
  final Future<void> Function(String reason) onSubmit;

  const ClientCancelReasonSheet({
    super.key,
    required this.hasAssignedWorker,
    required this.onSubmit,
  });

  @override
  State<ClientCancelReasonSheet> createState() =>
      _ClientCancelReasonSheetState();
}

class _ClientCancelReasonSheetState extends State<ClientCancelReasonSheet> {
  ClientCancelReason? _selected;
  final _customCtrl = TextEditingController();
  final _customFocus = FocusNode();
  bool _submitting = false;

  @override
  void dispose() {
    _customCtrl.dispose();
    _customFocus.dispose();
    super.dispose();
  }

  List<ClientCancelReason> get _reasons => ClientCancelReason.values
      .where((r) => widget.hasAssignedWorker || !r.workerRelated)
      .toList();

  bool get _isOther => _selected == ClientCancelReason.other;

  /// The free-text option requires non-empty text; every other option is valid
  /// on selection alone.
  bool get _canSubmit =>
      _selected != null && (!_isOther || _customCtrl.text.trim().isNotEmpty);

  /// What actually gets stored: the option's language-independent
  /// [ClientCancelReason.storedValue], or ONLY the trimmed custom text for the
  /// free-text option (never its sentinel value, never a translated label).
  String get _reasonToStore =>
      _isOther ? _customCtrl.text.trim() : _selected!.storedValue;

  void _select(ClientCancelReason reason) {
    if (_submitting) return;
    setState(() => _selected = reason);
    if (reason == ClientCancelReason.other) {
      _customFocus.requestFocus();
    } else {
      _customFocus.unfocus();
    }
  }

  Future<void> _submit() async {
    // Single-flight guard — a double tap must never send two cancellations.
    if (!_canSubmit || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(_reasonToStore);
      if (mounted) Navigator.of(context).pop(_reasonToStore);
    } catch (_) {
      // The caller surfaces the error; keep the sheet open so the client can
      // try again without re-picking their reason.
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Padding(
      // Lifts the whole sheet — reason list AND buttons — clear of the
      // keyboard raised by the free-text field.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.cancelReasonTitle,
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.cancelReasonRequired,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Only the reason list scrolls, so the destructive CTA and its way
            // out stay pinned and reachable at every text scale.
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                children: [
                  for (final reason in _reasons) ...[
                    _ReasonTile(
                      reason: reason,
                      selected: _selected == reason,
                      enabled: !_submitting,
                      onTap: () => _select(reason),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_isOther) ...[
                    const SizedBox(height: 4),
                    TextField(
                      controller: _customCtrl,
                      focusNode: _customFocus,
                      maxLines: 3,
                      maxLength: kClientCancelReasonMaxLength,
                      enabled: !_submitting,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: colors.textPrimary,
                      ),
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(
                          kClientCancelReasonMaxLength,
                        ),
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: context.l10n.cancelReasonWriteOwn,
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
                          borderSide: BorderSide(
                            color: colors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BookingPrimaryButton(
                    key: const Key('confirm-cancellation-button'),
                    label: context.l10n.bookingCancelBooking,
                    icon: Icons.close_rounded,
                    destructive: true,
                    loading: _submitting,
                    onPressed: _canSubmit ? _submit : null,
                  ),
                  const SizedBox(height: 10),
                  BookingSecondaryButton(
                    key: const Key('keep-booking-button'),
                    label: context.l10n.postJobBack,
                    icon: Icons.arrow_back_rounded,
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop<String?>(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One selectable reason. A full-width 56px row so a long or Urdu label wraps
/// instead of truncating, with the radio glyph and a teal-tinted fill both
/// carrying the selected state.
class _ReasonTile extends StatelessWidget {
  final ClientCancelReason reason;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ReasonTile({
    required this.reason,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      child: Material(
        color: selected ? colors.softTeal : colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? colors.primary : colors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 22,
                  color: selected ? colors.primary : colors.controlBorder,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    reason.label(context.l10n),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: colors.textPrimary,
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

/// Opens the shared cancellation-reason sheet. Returns the stored reason on
/// success, or null when the client backed out.
Future<String?> showClientCancelReasonSheet({
  required BuildContext context,
  required bool hasAssignedWorker,
  required Future<void> Function(String reason) onSubmit,
}) {
  final colors = context.semanticColors;
  return showModalBottomSheet<String>(
    context: context,
    // Cancelling is deliberate: the sheet is dismissed by its own "back"
    // button, never by a stray tap on the barrier — matching the
    // barrier-dismissible:false dialog it replaces.
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ClientCancelReasonSheet(
      hasAssignedWorker: hasAssignedWorker,
      onSubmit: onSubmit,
    ),
  );
}
