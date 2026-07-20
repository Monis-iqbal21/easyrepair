import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../bookings/domain/entities/inspection_report_entity.dart';
import '../../../bookings/presentation/providers/booking_providers.dart';
import '../../../bookings/presentation/widgets/media_attachment_widgets.dart';

const _kPrimary = Color(0xFFDB6234);
const _kDark = Color(0xFF1A1A1A);
const _kGray = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kBg = Color(0xFFF9FAFB);
const _kError = Color(0xFFEF4444);
const _kMaxPhotos = 6;

/// Worker-side inspection report form — "Masla kya nikla?" / repair quote,
/// submitted after the worker taps "Start Inspection" and inspects on-site.
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
    final status = await Permission.microphone.request();
    if (status.isPermanentlyDenied) {
      _showError('Microphone access is permanently denied. Enable it in Settings.');
      openAppSettings();
      return;
    }
    if (!status.isGranted) {
      _showError('Microphone permission denied.');
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
        backgroundColor: _kError,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= _kMaxPhotos) return;
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
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: _kPrimary),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.image_rounded, color: _kPrimary),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final file = await _picker.pickImage(source: source, imageQuality: 85);
    if (file != null && mounted) setState(() => _photos.add(file));
  }

  Future<void> _submit() async {
    if (!_isValid) return;
    try {
      await ref.read(inspectionReportSubmitNotifierProvider.notifier).submit(
            widget.bookingId,
            issueFound: _issueCtrl.text.trim().isEmpty ? null : _issueCtrl.text.trim(),
            recommendedRepair:
                _repairCtrl.text.trim().isEmpty ? null : _repairCtrl.text.trim(),
            labourCost: _labourCost,
            partsNeeded: _partsNeeded,
            parts: _parts,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            photos: _photos.map((x) => File(x.path)).toList(),
            voiceNoteFile: _voiceNotePath != null ? File(_voiceNotePath!) : null,
            voiceNoteDurationSeconds: _voiceNoteDurationSeconds?.toDouble(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted. Waiting for client decision.'),
            backgroundColor: _kPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is Failure ? e.message : 'Failed to submit report.'),
            backgroundColor: _kError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting =
        ref.watch(inspectionReportSubmitNotifierProvider).isLoading;

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
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel(_hasVoiceNote ? 'Masla kya nikla?' : 'Masla kya nikla? *'),
                          _TextInput(
                            controller: _issueCtrl,
                            hint: 'e.g. Gas leak — refill zaroori',
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          _FieldLabel(_hasVoiceNote ? 'Recommended repair' : 'Recommended repair *'),
                          _TextInput(
                            controller: _repairCtrl,
                            hint: 'Kya kaam karna hoga',
                            maxLines: 3,
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
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
                    if (!_hasReportContent) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Please write the report or record a voice note.',
                        style: TextStyle(color: _kError, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _Card(child: _PhotosSection(photos: _photos, onAdd: _pickPhoto, onRemove: (i) => setState(() => _photos.removeAt(i)))),
                    const SizedBox(height: 12),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Parts required?',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: _kDark),
                              ),
                              Switch(
                                value: _partsNeeded,
                                activeThumbColor: _kPrimary,
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
                                    onChanged: (p) => setState(() => _parts[e.key] = p),
                                    onRemove: () => setState(() => _parts.removeAt(e.key)),
                                  ),
                                ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => setState(
                                () => _parts.add(const InspectionReportPartDraft()),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add part'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _kPrimary,
                                side: const BorderSide(color: _kPrimary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          _FieldLabel('Labour cost *'),
                          _TextInput(
                            controller: _labourCtrl,
                            hint: '0',
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          _FieldLabel('Notes (optional)'),
                          _TextInput(controller: _notesCtrl, hint: 'Ustaad notes', maxLines: 2),
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
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isValid && !isSubmitting ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _kBorder,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Submit Report',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
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
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kDark),
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

  const _TextInput({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: _kDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _kGray, fontSize: 13.5),
        filled: true,
        fillColor: _kBg,
        contentPadding: const EdgeInsets.all(12),
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
          borderSide: const BorderSide(color: _kPrimary, width: 1.5),
        ),
      ),
    );
  }
}

class _PhotosSection extends StatelessWidget {
  final List<XFile> photos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _PhotosSection({required this.photos, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final canAddMore = photos.length < _kMaxPhotos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Issue photos — optional, max $_kMaxPhotos',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kDark),
        ),
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
                    color: _kBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorder, style: BorderStyle.solid),
                  ),
                  child: const Center(
                    child: Icon(Icons.camera_alt_rounded, color: _kPrimary, size: 22),
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
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Voice note',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kDark),
        ),
        const SizedBox(height: 4),
        const Text(
          'Agar likhna mushkil ho, voice note record kar dein.',
          style: TextStyle(fontSize: 12, color: _kGray),
        ),
        const SizedBox(height: 12),
        if (isRecording)
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: _kError, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(
                'Recording  ${_fmt(recordingDuration)}',
                style: const TextStyle(fontSize: 14, color: _kDark, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              IconButton(
                onPressed: onCancelRecording,
                icon: const Icon(Icons.close_rounded, color: _kGray),
                tooltip: 'Cancel',
              ),
              IconButton(
                onPressed: onStopRecording,
                icon: const Icon(Icons.stop_circle_rounded, color: _kPrimary, size: 32),
                tooltip: 'Stop',
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
                icon: const Icon(Icons.delete_outline_rounded, color: _kError),
                tooltip: 'Delete',
              ),
            ],
          )
        else
          OutlinedButton.icon(
            onPressed: onStartRecording,
            icon: const Icon(Icons.mic_rounded, size: 18),
            label: const Text('Start recording'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kPrimary,
              side: const BorderSide(color: _kPrimary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          ),
      ],
    );
  }
}

class _PartCard extends StatefulWidget {
  final InspectionReportPartDraft part;
  final ValueChanged<InspectionReportPartDraft> onChanged;
  final VoidCallback onRemove;

  const _PartCard({required this.part, required this.onChanged, required this.onRemove});

  @override
  State<_PartCard> createState() => _PartCardState();
}

class _PartCardState extends State<_PartCard> {
  late final TextEditingController _name = TextEditingController(text: widget.part.name);
  late final TextEditingController _qty = TextEditingController(text: widget.part.quantity.toString());
  late final TextEditingController _price = TextEditingController(
    text: widget.part.unitPrice == 0 ? '' : widget.part.unitPrice.toString(),
  );
  late final TextEditingController _warranty = TextEditingController(text: widget.part.warranty ?? '');

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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel('Part name'),
          _TextInput(controller: _name, hint: 'e.g. Gas refill', onChanged: (_) => _emit()),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('Qty'),
                    _TextInput(
                      controller: _qty,
                      hint: '1',
                      keyboardType: TextInputType.number,
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
                    _FieldLabel('Unit price'),
                    _TextInput(
                      controller: _price,
                      hint: '0',
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _emit(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _FieldLabel('Warranty / guarantee (optional)'),
          _TextInput(controller: _warranty, hint: 'e.g. 7 days', onChanged: (_) => _emit()),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: widget.onRemove,
              style: OutlinedButton.styleFrom(
                foregroundColor: _kError,
                side: const BorderSide(color: _kError),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Remove part'),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line('Parts total', formatPkr(partsTotal)),
          _line('Labour', formatPkr(labourCost)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Colors.white24),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Repair quote total', style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800)),
              Text(
                formatPkr(finalQuote),
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Inspection fee is not added here — it is waived if the client continues repair, or charged alone if they close after inspection.',
            style: TextStyle(color: Colors.white60, fontSize: 11.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value, {Color valueColor = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
          Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.w700, fontSize: 13.5)),
        ],
      ),
    );
  }
}
