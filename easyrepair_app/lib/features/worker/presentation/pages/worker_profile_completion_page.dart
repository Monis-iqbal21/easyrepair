import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/worker_profile_entity.dart';
import '../../domain/entities/agreement_template_entity.dart';
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

// Missing-field keys used by both the validation set and each widget's
// error lookup — kept as constants so a typo can't silently break a check.
const _kFieldFullLegalName = 'fullLegalName';
const _kFieldCnicNumber = 'cnicNumber';
const _kFieldMainSkill = 'mainSkill';
const _kFieldExperienceYears = 'experienceYears';
const _kFieldResidentialAddress = 'residentialAddress';
const _kFieldCnicFront = 'cnicFront';
const _kFieldCnicBack = 'cnicBack';
const _kFieldLiveSelfie = 'liveSelfie';
const _kFieldLegalNameConfirmed = 'legalNameConfirmed';
const _kFieldGeneralAgreement = 'generalAgreement';
const _kFieldTradeAgreement = 'tradeAgreement';

/// Formats free-typed or pasted input into Pakistan's CNIC layout
/// (12345-1234567-1) live as the user types. Strips everything but digits
/// first (so pasting an already-dashed CNIC just re-normalizes to the same
/// format), caps at 13 raw digits, then inserts dashes after digit 5 and
/// digit 12 — giving a fixed 15-character result (13 digits + 2 dashes).
class _CnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 13 ? digits.substring(0, 13) : digits;

    final buffer = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      if (i == 5 || i == 12) buffer.write('-');
      buffer.write(capped[i]);
    }
    final formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class WorkerProfileCompletionPage extends ConsumerStatefulWidget {
  const WorkerProfileCompletionPage({super.key});

  @override
  ConsumerState<WorkerProfileCompletionPage> createState() =>
      _WorkerProfileCompletionPageState();
}

