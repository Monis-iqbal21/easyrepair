import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_semantic_colors.dart';
import '../../domain/entities/worker_profile_entity.dart';
import '../../domain/entities/agreement_template_entity.dart';
import '../providers/worker_providers.dart';
import '../pages/worker_home_page.dart' show showSkillsSheet;
import '../pages/agreement_viewer_page.dart';
import '../utils/agreement_labels.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/permissions/media_permission_helper.dart';

// Missing-field keys used by both the validation set and each widget's
// error lookup — kept as constants so a typo can't silently break a check.
const _kFieldFullLegalName = 'fullLegalName';
const _kFieldFatherName = 'fatherName';
const _kFieldCnicNumber = 'cnicNumber';
const _kFieldDateOfBirth = 'dateOfBirth';
const _kFieldMainSkill = 'mainSkill';
const _kFieldExperienceYears = 'experienceYears';
const _kFieldResidentialAddress = 'residentialAddress';
const _kFieldCnicFront = 'cnicFront';
const _kFieldCnicBack = 'cnicBack';
const _kFieldLiveSelfie = 'liveSelfie';
const _kFieldLegalNameConfirmed = 'legalNameConfirmed';

/// One error key per agreement row, so the right row goes red.
// l10n-ignore: Internal error-set key, matched in code and never rendered
String _agreementFieldKey(String documentType) => 'agreement:$documentType';

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
  final _fatherNameCtrl = TextEditingController();
  final _cnicNumberCtrl = TextEditingController();
  final _residentialAddressCtrl = TextEditingController();
  final _experienceYearsCtrl = TextEditingController();
  final _emergencyContactCtrl = TextEditingController();

  /// ISO calendar date (yyyy-MM-dd), which is exactly what the backend stores
  /// and what the legal document prints — no timezone can shift it by a day.
  String? _dateOfBirth;

  bool _legalNameConfirmed = false;
  bool _prefilled = false;
  bool _uploadingCnicFront = false;
  bool _uploadingCnicBack = false;
  bool _uploadingSelfie = false;
  bool _submitting = false;

  /// Per-document proof that THIS exact agreement was opened, plus whether the
  /// box was then ticked. Keyed by documentType, so each of the three carries
  /// its own independent state.
  ///
  /// Nothing is reconciled when the trade changes: an entry is only honoured
  /// while it still `matches` the currently-loaded template, so a new trade
  /// schedule (different hash/trade) silently invalidates just its own row and
  /// leaves the General and EVS acceptances alone.
  final Map<String, AgreementEvidence> _evidence = {};

  /// Generated once for the whole submit attempt, so a retry after a timeout
  /// returns the SAME three sealed records instead of creating a second set.
  String? _submissionAttemptId;

  /// Populated only after a failed Submit attempt — drives the red
  /// borders/helper text below. Cleared per-field as the worker fixes each
  /// one, so the form isn't stuck showing stale errors.
  Set<String> _missingFields = {};

  @override
  void dispose() {
    _fullLegalNameCtrl.dispose();
    _fatherNameCtrl.dispose();
    _cnicNumberCtrl.dispose();
    _residentialAddressCtrl.dispose();
    _experienceYearsCtrl.dispose();
    _emergencyContactCtrl.dispose();
    super.dispose();
  }

  void _prefillFrom(WorkerProfileEntity profile) {
    if (_prefilled) return;
    _prefilled = true;
    _fullLegalNameCtrl.text = profile.fullLegalName ?? '';
    _fatherNameCtrl.text = profile.fatherName ?? '';
    _cnicNumberCtrl.text = profile.cnicNumber ?? '';
    _residentialAddressCtrl.text = profile.residentialAddress ?? '';
    _emergencyContactCtrl.text = profile.emergencyContact ?? '';
    _dateOfBirth = profile.dateOfBirth;
    final exp =
        profile.skills.isNotEmpty ? profile.skills.first.yearsExperience : null;
    _experienceYearsCtrl.text = exp != null ? '$exp' : '';
    _legalNameConfirmed = profile.legalNameConfirmedAt != null;
    // Agreement acceptance is deliberately NOT prefilled from the profile.
    // The old two date columns are not evidence that this Ustaad read the
    // current documents, so every submission starts from an unchecked box.
  }

  bool _isEditable(String onboardingStatus) =>
      onboardingStatus == 'DRAFT' || onboardingStatus == 'CHANGES_REQUIRED';

  void _clearFieldError(String field) {
    if (_missingFields.contains(field)) {
      setState(() => _missingFields.remove(field));
    }
  }

  // ── Agreement state (derived, never reconciled) ───────────────────────────

  /// The stored evidence for [template], but only while it still describes it.
  /// A version, hash, language or trade change makes the stored entry stale,
  /// which is what forces the Ustaad to open and accept that document again.
  AgreementEvidence? _evidenceFor(AgreementTemplateEntity template) {
    final stored = _evidence[template.documentType];
    if (stored == null || !stored.matches(template)) return null;
    return stored;
  }

  bool _isViewed(AgreementTemplateEntity t) => _evidenceFor(t) != null;

  bool _isAccepted(AgreementTemplateEntity t) =>
      _evidenceFor(t)?.checkboxAccepted ?? false;

  /// True when this row was viewed against a document that has since changed —
  /// the "your trade changed, open it again" case.
  bool _isStale(AgreementTemplateEntity t) =>
      _evidence[t.documentType] != null && _evidenceFor(t) == null;

  Future<void> _openAgreement(AgreementTemplateEntity template) async {
    final result = await Navigator.of(context).push<AgreementEvidence>(
      MaterialPageRoute(
        builder: (_) => AgreementViewerPage(documentType: template.documentType),
      ),
    );
    if (!mounted) return;
    // Null means the viewer never rendered the document (load failed, or an
    // unsupported trade). That must NOT unlock the checkbox.
    if (result == null) return;
    setState(() {
      _evidence[template.documentType] = result;
      _missingFields.remove(_agreementFieldKey(template.documentType));
    });
  }

  void _setAccepted(AgreementTemplateEntity template, bool value) {
    // Opening the viewer is optional. When the Ustaad ticks a row they have
    // not opened, the evidence is built from the template they were shown —
    // the same documentType/version/sourceHash/locale/trade the backend
    // seals — but with NO viewedAt, because nothing was viewed. The record
    // says "accepted, not viewed" rather than claiming a reading that never
    // happened; opening the viewer is what supplies a real timestamp.
    final existing =
        _evidenceFor(template) ?? template.evidenceUnviewed();
    setState(() {
      _evidence[template.documentType] =
          existing.copyWith(checkboxAccepted: value);
      if (value) {
        _missingFields.remove(_agreementFieldKey(template.documentType));
      }
    });
  }

  // ── Images ────────────────────────────────────────────────────────────────

  /// Bottom sheet letting the worker choose Camera or Gallery for a document
  /// photo. Camera is listed first for all three (Live Selfie should
  /// preferably use the camera; CNIC front/back are equally likely to be an
  /// existing gallery photo), so both options are always offered.
  List<(ImageSource, IconData, String)> _imageSourceOptions(
    AppLocalizations l10n,
  ) =>
      [
        (ImageSource.camera, Icons.camera_alt_outlined, l10n.chatTakePhoto),
        (
          ImageSource.gallery,
          Icons.photo_library_outlined,
          l10n.inspFormChooseFromGallery,
        ),
      ];

  Future<ImageSource?> _chooseImageSource() {
    final c = context.semanticColors;
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: c.surface,
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
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            for (final (source, icon, label)
                in _imageSourceOptions(context.l10n))
              ListTile(
                leading: Icon(icon, color: c.primary),
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
    String fieldKey, {
    ImageSource? forceSource,
  }) async {
    final c = context.semanticColors;
    // The profile photo doubles as the identity-verification image, so it is
    // taken with the camera rather than picked from the gallery.
    final source = forceSource ?? await _chooseImageSource();
    if (source == null || !mounted) return;

    final picked = await pickImageWithRecovery(
      context,
      picker: _picker,
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
          content: Text(
              failureMessage(context.l10n, err, fallback: context.l10n.workerUploadFailed)),
          backgroundColor: c.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _clearFieldError(fieldKey);
    }
  }

  // ── Date of birth ─────────────────────────────────────────────────────────

  Future<void> _pickDateOfBirth() async {
    final today = DateTime.now();
    final initial = _parsedDateOfBirth ?? DateTime(today.year - 25, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1930),
      // A date of birth can never be in the future, so the picker cannot
      // offer one — the backend rejects it too.
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateOfBirth = _formatIsoDate(picked);
      _missingFields.remove(_kFieldDateOfBirth);
    });
  }

  DateTime? get _parsedDateOfBirth {
    final value = _dateOfBirth;
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static String _formatIsoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  // ── Validation & submit ───────────────────────────────────────────────────

  /// Computes every missing/invalid field against the current form, the
  /// already-uploaded documents, and the three agreements. Returns an empty
  /// set when everything required is present and valid.
  Set<String> _computeMissingFields(
    WorkerProfileEntity profile,
    List<AgreementTemplateEntity> templates,
  ) {
    final missing = <String>{};
    if (_fullLegalNameCtrl.text.trim().isEmpty) missing.add(_kFieldFullLegalName);
    if (_fatherNameCtrl.text.trim().isEmpty) missing.add(_kFieldFatherName);
    if (!_cnicPattern.hasMatch(_cnicNumberCtrl.text.trim())) {
      missing.add(_kFieldCnicNumber);
    }
    final dob = _parsedDateOfBirth;
    if (dob == null || dob.isAfter(DateTime.now())) {
      missing.add(_kFieldDateOfBirth);
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

    // Every document the backend returned must be ticked, plus the trade
    // schedule whenever it is absent — an unsupported trade blocks
    // submission rather than sending one agreement fewer.
    final required = <String>{
      ...templates.map((t) => t.documentType),
      kUstaadTradeAgreement,
    };
    for (final documentType in required) {
      AgreementTemplateEntity? template;
      for (final t in templates) {
        if (t.documentType == documentType) template = t;
      }
      if (template == null || !_isAccepted(template)) {
        missing.add(_agreementFieldKey(documentType));
      }
    }
    // Emergency contact is deliberately absent: the EVS document prints a
    // controlled "Not applicable" for it.
    return missing;
  }

  /// One id per submit attempt. Reused across retries of the same attempt so
  /// the backend's idempotency key resolves to the same three records.
  String _attemptId() {
    return _submissionAttemptId ??= 'sub-'
        '${DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(36)}-'
        '${Random().nextInt(0x7fffffff).toRadixString(36)}';
  }

  Future<void> _submit(
    WorkerProfileEntity profile,
    List<AgreementTemplateEntity> templates,
  ) async {
    final c = context.semanticColors;
    if (_submitting) return; // hard guard against a double tap

    final missing = _computeMissingFields(profile, templates);
    setState(() => _missingFields = missing);

    if (missing.isNotEmpty) {
      final agreementsMissing = missing.any((f) => f.startsWith('agreement:'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            agreementsMissing && missing.length == 1
                ? context.l10n.agreementsAllThreeRequired
                : context.l10n.workerCompleteHighlightedFields,
          ),
          backgroundColor: c.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    final years = int.parse(_experienceYearsCtrl.text.trim());
    final notifier = ref.read(profileCompletionNotifierProvider.notifier);

    final saved = await notifier.save(
      fullLegalName: _fullLegalNameCtrl.text.trim(),
      fatherName: _fatherNameCtrl.text.trim(),
      cnicNumber: _cnicNumberCtrl.text.trim(),
      dateOfBirth: _dateOfBirth,
      residentialAddress: _residentialAddressCtrl.text.trim(),
      emergencyContact: _emergencyContactCtrl.text.trim(),
      experienceYears: years,
      legalNameConfirmed: _legalNameConfirmed,
    );
    if (!mounted) return;
    if (!saved) {
      setState(() => _submitting = false);
      _showError(context.l10n.workerProfileSaveFailed);
      return;
    }

    // One evidence object per document the backend served, in its order.
    final evidence = <AgreementEvidence>[];
    for (final template in templates) {
      final stored = _evidence[template.documentType];
      if (stored != null) evidence.add(stored);
    }

    final accepted = await notifier.submit(
      submissionAttemptId: _attemptId(),
      agreements: evidence,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (accepted != null) {
      // A fresh attempt id next time; this one is spent.
      _submissionAttemptId = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.workerProfileSubmitted),
          backgroundColor: c.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // Form data and still-valid agreement state are untouched — only a
      // document the backend says changed becomes stale, and that is decided
      // by the template reload, not here.
      _showError(context.l10n.workerCompleteAllRequired);
    }
  }

  void _showError(String fallback) {
    final c = context.semanticColors;
    final err = ref.read(profileCompletionNotifierProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failureMessage(context.l10n, err, fallback: fallback)),
        backgroundColor: c.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final profileAsync = ref.watch(workerProfileProvider);
    final templatesAsync = ref.watch(agreementTemplatesProvider);
    final templates =
        templatesAsync.asData?.value ?? const <AgreementTemplateEntity>[];
    final busy = _submitting ||
        ref.watch(profileCompletionNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.l10n.workerCompleteProfile,
          style: TextStyle(
              color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: profileAsync.when(
        skipError: true,
        loading: () => Center(child: CircularProgressIndicator(color: c.primary)),
        error: (err, _) => Center(
          child: Text(failureMessage(context.l10n, err, fallback: context.l10n.workerProfileLoadFailed)),
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

                _SectionLabel(context.l10n.workerFullLegalName),
                _TextInput(
                  controller: _fullLegalNameCtrl,
                  hint: context.l10n.workerLegalNameHint,
                  enabled: editable,
                  hasError: _missingFields.contains(_kFieldFullLegalName),
                  errorText: context.l10n.workerLegalNameRequired,
                  onChanged: (_) => _clearFieldError(_kFieldFullLegalName),
                ),
                const SizedBox(height: 16),

                _SectionLabel(context.l10n.workerFatherName),
                _TextInput(
                  controller: _fatherNameCtrl,
                  hint: context.l10n.workerLegalNameHint,
                  enabled: editable,
                  hasError: _missingFields.contains(_kFieldFatherName),
                  errorText: context.l10n.workerFatherNameRequired,
                  onChanged: (_) => _clearFieldError(_kFieldFatherName),
                ),
                const SizedBox(height: 16),

                _SectionLabel(context.l10n.workerCnicNumber),
                _TextInput(
                  controller: _cnicNumberCtrl,
                  hint: '12345-1234567-1',
                  enabled: editable,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_CnicInputFormatter()],
                  hasError: _missingFields.contains(_kFieldCnicNumber),
                  errorText: context.l10n.workerCnicInvalid,
                  onChanged: (_) => _clearFieldError(_kFieldCnicNumber),
                ),
                const SizedBox(height: 16),

                _SectionLabel(context.l10n.workerDateOfBirth),
                _DateInput(
                  value: _dateOfBirth,
                  hint: context.l10n.workerDateOfBirthHint,
                  enabled: editable,
                  hasError: _missingFields.contains(_kFieldDateOfBirth),
                  errorText: context.l10n.workerDateOfBirthRequired,
                  onTap: _pickDateOfBirth,
                ),
                const SizedBox(height: 16),

                _SectionLabel(context.l10n.workerMainSkill),
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

                _SectionLabel(context.l10n.workerExperienceYears),
                _TextInput(
                  controller: _experienceYearsCtrl,
                  hint: context.l10n.workerExperienceHint,
                  enabled: editable,
                  keyboardType: TextInputType.number,
                  hasError: _missingFields.contains(_kFieldExperienceYears),
                  errorText: context.l10n.workerExperienceInvalid,
                  onChanged: (_) => _clearFieldError(_kFieldExperienceYears),
                ),
                const SizedBox(height: 16),

                _SectionLabel(context.l10n.workerResidentialAddress),
                _TextInput(
                  controller: _residentialAddressCtrl,
                  hint: context.l10n.workerResidentialAddressHint,
                  enabled: editable,
                  maxLines: 3,
                  hasError: _missingFields.contains(_kFieldResidentialAddress),
                  errorText: context.l10n.workerResidentialAddressRequired,
                  onChanged: (_) => _clearFieldError(_kFieldResidentialAddress),
                ),
                const SizedBox(height: 16),

                _SectionLabel(context.l10n.workerEmergencyContact),
                _TextInput(
                  controller: _emergencyContactCtrl,
                  hint: context.l10n.workerEmergencyContactHint,
                  enabled: editable,
                ),
                const SizedBox(height: 20),

                _SectionLabel(context.l10n.workerIdentityDocuments),
                const SizedBox(height: 8),
                _DocumentTile(
                  label: context.l10n.workerCnicFront,
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
                  label: context.l10n.workerCnicBack,
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
                  label: context.l10n.profilePhotoTitle,
                  imageUrl: profile.liveSelfieUrl,
                  uploading: _uploadingSelfie,
                  editable: editable,
                  hasError: _missingFields.contains(_kFieldLiveSelfie),
                  onTap: () => _pickAndUpload(
                    (f) => ref.read(profileCompletionNotifierProvider.notifier).uploadLiveSelfie(f),
                    (v) => _uploadingSelfie = v,
                    _kFieldLiveSelfie,
                    forceSource: ImageSource.camera,
                  ),
                ),
                const SizedBox(height: 20),

                _SectionLabel(context.l10n.workerAgreements),
                const SizedBox(height: 8),
                _AgreementCheckbox(
                  value: _legalNameConfirmed,
                  enabled: editable,
                  hasError: _missingFields.contains(_kFieldLegalNameConfirmed),
                  label: context.l10n.workerConfirmLegalName,
                  onChanged: (v) {
                    setState(() => _legalNameConfirmed = v);
                    if (v) _clearFieldError(_kFieldLegalNameConfirmed);
                  },
                ),
                const SizedBox(height: 4),

                // One row per document the backend returned, in its order.
                // Nothing here assumes how many there are, so a newly
                // activated document or version appears without an app
                // release.
                ...templatesAsync.when(
                  loading: () => [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: CircularProgressIndicator(color: c.primary),
                      ),
                    ),
                  ],
                  error: (err, _) => [
                    _AgreementsError(
                      message: failureMessage(
                        context.l10n,
                        err,
                        fallback: context.l10n.agreementsLoadFailed,
                      ),
                      onRetry: () =>
                          ref.invalidate(agreementTemplatesProvider),
                    ),
                  ],
                  data: (loaded) => [
                    for (final template in loaded)
                      _agreementRow(loaded, template.documentType, editable),
                    // The backend omits the trade schedule when the Ustaad's
                    // trade has none. That must block submission rather than
                    // quietly show one row fewer.
                    if (loaded.isNotEmpty &&
                        !loaded.any((t) => t.documentType == kUstaadTradeAgreement))
                      _agreementRow(loaded, kUstaadTradeAgreement, editable),
                  ],
                ),
                const SizedBox(height: 24),

                if (editable)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          busy ? null : () => _submit(profile, templates),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: busy
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: c.onPrimary,
                              ),
                            )
                          : Text(
                              context.l10n.workerSubmitForApproval,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700),
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

  Widget _agreementRow(
    List<AgreementTemplateEntity> loaded,
    String documentType,
    bool editable,
  ) {
    AgreementTemplateEntity? template;
    for (final t in loaded) {
      if (t.documentType == documentType) template = t;
    }
    final fieldKey = _agreementFieldKey(documentType);

    if (template == null) {
      // The trade has no approved schedule. Blocked, never substituted.
      return _AgreementUnavailableRow(
        hasError: _missingFields.contains(fieldKey),
      );
    }

    return _AgreementRow(
      template: template,
      viewed: _isViewed(template),
      accepted: _isAccepted(template),
      stale: _isStale(template),
      enabled: editable,
      hasError: _missingFields.contains(fieldKey),
      onView: () => _openAgreement(template!),
      onChanged: (v) => _setAccepted(template!, v),
    );
  }
}

// ── Agreement row ────────────────────────────────────────────────────────────

/// One returned document: title, version, language, trade, a required marker,
/// an optional View link and the acceptance checkbox. The checkbox is
/// independent of the viewer - reading is offered, not enforced.
class _AgreementRow extends StatelessWidget {
  final AgreementTemplateEntity template;
  final bool viewed;
  final bool accepted;
  final bool stale;
  final bool enabled;
  final bool hasError;
  final VoidCallback onView;
  final ValueChanged<bool> onChanged;

  const _AgreementRow({
    required this.template,
    required this.viewed,
    required this.accepted,
    required this.stale,
    required this.enabled,
    required this.hasError,
    required this.onView,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError ? c.error : c.border,
          width: hasError ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                // Backend-authored agreement title — shown as-is.
                child: Text(
                  template.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.softTeal,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.workerDocumentRequired,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: c.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.workerAgreementVersion(template.version),
            style: TextStyle(fontSize: 12.5, color: c.textSecondary),
          ),
          Text(
            l10n.agreementLanguageChip(
              agreementLocaleLabel(l10n, template.agreementLocale),
            ),
            style: TextStyle(fontSize: 12.5, color: c.textSecondary),
          ),
          if (template.applicableTrade != null)
            Text(
              l10n.agreementTradeChip(
                tradeLabel(l10n, template.applicableTrade!),
              ),
              style: TextStyle(fontSize: 12.5, color: c.textSecondary),
            ),
          if (stale) ...[
            const SizedBox(height: 6),
            Text(
              l10n.agreementTradeChangedReopen,
              style: TextStyle(
                fontSize: 12.5,
                color: c.warning,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onView,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book_outlined, size: 15, color: c.primary),
                const SizedBox(width: 6),
                Text(
                  l10n.workerViewAgreement,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: c.primary,
                  ),
                ),
                if (viewed) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check_circle_rounded,
                      size: 14, color: c.success),
                ],
              ],
            ),
          ),
          Divider(height: 20, color: c.border),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: accepted,
                  activeColor: c.primary,
                  side: hasError
                      ? BorderSide(color: c.error, width: 1.4)
                      : null,
                  // Ticking is the Ustaad's own act - opening the viewer is
                  // offered, never required. The row still records which exact
                  // document/version/hash was accepted.
                  onChanged: enabled
                      ? (v) => onChanged(v ?? false)
                      : null,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.agreementAcceptCheckbox,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: c.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    if (hasError) ...[
                      const SizedBox(height: 2),
                      Text(
                        l10n.agreementAcceptRequired,
                        style: TextStyle(fontSize: 12.5, color: c.error),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown in place of the trade row when the selected trade has no approved
/// schedule. Deliberately offers no way forward — never another trade's text.
class _AgreementUnavailableRow extends StatelessWidget {
  final bool hasError;
  const _AgreementUnavailableRow({required this.hasError});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError ? c.error : c.border,
          width: hasError ? 1.4 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: c.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.agreementUnavailableForTrade,
              style: TextStyle(fontSize: 12.5, color: c.textSecondary, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgreementsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _AgreementsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(fontSize: 12.5, color: c.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onRetry,
            child: Text(
              context.l10n.commonRetry,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: c.primary,
              ),
            ),
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

  /// [profile.onboardingStatus] stays the raw backend token — only the words
  /// on the banner are translated.
  /// Takes the palette because a `=>` method has no `BuildContext` of its own.
  (String, Color, Color, IconData) _visual(
    AppLocalizations l10n,
    AppSemanticColors c,
  ) =>
      switch (profile.onboardingStatus) {
        'SUBMITTED_FOR_REVIEW' => (
            l10n.workerOnboardingSubmitted,
            c.warning,
            c.warningSurface,
            Icons.hourglass_top_rounded,
          ),
        'CHANGES_REQUIRED' => (
            l10n.workerOnboardingChangesRequired,
            c.warning,
            c.warningSurface,
            Icons.edit_note_rounded,
          ),
        'REJECTED' => (
            l10n.bidStatusRejected,
            c.error,
            c.urgentSoft,
            Icons.cancel_outlined,
          ),
        'APPROVED' => (
            l10n.workerOnboardingApproved,
            c.success,
            c.successSoft,
            Icons.verified_rounded,
          ),
        _ => (
            l10n.workerOnboardingDraft,
            c.textSecondary,
            c.surfaceSubtle,
            Icons.description_outlined,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final (label, fg, bg, icon) = _visual(context.l10n, c);
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg),
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
              style: TextStyle(fontSize: 12.5, color: fg, height: 1.4),
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
    final c = context.semanticColors;
    return Text(
      text,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary),
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
    final c = context.semanticColors;
    final borderColor = hasError ? c.error : c.border;
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
          style: TextStyle(fontSize: 14, color: c.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: c.textSecondary, fontSize: 14),
            filled: true,
            fillColor: enabled ? c.surface : c.surfaceSubtle,
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
              borderSide: BorderSide(color: hasError ? c.error : c.primary),
            ),
          ),
        ),
        if (hasError && errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: TextStyle(fontSize: 12.5, color: c.error),
          ),
        ],
      ],
    );
  }
}

