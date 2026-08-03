import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../l10n/app_localizations.dart';

const _kPrimary = Color(0xFFDB6234);
const _kDark = Color(0xFF1A1A1A);
const _kGray = Color(0xFF6B7280);
const _kBorder = Color(0xFFE2E8F0);
const _kBg = Color(0xFFF9FAFB);
const _kRed = Color(0xFFDC2626);

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
        ClientCancelReason.timingNotSuitable =>
          l10n.cancelReasonTimingNotSuitable,
        ClientCancelReason.priceNotSuitable => l10n.cancelReasonPriceNotSuitable,
        ClientCancelReason.cannotReachUstaad =>
          l10n.cancelReasonCannotReachUstaad,
        ClientCancelReason.ustaadRunningLate =>
          l10n.cancelReasonUstaadRunningLate,
        ClientCancelReason.other => l10n.cancelReasonOther,
      };
}

/// Roman Urdu cancellation-reason modal, shared by every lane and by both
/// client entry points (booking detail + My Bookings list).
///
/// Purely a reason collector: it is only ever opened once the caller has
/// already decided cancellation is allowed. It changes nothing about *when*
/// cancelling is permitted.
///
/// Pops with the reason string to store (the preset label, or the trimmed
/// custom text for "Dusri wajah"), or null when the client backs out.
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
  bool _submitting = false;

  @override
  void dispose() {
    _customCtrl.dispose();
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        context.l10n.cancelReasonTitle,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 17,
          color: _kDark,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.cancelReasonRequired,
              style: TextStyle(color: _kGray, fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ClientCancelReason>(
              initialValue: _selected,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: context.l10n.cancelReasonSelect,
                filled: true,
                fillColor: _kBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: _reasons
                  .map(
                    (r) => DropdownMenuItem(
                      value: r,
                      child: Text(
                        r.label(context.l10n),
                        style: const TextStyle(fontSize: 13.5),
                      ),
                    ),
                  )
                  .toList(),
              onChanged:
                  _submitting ? null : (v) => setState(() => _selected = v),
            ),
            if (_isOther) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customCtrl,
                maxLines: 3,
                maxLength: kClientCancelReasonMaxLength,
                enabled: !_submitting,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    kClientCancelReasonMaxLength,
                  ),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: context.l10n.cancelReasonWriteOwn,
                  filled: true,
                  fillColor: _kBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop<String?>(),
          child: Text(context.l10n.postJobBack, style: TextStyle(color: _kGray)),
        ),
        TextButton(
          onPressed: _canSubmit && !_submitting ? _submit : null,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _kPrimary,
                  ),
                )
              : Text(
                  context.l10n.bookingCancelBooking,
                  style: TextStyle(color: _kRed, fontWeight: FontWeight.w600),
                ),
        ),
      ],
    );
  }
}

/// Opens the shared cancellation-reason modal. Returns the stored reason on
/// success, or null when the client backed out.
Future<String?> showClientCancelReasonSheet({
  required BuildContext context,
  required bool hasAssignedWorker,
  required Future<void> Function(String reason) onSubmit,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ClientCancelReasonSheet(
      hasAssignedWorker: hasAssignedWorker,
      onSubmit: onSubmit,
    ),
  );
}