class _WorkerProfileCompletionPageState
    extends ConsumerState<WorkerProfileCompletionPage> {
  static final _cnicPattern = RegExp(r'^\d{5}-\d{7}-\d{1}$');

  final _picker = ImagePicker();
  final _fullLegalNameCtrl = TextEditingController();
  final _cnicNumberCtrl = TextEditingController();
  final _residentialAddressCtrl = TextEditingController();
  final _experienceYearsCtrl = TextEditingController();

  bool _legalNameConfirmed = false;
  bool _generalAgreementAccepted = false;
  bool _tradeAgreementAccepted = false;
  bool _prefilled = false;
  bool _uploadingCnicFront = false;
  bool _uploadingCnicBack = false;
  bool _uploadingSelfie = false;

  /// Populated only after a failed Submit attempt — drives the red
  /// borders/helper text below. Cleared per-field as the worker fixes each
  /// one, so the form isn't stuck showing stale errors.
  Set<String> _missingFields = {};

  @override
  void dispose() {
    _fullLegalNameCtrl.dispose();
    _cnicNumberCtrl.dispose();
    _residentialAddressCtrl.dispose();
    _experienceYearsCtrl.dispose();
    super.dispose();
  }

  void _prefillFrom(WorkerProfileEntity profile) {
    if (_prefilled) return;
    _prefilled = true;
    _fullLegalNameCtrl.text = profile.fullLegalName ?? '';
    _cnicNumberCtrl.text = profile.cnicNumber ?? '';
    _residentialAddressCtrl.text = profile.residentialAddress ?? '';
    final exp = profile.skills.isNotEmpty ? profile.skills.first.yearsExperience : null;
    _experienceYearsCtrl.text = exp != null ? '$exp' : '';
    _legalNameConfirmed = profile.legalNameConfirmedAt != null;
    _generalAgreementAccepted = profile.generalAgreementAcceptedAt != null;
    _tradeAgreementAccepted = profile.tradeAgreementAcceptedAt != null;
  }

  bool _isEditable(String onboardingStatus) =>
      onboardingStatus == 'DRAFT' || onboardingStatus == 'CHANGES_REQUIRED';

  void _clearFieldError(String field) {
    if (_missingFields.contains(field)) {
      setState(() => _missingFields.remove(field));
    }
  }

  /// Bottom sheet letting the worker choose Camera or Gallery for a document
  /// photo. Camera is listed first for all three (Live Selfie should
  /// preferably use the camera; CNIC front/back are equally likely to be an
  /// existing gallery photo), so both options are always offered.
  static const _imageSourceOptions = [
    (ImageSource.camera, Icons.camera_alt_outlined, 'Take Photo'),
    (ImageSource.gallery, Icons.photo_library_outlined, 'Choose from Gallery'),
  ];

  Future<ImageSource?> _chooseImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            for (final (source, icon, label) in _imageSourceOptions)
              ListTile(
                leading: Icon(icon, color: _kOrange),
                title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, source),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(
    Future<String?> Function(File file) uploader,
    void Function(bool) setUploading,
    String fieldKey,
  ) async {
    final source = await _chooseImageSource();
    if (source == null || !mounted) return;

    final picked = await _picker.pickImage(
      source: source,
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
    } else {
      _clearFieldError(fieldKey);
    }
  }

  /// Computes every missing/invalid field against the current form + already
  /// -uploaded documents. Returns an empty set when everything required is
  /// present and valid.
  Set<String> _computeMissingFields(WorkerProfileEntity profile) {
    final missing = <String>{};
    if (_fullLegalNameCtrl.text.trim().isEmpty) missing.add(_kFieldFullLegalName);
    if (!_cnicPattern.hasMatch(_cnicNumberCtrl.text.trim())) {
      missing.add(_kFieldCnicNumber);
    }
    if (profile.skills.isEmpty) missing.add(_kFieldMainSkill);
    final years = int.tryParse(_experienceYearsCtrl.text.trim());
    if (years == null || years < 0) missing.add(_kFieldExperienceYears);
    if (_residentialAddressCtrl.text.trim().isEmpty) {
      missing.add(_kFieldResidentialAddress);
    }
    if (profile.cnicFrontUrl == null || profile.cnicFrontUrl!.isEmpty) {
      missing.add(_kFieldCnicFront);
    }
    if (profile.cnicBackUrl == null || profile.cnicBackUrl!.isEmpty) {
      missing.add(_kFieldCnicBack);
    }
    if (profile.liveSelfieUrl == null || profile.liveSelfieUrl!.isEmpty) {
      missing.add(_kFieldLiveSelfie);
    }
    if (!_legalNameConfirmed) missing.add(_kFieldLegalNameConfirmed);
    if (!_generalAgreementAccepted) missing.add(_kFieldGeneralAgreement);
    if (!_tradeAgreementAccepted) missing.add(_kFieldTradeAgreement);
    return missing;
  }

  Future<void> _submit(WorkerProfileEntity profile) async {
    final missing = _computeMissingFields(profile);
    setState(() => _missingFields = missing);

    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete the highlighted fields below.'),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final years = int.parse(_experienceYearsCtrl.text.trim());
    final notifier = ref.read(profileCompletionNotifierProvider.notifier);
    final saved = await notifier.save(
      fullLegalName: _fullLegalNameCtrl.text.trim(),
      cnicNumber: _cnicNumberCtrl.text.trim(),
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
    final templatesAsync = ref.watch(agreementTemplatesProvider);
    final templates = templatesAsync.asData?.value ?? const <AgreementTemplateEntity>[];
    AgreementTemplateEntity? findTemplate(bool general) {
      for (final t in templates) {
        if (general ? t.isGeneral : t.isTrade) return t;
      }
      return null;
    }

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
                  hasError: _missingFields.contains(_kFieldFullLegalName),
                  errorText: 'Full legal name is required.',
                  onChanged: (_) => _clearFieldError(_kFieldFullLegalName),
                ),
                const SizedBox(height: 16),

                _SectionLabel('CNIC Number'),
                _TextInput(
                  controller: _cnicNumberCtrl,
                  hint: '12345-1234567-1',
                  enabled: editable,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_CnicInputFormatter()],
                  hasError: _missingFields.contains(_kFieldCnicNumber),
                  errorText: 'Enter CNIC like 12345-1234567-1',
                  onChanged: (_) => _clearFieldError(_kFieldCnicNumber),
                ),
                const SizedBox(height: 16),

                _SectionLabel('Main Skill'),
                _MainSkillRow(
                  skillName: mainSkillName,
                  editable: editable,
                  hasError: _missingFields.contains(_kFieldMainSkill),
                  onChangeTap: () async {
                    await showSkillsSheet(context, ref);
                    _clearFieldError(_kFieldMainSkill);
                  },
                ),
                const SizedBox(height: 16),

                _SectionLabel('Experience in Years'),
                _TextInput(
                  controller: _experienceYearsCtrl,
                  hint: 'e.g. 3',
                  enabled: editable,
                  keyboardType: TextInputType.number,
                  hasError: _missingFields.contains(_kFieldExperienceYears),
                  errorText: 'Enter a valid number of years (0 or more).',
                  onChanged: (_) => _clearFieldError(_kFieldExperienceYears),
                ),
                const SizedBox(height: 16),

                _SectionLabel('Residential Address'),
                _TextInput(
                  controller: _residentialAddressCtrl,
                  hint: 'House #, street, area, city',
                  enabled: editable,
                  maxLines: 3,
                  hasError: _missingFields.contains(_kFieldResidentialAddress),
                  errorText: 'Residential address is required.',
                  onChanged: (_) => _clearFieldError(_kFieldResidentialAddress),
                ),
                const SizedBox(height: 20),

                _SectionLabel('Identity Documents'),
                const SizedBox(height: 8),
                _DocumentTile(
                  label: 'CNIC Front',
                  imageUrl: profile.cnicFrontUrl,
                  uploading: _uploadingCnicFront,
                  editable: editable,
                  hasError: _missingFields.contains(_kFieldCnicFront),
                  onTap: () => _pickAndUpload(
                    (f) => ref.read(profileCompletionNotifierProvider.notifier).uploadCnicFront(f),
                    (v) => _uploadingCnicFront = v,
                    _kFieldCnicFront,
                  ),
                ),
                const SizedBox(height: 10),
                _DocumentTile(
                  label: 'CNIC Back',
                  imageUrl: profile.cnicBackUrl,
                  uploading: _uploadingCnicBack,
                  editable: editable,
                  hasError: _missingFields.contains(_kFieldCnicBack),
                  onTap: () => _pickAndUpload(
                    (f) => ref.read(profileCompletionNotifierProvider.notifier).uploadCnicBack(f),
                    (v) => _uploadingCnicBack = v,
                    _kFieldCnicBack,
                  ),
                ),
                const SizedBox(height: 10),
                _DocumentTile(
                  label: 'Live Selfie',
                  imageUrl: profile.liveSelfieUrl,
                  uploading: _uploadingSelfie,
                  editable: editable,
                  hasError: _missingFields.contains(_kFieldLiveSelfie),
                  onTap: () => _pickAndUpload(
                    (f) => ref.read(profileCompletionNotifierProvider.notifier).uploadLiveSelfie(f),
                    (v) => _uploadingSelfie = v,
                    _kFieldLiveSelfie,
                  ),
                ),
                const SizedBox(height: 20),

                _SectionLabel('Agreements'),
                const SizedBox(height: 8),
                _AgreementCheckbox(
                  value: _legalNameConfirmed,
                  enabled: editable,
                  hasError: _missingFields.contains(_kFieldLegalNameConfirmed),
                  label: 'I confirm my legal name matches my CNIC.',
                  onChanged: (v) {
                    setState(() => _legalNameConfirmed = v);
                    if (v) _clearFieldError(_kFieldLegalNameConfirmed);
                  },
                ),
                _AgreementCheckbox(
                  value: _generalAgreementAccepted,
                  enabled: editable,
                  hasError: _missingFields.contains(_kFieldGeneralAgreement),
                  label: 'I accept the General Ustaad Agreement'
                      '${findTemplate(true) != null ? ' (v${findTemplate(true)!.version})' : ''}.',
                  linkLabel: 'View Agreement',
                  onViewTap: () => _showAgreement(context, findTemplate(true)),
                  onChanged: (v) {
                    setState(() => _generalAgreementAccepted = v);
                    if (v) _clearFieldError(_kFieldGeneralAgreement);
                  },
                ),
                _AgreementCheckbox(
                  value: _tradeAgreementAccepted,
                  enabled: editable,
                  hasError: _missingFields.contains(_kFieldTradeAgreement),
                  label: 'I accept the Trade-specific Agreement'
                      '${findTemplate(false) != null ? ' (v${findTemplate(false)!.version})' : ''}.',
                  linkLabel: 'View Agreement',
                  onViewTap: () => _showAgreement(context, findTemplate(false)),
                  onChanged: (v) {
                    setState(() => _tradeAgreementAccepted = v);
                    if (v) _clearFieldError(_kFieldTradeAgreement);
                  },
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

  /// Shows the exact text/version of the agreement the worker is about to
  /// accept. [template] is null while still loading (no active template
  /// fetched yet, e.g. before a main skill is selected for the trade
  /// agreement) — shown as a friendly notice rather than a blank dialog.
  void _showAgreement(BuildContext context, AgreementTemplateEntity? template) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          template?.title ?? 'Agreement',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: template != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Version ${template.version}',
                        style: const TextStyle(
                          color: _kOrange,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        template.contentText,
                        style: const TextStyle(color: _kDark, fontSize: 13, height: 1.5),
                      ),
                    ],
                  )
                : const Text(
                    'Select your main skill first to load this agreement.',
                    style: TextStyle(color: _kGray, fontSize: 13.5),
                  ),
          ),
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
  final bool hasError;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  const _TextInput({
    required this.controller,
    required this.hint,
    required this.enabled,
    this.maxLines = 1,
    this.keyboardType,
    this.hasError = false,
    this.errorText,
    this.onChanged,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError ? _kRed : _kBorder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14, color: _kDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _kLight, fontSize: 13),
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF1F5F9),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor, width: hasError ? 1.4 : 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor, width: hasError ? 1.4 : 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: hasError ? _kRed : _kOrange),
            ),
          ),
        ),
        if (hasError && errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: const TextStyle(fontSize: 11.5, color: _kRed),
          ),
        ],
      ],
    );
  }
}

