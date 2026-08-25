import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../bookings/domain/entities/inspection_report_entity.dart';
import '../../../bookings/presentation/providers/booking_providers.dart';
import '../../../bookings/presentation/widgets/media_attachment_widgets.dart';
import '../config/inspection_issue_hints.dart';
import '../providers/worker_job_providers.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/permissions/media_permission_helper.dart';

const _kMaxPhotos = 6;

// Type scale. These users read outdoors, often in sunlight — nothing here
// drops below 12.5px, and every field label is at body weight.
const double _fLabel = 14;
const double _fBody = 14;
const double _fSection = 16;
const double _fNote = 13;

/// Worker-side inspection report form — "Masla kya nikla?" / repair quote,
/// submitted after the worker taps "Start Inspection" and inspects on-site.
///
/// ORDER IS THE DESIGN
/// -------------------
/// Most Ustaads read and write very little. The voice note is therefore the
/// FIRST thing on the screen and the loudest control on it; photos come
/// second (a picture needs no literacy at all); the two typed fields come
/// third, for the Ustaads who prefer to write. Nothing about what the form
/// accepts changed — `_isValid` and the submit call are untouched — only the
/// order in which an Ustaad meets the inputs.
class InspectionReportFormPage extends ConsumerStatefulWidget {
  final String bookingId;
  const InspectionReportFormPage({super.key, required this.bookingId});

  @override
  ConsumerState<InspectionReportFormPage> createState() =>
      _InspectionReportFormPageState();
}