/// Date of birth. Tapping opens the platform date picker, whose lastDate is
/// today — a future date is not selectable, and the backend rejects one too.
class _DateInput extends StatelessWidget {
  final String? value;
  final String hint;
  final bool enabled;
  final bool hasError;
  final String errorText;
  final VoidCallback onTap;

  const _DateInput({
    required this.value,
    required this.hint,
    required this.enabled,
    required this.hasError,
    required this.errorText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final hasValue = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: enabled ? c.surface : c.surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError ? c.error : c.border,
                width: hasError ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    // An ISO date needs no translation and must not be
                    // reformatted per language — it is what the legal
                    // document prints.
                    hasValue ? value! : hint,
                    style: TextStyle(
                      fontSize: 14,
                      color: hasValue ? c.textPrimary : c.textSecondary,
                    ),
                  ),
                ),
                Icon(Icons.calendar_today_outlined,
                    size: 16, color: c.textSecondary),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(errorText, style: TextStyle(fontSize: 12.5, color: c.error)),
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
    final c = context.semanticColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: hasError ? c.error : c.border, width: hasError ? 1.4 : 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  skillName ?? context.l10n.workerMainSkillNotSelected,
                  style: TextStyle(
                    fontSize: 14,
                    color: skillName != null ? c.textPrimary : c.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (editable)
                GestureDetector(
                  onTap: onChangeTap,
                  child: Text(
                    context.l10n.workerChangeSkill,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.primary),
                  ),
                ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(
            context.l10n.workerMainSkillRequired,
            style: TextStyle(fontSize: 12.5, color: c.error),
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
    final c = context.semanticColors;
    final borderColor =
        hasError ? c.error : (uploaded ? c.success : c.border);
    return GestureDetector(
      onTap: (editable && !uploading) ? onTap : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: hasError ? 1.4 : 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 42,
                  decoration: BoxDecoration(
                    color: c.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: uploading
                      ? Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
                          ),
                        )
                      : uploaded
                          ? Image.network(imageUrl!, fit: BoxFit.cover)
                          : Icon(Icons.image_outlined, color: c.textSecondary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
                  ),
                ),
                Icon(
                  uploaded ? Icons.check_circle_rounded : Icons.upload_outlined,
                  size: 18,
                  color: uploaded ? c.success : c.textSecondary,
                ),
              ],
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 4),
            Text(
              context.l10n.workerDocumentRequired,
              style: TextStyle(fontSize: 12.5, color: c.error),
            ),
          ],
        ],
      ),
    );
  }
}

/// The plain "I confirm…" checkbox (legal-name confirmation). The three
/// agreement rows use [_AgreementRow] instead, because they carry a
/// view-before-check gate this one does not need.
class _AgreementCheckbox extends StatelessWidget {
  final bool value;
  final bool enabled;
  final bool hasError;
  final String label;
  final ValueChanged<bool> onChanged;

  const _AgreementCheckbox({
    required this.value,
    required this.enabled,
    required this.label,
    required this.onChanged,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
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
              activeColor: c.primary,
              side: hasError ? BorderSide(color: c.error, width: 1.4) : null,
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
                  style: TextStyle(fontSize: 14, color: c.textPrimary, height: 1.4),
                ),
                if (hasError) ...[
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.workerConfirmationRequired,
                    style: TextStyle(fontSize: 12.5, color: c.error),
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