class _MainSkillRow extends StatelessWidget {
  final String? skillName;
  final bool editable;
  final bool hasError;
  final VoidCallback onChangeTap;

  const _MainSkillRow({
    required this.skillName,
    required this.editable,
    required this.onChangeTap,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: hasError ? _kRed : _kBorder, width: hasError ? 1.4 : 1),
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
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          const Text(
            'Please select your main skill.',
            style: TextStyle(fontSize: 11.5, color: _kRed),
          ),
        ],
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final bool uploading;
  final bool editable;
  final bool hasError;
  final VoidCallback onTap;

  const _DocumentTile({
    required this.label,
    required this.imageUrl,
    required this.uploading,
    required this.editable,
    required this.onTap,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final uploaded = imageUrl != null && imageUrl!.isNotEmpty;
    final borderColor = hasError ? _kRed : (uploaded ? _kGreen.withValues(alpha: 0.4) : _kBorder);
    return GestureDetector(
      onTap: (editable && !uploading) ? onTap : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: hasError ? 1.4 : 1),
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
          if (hasError) ...[
            const SizedBox(height: 4),
            const Text(
              'Required — ضروری ہے',
              style: TextStyle(fontSize: 11.5, color: _kRed),
            ),
          ],
        ],
      ),
    );
  }
}

class _AgreementCheckbox extends StatelessWidget {
  final bool value;
  final bool enabled;
  final bool hasError;
  final String label;
  final String? linkLabel;
  final VoidCallback? onViewTap;
  final ValueChanged<bool> onChanged;

  const _AgreementCheckbox({
    required this.value,
    required this.enabled,
    required this.label,
    required this.onChanged,
    this.hasError = false,
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
              side: hasError ? const BorderSide(color: _kRed, width: 1.4) : null,
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
                if (hasError) ...[
                  const SizedBox(height: 2),
                  const Text(
                    'This confirmation is required.',
                    style: TextStyle(fontSize: 11.5, color: _kRed),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