class _InspectionReportFormPageState
    extends ConsumerState<InspectionReportFormPage> {
  final _issueCtrl = TextEditingController();
  final _repairCtrl = TextEditingController();
  final _labourCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _picker = ImagePicker();

  bool _partsNeeded = false;
  final List<InspectionReportPartDraft> _parts = [];
  final List<XFile> _photos = [];

  AudioRecorder? _recorder;
  bool _isRecordingVoice = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  String? _voiceNotePath;
  int? _voiceNoteDurationSeconds;

  @override
  void dispose() {
    _issueCtrl.dispose();
    _repairCtrl.dispose();
    _labourCtrl.dispose();
    _notesCtrl.dispose();
    _recordingTimer?.cancel();
    _recorder?.dispose();
    super.dispose();
  }

  double get _labourCost => double.tryParse(_labourCtrl.text.trim()) ?? 0;

  double get _partsTotal =>
      _parts.fold<double>(0, (sum, p) => sum + p.lineTotal);

  double get _finalQuote => _labourCost + _partsTotal;

  bool get _hasWrittenText =>
      _issueCtrl.text.trim().isNotEmpty && _repairCtrl.text.trim().isNotEmpty;

  bool get _hasVoiceNote => _voiceNotePath != null;

  bool get _hasReportContent => _hasWrittenText || _hasVoiceNote;

  bool get _isValid {
    if (!_hasReportContent) return false;
    if (_labourCtrl.text.trim().isEmpty || _labourCost < 0) return false;
    if (_partsNeeded && _parts.isEmpty) return false;
    for (final p in _parts) {
      if (p.name.trim().isEmpty || p.quantity < 1) return false;
    }
    return true;
  }

  // ── Voice recording ───────────────────────────────────────────────────────

  Future<void> _startVoiceRecording() async {
    // Resolved before the permission round-trip so neither message reads
    // `context` across an async gap.
    final l10n = context.l10n;
    final status = await Permission.microphone.request();
    if (status.isPermanentlyDenied) {
      _showError(l10n.inspFormMicPermanentlyDenied);
      openAppSettings();
      return;
    }
    if (!status.isGranted) {
      _showError(l10n.inspFormMicDenied);
      return;
    }
    _recorder ??= AudioRecorder();

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/inspection_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder!.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );

    setState(() {
      _isRecordingVoice = true;
      _recordingDuration = Duration.zero;
    });

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _recordingDuration += const Duration(seconds: 1));
      }
    });
  }

  Future<void> _stopVoiceRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;

    final path = await _recorder?.stop();
    final finalDuration = _recordingDuration;

    setState(() {
      _isRecordingVoice = false;
      _recordingDuration = Duration.zero;
      if (path != null) {
        _voiceNotePath = path;
        _voiceNoteDurationSeconds = finalDuration.inSeconds;
      }
    });
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    await _recorder?.stop();
    setState(() {
      _isRecordingVoice = false;
      _recordingDuration = Duration.zero;
    });
  }

  Future<void> _deleteVoiceNote() async {
    final path = _voiceNotePath;
    setState(() {
      _voiceNotePath = null;
      _voiceNoteDurationSeconds = null;
    });
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.semanticColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= _kMaxPhotos) return;
    final c = context.semanticColors;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.camera_alt_rounded, color: c.primary),
              title: Text(context.l10n.chatTakePhoto),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.image_rounded, color: c.primary),
              title: Text(context.l10n.inspFormChooseFromGallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final file = await pickImageWithRecovery(
      context,
      picker: _picker,
      source: source,
      imageQuality: 85,
    );
    if (file != null && mounted) setState(() => _photos.add(file));
  }

  /// Belt-and-suspenders reentrancy guard — the button is already disabled
  /// via the provider's `isLoading`, but that only takes effect on the next
  /// rebuild; this blocks a second tap landing in the same frame before that
  /// rebuild happens, so a fast double-tap can never fire two submissions.
  bool _submitInFlight = false;

  Future<void> _submit() async {
    if (!_isValid || _submitInFlight) return;
    _submitInFlight = true;
    try {
      await ref
          .read(inspectionReportSubmitNotifierProvider.notifier)
          .submit(
            widget.bookingId,
            issueFound: _issueCtrl.text.trim().isEmpty
                ? null
                : _issueCtrl.text.trim(),
            recommendedRepair: _repairCtrl.text.trim().isEmpty
                ? null
                : _repairCtrl.text.trim(),
            labourCost: _labourCost,
            partsNeeded: _partsNeeded,
            parts: _parts,
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
            photos: _photos.map((x) => File(x.path)).toList(),
            voiceNoteFile: _voiceNotePath != null
                ? File(_voiceNotePath!)
                : null,
            voiceNoteDurationSeconds: _voiceNoteDurationSeconds?.toDouble(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.inspFormSubmitted),
            backgroundColor: context.semanticColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failureMessage(
                context.l10n,
                e,
                fallback: context.l10n.inspFormSubmitFailed,
              ),
            ),
            backgroundColor: context.semanticColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      // Always released — success, error, timeout, or the widget having
      // been disposed in the meantime all reach this line.
      _submitInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final isSubmitting = ref
        .watch(inspectionReportSubmitNotifierProvider)
        .isLoading;
    final categoryName = ref
        .watch(workerJobDetailProvider(widget.bookingId))
        .valueOrNull
        ?.serviceCategory;
    // One lookup for every example-bearing field, so the issue, the
    // recommended repair and each part line always describe the same trade.
    final hints = inspectionFieldHintsFor(context.l10n, categoryName);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text(
          context.l10n.inspectionReportTitle,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Speak. The easiest way in for an Ustaad who does not
                    //    write, so it leads the screen.
                    _Card(
                      child: _VoiceNoteSection(
                        isRecording: _isRecordingVoice,
                        recordingDuration: _recordingDuration,
                        voiceNotePath: _voiceNotePath,
                        voiceNoteDurationSeconds: _voiceNoteDurationSeconds,
                        onStartRecording: _startVoiceRecording,
                        onStopRecording: _stopVoiceRecording,
                        onCancelRecording: _cancelRecording,
                        onDelete: _deleteVoiceNote,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 2. Show. A photo needs no literacy at all.
                    _Card(
                      child: _PhotosSection(
                        photos: _photos,
                        onAdd: _pickPhoto,
                        onRemove: (i) => setState(() => _photos.removeAt(i)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 3. Write — for the Ustaads who prefer to.
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel(
                            _hasVoiceNote
                                ? context.l10n.inspFormWhatWasIssue
                                : context.l10n.inspFormWhatWasIssueRequired,
                          ),
                          _TextInput(
                            controller: _issueCtrl,
                            hint: hints.issue,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          _FieldLabel(
                            _hasVoiceNote
                                ? context.l10n.inspFormRecommendedRepair
                                : context
                                      .l10n
                                      .inspFormRecommendedRepairRequired,
                          ),
                          _TextInput(
                            controller: _repairCtrl,
                            hint: hints.repair,
                            maxLines: 3,
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                    if (!_hasReportContent) ...[
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.inspFormWriteOrRecord,
                        style: TextStyle(
                          color: c.error,
                          fontSize: _fNote,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  context.l10n.inspFormPartsRequired,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: _fSection,
                                    color: c.textPrimary,
                                  ),
                                ),
                              ),
                              Switch(
                                value: _partsNeeded,
                                onChanged: (v) => setState(() {
                                  _partsNeeded = v;
                                  if (!v) _parts.clear();
                                }),
                              ),
                            ],
                          ),
                          if (_partsNeeded) ...[
                            const SizedBox(height: 8),
                            ..._parts.asMap().entries.map(
                              (e) => _PartCard(
                                part: e.value,
                                nameHint: hints.partName,
                                onChanged: (p) =>
                                    setState(() => _parts[e.key] = p),
                                onRemove: () =>
                                    setState(() => _parts.removeAt(e.key)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => setState(
                                () => _parts.add(
                                  const InspectionReportPartDraft(),
                                ),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 20),
                              label: Text(
                                context.l10n.inspFormAddPart,
                                style: const TextStyle(
                                  fontSize: _fBody,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel(context.l10n.inspFormLabourCostRequired),
                          _TextInput(
                            controller: _labourCtrl,
                            hint: '0',
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          _FieldLabel(context.l10n.inspFormNotesOptional),
                          _TextInput(
                            controller: _notesCtrl,
                            hint: context.l10n.inspFormUstaadNotes,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SummaryCard(
                      partsTotal: _partsTotal,
                      labourCost: _labourCost,
                      finalQuote: _finalQuote,
                    ),
                  ],
                ),
              ),
            ),
            // A hairline above the footer so the primary "Submit" never reads
            // as part of the scrolling content — it is the one control that
            // ends the screen.
            Container(height: 1, color: c.border),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isValid && !isSubmitting ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isSubmitting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.onPrimary,
                            ),
                          )
                        : Text(
                            context.l10n.inspFormSubmitReport,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: _fSection,
        fontWeight: FontWeight.w700,
        color: context.semanticColors.textPrimary,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: _fLabel,
          fontWeight: FontWeight.w700,
          color: context.semanticColors.textPrimary,
        ),
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  /// The fill a field needs to read against whatever sits behind it — a
  /// [_Card] fills with `surface`, a [_PartCard] with `surfaceSubtle`.
  final bool onSubtleSurface;

  const _TextInput({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
    this.onSubtleSurface = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final fill = onSubtleSurface ? c.surface : c.background;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(fontSize: _fBody, color: c.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textSecondary, fontSize: _fBody),
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _PhotosSection extends StatelessWidget {
  final List<XFile> photos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _PhotosSection({
    required this.photos,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final canAddMore = photos.length < _kMaxPhotos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(context.l10n.inspFormIssuePhotos(_kMaxPhotos)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: photos.length + (canAddMore ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == photos.length) {
              return GestureDetector(
                onTap: onAdd,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.softTeal,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.controlBorder),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.add_a_photo_rounded,
                      color: c.primary,
                      size: 26,
                    ),
                  ),
                ),
              );
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(photos[i].path), fit: BoxFit.cover),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => onRemove(i),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: c.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.border),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: c.error,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _VoiceNoteSection extends StatelessWidget {
  final bool isRecording;
  final Duration recordingDuration;
  final String? voiceNotePath;
  final int? voiceNoteDurationSeconds;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onCancelRecording;
  final VoidCallback onDelete;

  const _VoiceNoteSection({
    required this.isRecording,
    required this.recordingDuration,
    required this.voiceNotePath,
    required this.voiceNoteDurationSeconds,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onCancelRecording,
    required this.onDelete,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(context.l10n.inspFormVoiceNote),
        const SizedBox(height: 4),
        Text(
          context.l10n.inspFormVoiceNoteHint,
          style: TextStyle(
            fontSize: _fBody,
            color: c.textSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        if (isRecording)
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: c.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                context.l10n.inspFormRecording(_fmt(recordingDuration)),
                style: TextStyle(
                  fontSize: _fSection,
                  color: c.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onCancelRecording,
                icon: Icon(Icons.close_rounded, color: c.textSecondary),
                tooltip: context.l10n.commonCancel,
              ),
              IconButton(
                onPressed: onStopRecording,
                icon: Icon(
                  Icons.stop_circle_rounded,
                  color: c.primary,
                  size: 38,
                ),
                tooltip: context.l10n.inspFormStop,
              ),
            ],
          )
        else if (voiceNotePath != null)
          Row(
            children: [
              Expanded(
                child: WhatsAppVoiceNotePlayer(localPath: voiceNotePath),
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, color: c.error),
                tooltip: context.l10n.commonDelete,
              ),
            ],
          )
        else
          // The single loudest control on the screen: full width, 56 high,
          // a filled brand button rather than a thin outline. An Ustaad who
          // cannot write should not have to hunt for it.
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onStartRecording,
              icon: const Icon(Icons.mic_rounded, size: 24),
              label: Text(
                context.l10n.inspFormStartRecording,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PartCard extends StatefulWidget {
  final InspectionReportPartDraft part;

  /// Trade-specific example for the part name, resolved once by the form from
  /// the booking's category — a Painter must never be shown "Gas refill".
  final String nameHint;
  final ValueChanged<InspectionReportPartDraft> onChanged;
  final VoidCallback onRemove;

  const _PartCard({
    required this.part,
    required this.nameHint,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_PartCard> createState() => _PartCardState();
}

class _PartCardState extends State<_PartCard> {
  late final TextEditingController _name = TextEditingController(
    text: widget.part.name,
  );
  late final TextEditingController _qty = TextEditingController(
    text: widget.part.quantity.toString(),
  );
  late final TextEditingController _price = TextEditingController(
    text: widget.part.unitPrice == 0 ? '' : widget.part.unitPrice.toString(),
  );
  late final TextEditingController _warranty = TextEditingController(
    text: widget.part.warranty ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _price.dispose();
    _warranty.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      widget.part.copyWith(
        name: _name.text,
        quantity: int.tryParse(_qty.text) ?? 1,
        unitPrice: double.tryParse(_price.text) ?? 0,
        warranty: _warranty.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(context.l10n.inspFormPartName),
          _TextInput(
            controller: _name,
            hint: widget.nameHint,
            onSubtleSurface: true,
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel(context.l10n.inspFormQty),
                    _TextInput(
                      controller: _qty,
                      hint: '1',
                      keyboardType: TextInputType.number,
                      onSubtleSurface: true,
                      onChanged: (_) => _emit(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel(context.l10n.inspFormUnitPrice),
                    _TextInput(
                      controller: _price,
                      hint: '0',
                      keyboardType: TextInputType.number,
                      onSubtleSurface: true,
                      onChanged: (_) => _emit(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _FieldLabel(context.l10n.inspFormWarrantyOptional),
          _TextInput(
            controller: _warranty,
            hint: context.l10n.inspFormWarrantyHint,
            onSubtleSurface: true,
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: widget.onRemove,
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              label: Text(
                context.l10n.inspFormRemovePart,
                style: const TextStyle(
                  fontSize: _fBody,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: c.error,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double partsTotal;
  final double labourCost;
  final double finalQuote;

  const _SummaryCard({
    required this.partsTotal,
    required this.labourCost,
    required this.finalQuote,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line(c, context.l10n.inspFormPartsTotal, formatPkr(partsTotal)),
          _line(c, context.l10n.inspFormLabour, formatPkr(labourCost)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: c.border),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  context.l10n.inspFormTotalAmount,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: _fSection,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatPkr(finalQuote),
                style: TextStyle(
                  color: c.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.inspFormFeeWaivedNote,
            style: TextStyle(
              color: c.success,
              fontSize: _fNote,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(AppSemanticColors c, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: c.textSecondary, fontSize: _fBody),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: _fBody,
            ),
          ),
        ],
      ),
    );
  }
}
