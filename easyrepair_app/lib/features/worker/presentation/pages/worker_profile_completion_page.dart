import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/worker_profile_entity.dart';
import '../providers/worker_providers.dart';
import '../pages/worker_home_page.dart' show showSkillsSheet;

// ── Palette (matches the rest of the worker app) ────────────────────────────
const _kOrange = Color(0xFFDB6234);
const _kDark = Color(0xFF1A1A1A);
const _kGray = Color(0xFF6B7280);
const _kLight = Color(0xFF94A3B8);
const _kBorder = Color(0xFFE2E8F0);
const _kBg = Color(0xFFF9FAFB);
const _kRed = Color(0xFFDC2626);
const _kGreen = Color(0xFF22C55E);

class WorkerProfileCompletionPage extends ConsumerStatefulWidget {
  const WorkerProfileCompletionPage({super.key});

  @override
  ConsumerState<WorkerProfileCompletionPage> createState() =>
      _WorkerProfileCompletionPageState();
}

class _WorkerProfileCompletionPageState
    extends ConsumerState<WorkerProfileCompletionPage> {
  final _picker = ImagePicker();
  final _fullLegalNameCtrl = TextEditingController();
  final _residentialAddressCtrl = TextEditingController();
  final _experienceYearsCtrl = TextEditingController();

  bool _legalNameConfirmed = false;
  bool _generalAgreementAccepted = false;
  bool _tradeAgreementAccepted = false;
  bool _prefilled = false;
  bool _uploadingCnicFront = false;
  bool _uploadingCnicBack = false;
  bool _uploadingSelfie = false;

  @override
  void dispose() {
    _fullLegalNameCtrl.dispose();
    _residentialAddressCtrl.dispose();
    _experienceYearsCtrl.dispose();
    super.dispose();
  }

  void _prefillFrom(WorkerProfileEntity profile) {
    if (_prefilled) return;
    _prefilled = true;
    _fullLegalNameCtrl.text = profile.fullLegalName ?? '';
    _residentialAddressCtrl.text = profile.residentialAddress ?? '';
    final exp = profile.skills.isNotEmpty ? profile.skills.first.yearsExperience : null;
    _experienceYearsCtrl.text = exp != null ? '$exp' : '';
    _legalNameConfirmed = profile.legalNameConfirmedAt != null;
    _generalAgreementAccepted = profile.generalAgreementAcceptedAt != null;
    _tradeAgreementAccepted = profile.tradeAgreementAcceptedAt != null;
  }

  bool _isEditable(String onboardingStatus) =>
      onboardingStatus == 'DRAFT' || onboardingStatus == 'CHANGES_REQUIRED';

  Future<void> _pickAndUpload(
    Future<String?> Function(File file) uploader,
    void Function(bool) setUploading,
  ) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;

    setState(() => setUploading(true));
    final url = await uploader(File(picked.path));
    if (!mounted) return;
    setState(() => setUploading(false));

    if (url == null) {
      final err = ref.read(profileCompletionNotifierProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err is Failure ? err.message : 'Upload failed. Please try again.'),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submit(WorkerProfileEntity profile) async {
    final years = int.tryParse(_experienceYearsCtrl.text.trim());
    if (_fullLegalNameCtrl.text.trim().isEmpty ||
        _residentialAddressCtrl.text.trim().isEmpty ||
        years == null ||
        years < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields with valid values.'),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final notifier = ref.read(profileCompletionNotifierProvider.notifier);
    final saved = await notifier.save(
      fullLegalName: _fullLegalNameCtrl.text.trim(),
      residentialAddress: _residentialAddressCtrl.text.trim(),
      experienceYears: years,
      legalNameConfirmed: _legalNameConfirmed,
      generalAgreementAccepted: _generalAgreementAccepted,
      tradeAgreementAccepted: _tradeAgreementAccepted,
    );
    if (!mounted || !saved) {
      if (mounted) _showError('Failed to save profile. Please try again.');
      return;
    }

    final submitted = await notifier.submit();
    if (!mounted) return;
    if (submitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile submitted for approval.'),
          backgroundColor: _kGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(
        'Please complete all required fields before submitting.',
      );
    }
  }

  void _showError(String fallback) {
    final err = ref.read(profileCompletionNotifierProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err is Failure ? err.message : fallback),
        backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(workerProfileProvider);
    final isSaving = ref.watch(profileCompletionNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Complete Profile',
          style: TextStyle(color: _kDark, fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: profileAsync.when(
        skipError: true,
        loading: () => const Center(child: CircularProgressIndicator(color: _kOrange)),
        error: (err, _) => Center(
          child: Text(err is Failure ? err.message : 'Failed to load profile.'),
        ),
        data: (profile) {
          _prefillFrom(profile);
          final editable = _isEditable(profile.onboardingStatus);
          final mainSkillName =
              profile.skills.isNotEmpty ? profile.skills.first.categoryName : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusBanner(profile: profile),
                const SizedBox(height: 16),

                _SectionLabel('Full Legal Name'),
                _TextInput(
                  controller: _fullLegalNameCtrl,
                  hint: 'As written on your CNIC',
                  enabled: editable,
                ),
                const SizedBox(height: 16),

                _SectionLabel('Main Skill'),
                _MainSkillRow(
                  skillName: mainSkillName,
                  editable: editable,
                  onChangeTap: () => showSkillsSheet(context, ref),
                ),
                const SizedBox(height: 16),

                _SectionLabel('Experience in Years'),
                _TextInput(
                  controller: _experienceYearsCtrl,
                  hint: 'e.g. 3',
                  enabled: editable,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                _SectionLabel('Residential Address'),
                _TextInput(
                  controller: _residentialAddressCtrl,
                  hint: 'House #, street, area, city',
                  enabled: editable,
                  maxLines: 3,
                ),
                const SizedBox(height: 20),

                _SectionLabel('Identity Documents'),
                const SizedBox(height: 8),
                _DocumentTile(
                  label: 'CNIC Front',
                  imageUrl: profile.cnicFrontUrl,
                  uploading: _uploadingCnicFront,
                  editable: editable,
                  onTap: () => _pickAndUpload(
                    (f) => ref.read(profileCompletionNotifierProvider.notifier).uploadCnicFront(f),
                    (v) => _uploadingCnicFront = v,
                  ),
                ),
                const SizedBox(height: 10),
                _DocumentTile(
                  label: 'CNIC Back',
                  imageUrl: profile.cnicBackUrl,
                  uploading: _uploadingCnicBack,
                  editable: editable,
                  onTap: () => _pickAndUpload(
                    (f) => ref.read(profileCompletionNotifierProvider.notifier).uploadCnicBack(f),
                    (v) => _uploadingCnicBack = v,
                  ),
                ),
                const SizedBox(height: 10),
                _DocumentTile(
                  label: 'Live Selfie',
                  imageUrl: profile.liveSelfieUrl,
                  uploading: _uploadingSelfie,
                  editable: editable,
                  onTap: () => _pickAndUpload(
                    (f) => ref.read(profileCompletionNotifierProvider.notifier).uploadLiveSelfie(f),
                    (v) => _uploadingSelfie = v,
                  ),
                ),
                const SizedBox(height: 20),

                _SectionLabel('Agreements'),
                const SizedBox(height: 8),
                _AgreementCheckbox(
                  value: _legalNameConfirmed,
                  enabled: editable,
                  label: 'I confirm my legal name matches my CNIC.',
                  onChanged: (v) => setState(() => _legalNameConfirmed = v),
                ),
                _AgreementCheckbox(
                  value: _generalAgreementAccepted,
                  enabled: editable,
                  label: 'I accept the General Ustaad Agreement.',
                  linkLabel: 'View Agreement',
                  onViewTap: () => _showAgreementPlaceholder(
                    context,
                    'General Ustaad Agreement',
                  ),
                  onChanged: (v) => setState(() => _generalAgreementAccepted = v),
                ),
                _AgreementCheckbox(
                  value: _tradeAgreementAccepted,
                  enabled: editable,
                  label: 'I accept the Trade-specific Agreement.',
                  linkLabel: 'View Agreement',
                  onViewTap: () => _showAgreementPlaceholder(
                    context,
                    'Trade-specific Agreement',
                  ),
                  onChanged: (v) => setState(() => _tradeAgreementAccepted = v),
                ),
                const SizedBox(height: 24),

                if (editable)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : () => _submit(profile),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Submit for Approval',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAgreementPlaceholder(BuildContext context, String title) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: const Text(
          'Agreement text will be added here soon. Placeholder for now.',
          style: TextStyle(color: _kGray, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ── Status banner ─────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final WorkerProfileEntity profile;
  const _StatusBanner({required this.profile});

  (String, Color, Color, IconData) get _visual => switch (profile.onboardingStatus) {
        'SUBMITTED_FOR_REVIEW' => (
            'Submitted for Review',
            const Color(0xFFB45309),
            const Color(0xFFFFFBEB),
            Icons.hourglass_top_rounded,
          ),
        'CHANGES_REQUIRED' => (
            'Changes Required',
            const Color(0xFFB45309),
            const Color(0xFFFFF7ED),
            Icons.edit_note_rounded,
          ),
        'REJECTED' => (
            'Rejected',
            _kRed,
            const Color(0xFFFEF2F2),
            Icons.cancel_outlined,
          ),
        'APPROVED' => (
            'Approved',
            const Color(0xFF15803D),
            const Color(0xFFF0FDF4),
            Icons.verified_rounded,
          ),
        _ => (
            'Draft',
            _kGray,
            const Color(0xFFF1F5F9),
            Icons.description_outlined,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg, icon) = _visual;
    final reason = profile.onboardingStatus == 'CHANGES_REQUIRED'
        ? profile.changesRequiredReason
        : profile.onboardingStatus == 'REJECTED'
            ? profile.rejectionReason
            : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fg),
              ),
            ],
          ),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              reason,
              style: TextStyle(fontSize: 12.5, color: fg.withValues(alpha: 0.9), height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Shared small widgets ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kDark),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final int maxLines;
  final TextInputType? keyboardType;

  const _TextInput({
    required this.controller,
    required this.hint,
    required this.enabled,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: _kDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _kLight, fontSize: 13),
        filled: true,
        fillColor: enabled ? Colors.white : const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          borderSide: const BorderSide(color: _kOrange),
        ),
      ),
    );
  }
}

class _MainSkillRow extends StatelessWidget {
  final String? skillName;
  final bool editable;
  final VoidCallback onChangeTap;

  const _MainSkillRow({
    required this.skillName,
    required this.editable,
    required this.onChangeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              skillName ?? 'Not selected',
              style: TextStyle(
                fontSize: 14,
                color: skillName != null ? _kDark : _kLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (editable)
            GestureDetector(
              onTap: onChangeTap,
              child: const Text(
                'Change',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kOrange),
              ),
            ),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final bool uploading;
  final bool editable;
  final VoidCallback onTap;

  const _DocumentTile({
    required this.label,
    required this.imageUrl,
    required this.uploading,
    required this.editable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final uploaded = imageUrl != null && imageUrl!.isNotEmpty;
    return GestureDetector(
      onTap: (editable && !uploading) ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: uploaded ? _kGreen.withValues(alpha: 0.4) : _kBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: uploading
                  ? const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _kOrange),
                      ),
                    )
                  : uploaded
                      ? Image.network(imageUrl!, fit: BoxFit.cover)
                      : const Icon(Icons.image_outlined, color: _kLight, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _kDark),
              ),
            ),
            Icon(
              uploaded ? Icons.check_circle_rounded : Icons.upload_outlined,
              size: 18,
              color: uploaded ? _kGreen : _kLight,
            ),
          ],
        ),
      ),
    );
  }
}

class _AgreementCheckbox extends StatelessWidget {
  final bool value;
  final bool enabled;
  final String label;
  final String? linkLabel;
  final VoidCallback? onViewTap;
  final ValueChanged<bool> onChanged;

  const _AgreementCheckbox({
    required this.value,
    required this.enabled,
    required this.label,
    required this.onChanged,
    this.linkLabel,
    this.onViewTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: value,
              activeColor: _kOrange,
              onChanged: enabled ? (v) => onChanged(v ?? false) : null,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, color: _kDark, height: 1.4),
                ),
                if (linkLabel != null && onViewTap != null)
                  GestureDetector(
                    onTap: onViewTap,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        linkLabel!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kOrange,
                        ),
                      ),
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
