import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/permissions/media_permission_helper.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../worker/domain/entities/category_entity.dart';
import '../../../worker/presentation/providers/worker_providers.dart';
import '../providers/auth_otp_providers.dart';
import '../providers/ustaad_registration_draft.dart';
import '../widgets/client_auth_widgets.dart';
import '../widgets/ustaad_register_widgets.dart';
import 'ustaad_register_step4_page.dart';

/// Ustaad registration, Step 3 of 4 — profile and work.
///
/// ONE scrolling page. The two reference screenshots are two scroll positions
/// of this screen, not two steps.
///
/// ## Where the account is created
///
/// "Aage" is the moment the Ustaad account comes into existence: it presents
/// the registration token from Step 2 to `POST /auth/worker/otp-register`
/// together with the trade, because that endpoint needs a main category. Once
/// the session is live it saves everything else through the endpoints the
/// profile-completion form has always used — `updateSkills`, `uploadAvatar`
/// and `updateProfileCompletion` — so Step 4 can then upload CNIC images and
/// seal agreements as an authenticated worker.
///
/// Coming back to this screen after that edits the profile instead of trying
/// to register again ([UstaadRegistrationDraft.accountCreated]).
///
/// ## What this step must collect, and why
///
/// `submitProfileForReview` refuses the whole submission unless the profile
/// carries `fullLegalName`, `fatherName`, `dateOfBirth`, `residentialAddress`,
/// `cnicNumber`, `legalNameConfirmedAt` and **exactly one** WorkerSkill. Father
/// name and date of birth are blanks in the Background Verification / EVS
/// Consent document the backend generates, so they are not optional detail —
/// without them Step 4 can never succeed. They are collected here, in the same
/// PATCH as the rest, using the same labels and the same ISO date shape as the
/// legacy profile-completion form.
class UstaadRegisterStep3Page extends ConsumerStatefulWidget {
  const UstaadRegisterStep3Page({super.key});

  static const route = '/auth/worker/register/profile';

  @override
  ConsumerState<UstaadRegisterStep3Page> createState() =>
      _UstaadRegisterStep3PageState();
}

// Missing-field keys, shared by the validation set and each widget's error
// lookup — the same pattern (and, where they overlap, the same names) the
// legacy profile-completion form uses, so a typo cannot silently skip a check.
const _kFieldPhoto = 'photo';
const _kFieldFatherName = 'fatherName';
const _kFieldDateOfBirth = 'dateOfBirth';
const _kFieldLegalNameConfirmed = 'legalNameConfirmed';
const _kFieldMainSkill = 'mainSkill';
const _kFieldExperience = 'experienceYears';
const _kFieldArea = 'area';
const _kFieldStreet = 'street';
const _kFieldHouse = 'house';

class _UstaadRegisterStep3PageState
    extends ConsumerState<UstaadRegisterStep3Page> {
  final _picker = ImagePicker();
  final _fatherNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _houseCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();

  File? _photo;

  /// Exactly one trade, or none yet. Singular by type because the backend is
  /// singular — see [UstaadRegistrationDraft.categoryId].
  String? _categoryId;
  int? _experienceYears;

  /// ISO calendar date (yyyy-MM-dd) — exactly what the backend stores and what
  /// the legal document prints, so no timezone can shift it by a day.
  String? _dateOfBirth;

  bool _legalNameConfirmed = false;
  bool _submitting = false;

  /// Populated when a "Aage" attempt is rejected. Drives the inline messages
  /// below, and each entry is cleared as its field is fixed so the form is
  /// never stuck showing a stale error.
  Set<String> _missingFields = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final draft = ref.read(ustaadRegistrationDraftProvider);
      _fatherNameCtrl.text = draft.fatherName;
      _dobCtrl.text = draft.dateOfBirth ?? '';
      _areaCtrl.text = draft.area;
      _streetCtrl.text = draft.street;
      _houseCtrl.text = draft.house;
      _landmarkCtrl.text = draft.landmark;
      setState(() {
        _photo = draft.photo;
        _categoryId = draft.categoryId;
        _experienceYears = draft.experienceYears;
        _dateOfBirth = draft.dateOfBirth;
        _legalNameConfirmed = draft.legalNameConfirmed;
      });
    });
  }

  @override
  void dispose() {
    _fatherNameCtrl.dispose();
    _dobCtrl.dispose();
    _areaCtrl.dispose();
    _streetCtrl.dispose();
    _houseCtrl.dispose();
    _landmarkCtrl.dispose();
    super.dispose();
  }

  // ── Validation ───────────────────────────────────────────────────────────

  /// Everything the backend will refuse the submission without, checked here so
  /// the Ustaad is told which field is missing rather than left staring at a
  /// button that does nothing. The backend remains the authority.
  Set<String> _computeMissingFields() {
    final missing = <String>{};
    if (_photo == null) missing.add(_kFieldPhoto);
    if (_fatherNameCtrl.text.trim().isEmpty) missing.add(_kFieldFatherName);
    final dob = _parsedDateOfBirth;
    if (dob == null || dob.isAfter(DateTime.now())) {
      missing.add(_kFieldDateOfBirth);
    }
    if (!_legalNameConfirmed) missing.add(_kFieldLegalNameConfirmed);
    if (_categoryId == null) missing.add(_kFieldMainSkill);
    if (_experienceYears == null) missing.add(_kFieldExperience);
    if (_areaCtrl.text.trim().isEmpty) missing.add(_kFieldArea);
    if (_streetCtrl.text.trim().isEmpty) missing.add(_kFieldStreet);
    if (_houseCtrl.text.trim().isEmpty) missing.add(_kFieldHouse);
    // Landmark is genuinely optional — the backend stores one free-text
    // address and composes it without the landmark just fine.
    return missing;
  }

  void _clearFieldError(String field) {
    if (_missingFields.contains(field)) {
      setState(() => _missingFields = {..._missingFields}..remove(field));
    }
  }

  bool _hasError(String field) => _missingFields.contains(field);

  DateTime? get _parsedDateOfBirth {
    final value = _dateOfBirth;
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static String _formatIsoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  // ── Draft ────────────────────────────────────────────────────────────────

  void _saveToDraft() {
    ref
        .read(ustaadRegistrationDraftProvider.notifier)
        .update(
          (d) => d.copyWith(
            photo: _photo,
            categoryId: _categoryId,
            experienceYears: _experienceYears,
            fatherName: _fatherNameCtrl.text.trim(),
            dateOfBirth: _dateOfBirth,
            legalNameConfirmed: _legalNameConfirmed,
            area: _areaCtrl.text.trim(),
            street: _streetCtrl.text.trim(),
            house: _houseCtrl.text.trim(),
            landmark: _landmarkCtrl.text.trim(),
          ),
        );
  }

  // ── Inputs ───────────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final picked = await pickImageWithRecovery(
      context,
      picker: _picker,
      source: ImageSource.gallery,
      // The same bounds the profile-completion uploads use, so the backend
      // sees images of the size it already expects.
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _photo = File(picked.path));
    _clearFieldError(_kFieldPhoto);
    _saveToDraft();
  }

  Future<void> _pickDateOfBirth() async {
    final today = DateTime.now();
    final initial = _parsedDateOfBirth ?? DateTime(today.year - 25, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1930),
      // A date of birth can never be in the future, so the picker cannot offer
      // one — the backend rejects it too. Same bounds as the legacy form.
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateOfBirth = _formatIsoDate(picked);
      _dobCtrl.text = _dateOfBirth!;
    });
    _clearFieldError(_kFieldDateOfBirth);
    _saveToDraft();
  }

  // ── Submit ───────────────────────────────────────────────────────────────

  /// Every step here is required, so every one of them is checked. A failure
  /// leaves the Ustaad on this screen with the error already on screen (each
  /// notifier's `AsyncError` is surfaced by the listeners in [build]) rather
  /// than carrying a half-saved profile into Step 4, where the submission
  /// would then be rejected for a reason set three screens earlier.
  Future<void> _continue() async {
    if (_submitting) return;

    final missing = _computeMissingFields();
    setState(() => _missingFields = missing);
    if (missing.isNotEmpty) {
      _showMessage(context.l10n.workerCompleteHighlightedFields);
      return;
    }

    setState(() => _submitting = true);
    _saveToDraft();

    try {
      final draft = ref.read(ustaadRegistrationDraftProvider);
      final categoryId = _categoryId!;

      if (!draft.accountCreated) {
        final token = draft.registrationToken;
        if (token == null) {
          // Step 2 was never completed — nothing to present, so send them back
          // rather than failing at the network.
          if (mounted) context.pop();
          return;
        }
        final created = await ref
            .read(workerOtpRegisterNotifierProvider.notifier)
            .register(
              fullName: draft.fullName,
              phone: draft.phone,
              password: draft.password,
              categoryId: categoryId,
              registrationToken: token,
            );
        if (!created) return;
        ref
            .read(ustaadRegistrationDraftProvider.notifier)
            .update((d) => d.copyWith(accountCreated: true));
      } else {
        // A return trip: the trade may have been changed since the account was
        // created with it, so re-assert it. Exactly one id, always — more than
        // one is the request `updateSkills` rejects outright, and it is also
        // what would flip `profileCompleted` to false and make the Ustaad
        // undiscoverable after approval.
        //
        // Ordered before the profile save on purpose: `replaceSkills` deletes
        // and recreates the skill row, which would drop the yearsExperience
        // that `updateProfileCompletion` writes onto it.
        final savedSkill = await ref
            .read(skillsNotifierProvider.notifier)
            .saveSkills([categoryId]);
        if (!savedSkill) return;
      }

      // From here the Ustaad is authenticated, so these are the ordinary
      // worker endpoints the profile-completion form has always called.
      final profile = ref.read(profileCompletionNotifierProvider.notifier);

      final photo = _photo;
      if (photo != null) {
        final uploaded = await profile.uploadAvatar(photo);
        // A dropped avatar used to be invisible: the result was discarded and
        // the flow moved on regardless.
        if (uploaded == null) return;
      }

      final saved = await profile.save(
        fullLegalName: draft.fullName,
        fatherName: _fatherNameCtrl.text.trim(),
        cnicNumber: draft.cnicNumber,
        dateOfBirth: _dateOfBirth,
        residentialAddress: draft.residentialAddress,
        experienceYears: _experienceYears,
        legalNameConfirmed: _legalNameConfirmed,
      );
      if (!mounted || !saved) return;

      context.push(UstaadRegisterStep4Page.route);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Where "back" goes once the account exists.
  ///
  /// Popping would land on Step 2 — a spent OTP screen under `/auth`, which
  /// the logged-in redirect then bounces to Worker Home behind the Ustaad's
  /// back. Going there deliberately is the same destination reached honestly,
  /// and Worker Home's resume path (`resumeOnboardingRoute`) brings them back
  /// into onboarding.
  void _leaveRegistration() => context.go('/worker/home');

  @override
  Widget build(BuildContext context) {
    ref.listen(workerOtpRegisterNotifierProvider, (_, state) {
      if (state is AsyncError) _showError(state.error);
    });
    ref.listen(profileCompletionNotifierProvider, (_, state) {
      if (state is AsyncError) _showError(state.error);
    });
    ref.listen(skillsNotifierProvider, (_, state) {
      if (state is AsyncError) _showError(state.error);
    });
    final draft = ref.watch(ustaadRegistrationDraftProvider);

    final l10n = context.l10n;
    final colors = context.semanticColors;

    return PopScope(
      // Before the account exists, Back is an ordinary pop to Step 2. After it
      // exists there is nothing sensible behind this screen, so the pop is
      // intercepted and turned into an explicit exit instead of a redirect
      // firing underneath the Ustaad.
      canPop: !draft.accountCreated,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leaveRegistration();
      },
      child: UstaadStepScaffold(
        cta: ClientPrimaryButton(
          label: l10n.postJobNext,
          isLoading: _submitting,
          // Always tappable. A disabled button that never says which field is
          // missing is what left Ustaads stuck on this screen; the tap now
          // highlights every missing field at once.
          onPressed: _continue,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UstaadStepHeader(
              title: l10n.clientProfileTitle,
              step: 3,
              onBack: draft.accountCreated ? _leaveRegistration : null,
            ),
            const SizedBox(height: 20),
            Text(
              l10n.ustaadStep3Heading,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.15,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.ustaadStepIndicator(3, 4),
              style: TextStyle(fontSize: 15, color: colors.textSecondary),
            ),
            const SizedBox(height: 18),
            _PhotoCard(
              photo: _photo,
              onUpload: _pickPhoto,
              hasError: _hasError(_kFieldPhoto),
            ),
            const SizedBox(height: 14),
            _IdentityCard(
              fatherNameCtrl: _fatherNameCtrl,
              dobCtrl: _dobCtrl,
              fatherNameError: _hasError(_kFieldFatherName),
              dateOfBirthError: _hasError(_kFieldDateOfBirth),
              legalNameConfirmed: _legalNameConfirmed,
              legalNameError: _hasError(_kFieldLegalNameConfirmed),
              onFatherNameChanged: () {
                _clearFieldError(_kFieldFatherName);
                _saveToDraft();
              },
              onPickDateOfBirth: _pickDateOfBirth,
              onLegalNameChanged: (value) {
                setState(() => _legalNameConfirmed = value);
                if (value) _clearFieldError(_kFieldLegalNameConfirmed);
                _saveToDraft();
              },
            ),
            const SizedBox(height: 14),
            _SkillsCard(
              selected: _categoryId,
              hasError: _hasError(_kFieldMainSkill),
              onChanged: (id) {
                setState(() => _categoryId = id);
                _clearFieldError(_kFieldMainSkill);
                _saveToDraft();
              },
            ),
            const SizedBox(height: 14),
            UstaadSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UstaadSectionTitle(l10n.ustaadExperienceTitle),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final band in experienceBands)
                        UstaadChoiceChip(
                          label: band.label,
                          rounded: false,
                          selected: _experienceYears == band.years,
                          onTap: () {
                            // One band at a time — the backend stores a single
                            // experienceYears integer.
                            setState(() => _experienceYears = band.years);
                            _clearFieldError(_kFieldExperience);
                            _saveToDraft();
                          },
                        ),
                    ],
                  ),
                  if (_hasError(_kFieldExperience))
                    UstaadFieldError(l10n.workerExperienceInvalid),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _AddressCard(
              areaCtrl: _areaCtrl,
              streetCtrl: _streetCtrl,
              houseCtrl: _houseCtrl,
              landmarkCtrl: _landmarkCtrl,
              areaError: _hasError(_kFieldArea),
              streetError: _hasError(_kFieldStreet),
              houseError: _hasError(_kFieldHouse),
              onChanged: (field) {
                setState(() {});
                if (field != null) _clearFieldError(field);
                _saveToDraft();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showError(Object? error) {
    if (!mounted) return;
    _showMessage(
      failureMessage(context.l10n, error, fallback: context.l10n.authErrorGeneric),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.photo,
    required this.onUpload,
    required this.hasError,
  });

  final File? photo;
  final VoidCallback onUpload;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.semanticColors;

    return UstaadSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  shape: BoxShape.circle,
                ),
                child: photo != null
                    ? Image.file(photo!, fit: BoxFit.cover)
                    : Center(
                        child: Text(
                          l10n.ustaadPhotoPlaceholder,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: UstaadSectionTitle(
                  l10n.ustaadPhotoTitle,
                  subtitle: l10n.ustaadPhotoSubtitle,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: onUpload,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textPrimary,
                  side: BorderSide(color: colors.controlBorder),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l10n.ustaadPhotoUpload,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (hasError) UstaadFieldError(l10n.workerDocumentRequired),
        ],
      ),
    );
  }
}

/// Father's name, date of birth and the legal-name confirmation.
///
/// All three exist because `submitProfileForReview` refuses without them: the
/// first two are printed blanks in the Background Verification / EVS Consent
/// document, and the third is what makes the backend stamp
/// `legalNameConfirmedAt`. Labels, hint and wording are the ones the legacy
/// profile-completion form already uses, so nothing new had to be translated.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.fatherNameCtrl,
    required this.dobCtrl,
    required this.fatherNameError,
    required this.dateOfBirthError,
    required this.legalNameConfirmed,
    required this.legalNameError,
    required this.onFatherNameChanged,
    required this.onPickDateOfBirth,
    required this.onLegalNameChanged,
  });

  final TextEditingController fatherNameCtrl;
  final TextEditingController dobCtrl;
  final bool fatherNameError;
  final bool dateOfBirthError;
  final bool legalNameConfirmed;
  final bool legalNameError;
  final VoidCallback onFatherNameChanged;
  final VoidCallback onPickDateOfBirth;
  final ValueChanged<bool> onLegalNameChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.semanticColors;

    return UstaadSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UstaadSectionTitle(l10n.ustaadIdentityTitle),
          const SizedBox(height: 16),
          ClientFieldLabel(l10n.workerFatherName),
          ClientTextField(
            controller: fatherNameCtrl,
            hint: l10n.workerLegalNameHint,
            forceError: fatherNameError,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? l10n.workerFatherNameRequired
                : null,
            onChanged: (_) => onFatherNameChanged(),
          ),
          const SizedBox(height: 14),
          ClientFieldLabel(l10n.workerDateOfBirth),
          ClientTextField(
            controller: dobCtrl,
            hint: l10n.workerDateOfBirthHint,
            // Picker-driven: the field never takes keyboard input, so it never
            // has to defend against a malformed date.
            readOnly: true,
            onTap: onPickDateOfBirth,
            textInputAction: TextInputAction.done,
            forceError: dateOfBirthError,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? l10n.workerDateOfBirthRequired
                : null,
            suffix: Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, end: 16),
              child: Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                checked: legalNameConfirmed,
                child: Checkbox(
                  value: legalNameConfirmed,
                  onChanged: (v) => onLegalNameChanged(v ?? false),
                  activeColor: colors.primary,
                  checkColor: colors.onPrimary,
                  side: BorderSide(color: colors.controlBorder, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    l10n.workerConfirmLegalName,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (legalNameError)
            UstaadFieldError(l10n.workerConfirmationRequired),
        ],
      ),
    );
  }
}

/// The trades, straight from the live category list — never a hardcoded set,
/// so a category the admin adds (Appliances Repair, say) appears here without
/// a code change.
///
/// SINGLE select. `updateSkills` throws "Only one main skill is allowed." for
/// anything longer, `UpdateSkillsDto` carries `@ArrayMaxSize(1)`, and
/// `profileCompleted` — which every discovery query filters on — means "has
/// exactly one WorkerSkill". Tapping a second trade therefore replaces the
/// first rather than adding to it.
class _SkillsCard extends ConsumerWidget {
  const _SkillsCard({
    required this.selected,
    required this.hasError,
    required this.onChanged,
  });

  final String? selected;
  final bool hasError;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.semanticColors;
    final categories = ref.watch(categoriesProvider);

    return UstaadSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UstaadSectionTitle(l10n.ustaadSkillsTitle),
          const SizedBox(height: 14),
          categories.when(
            loading: () => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
            error: (_, _) => Text(
              l10n.authSkillsLoadFailed,
              style: TextStyle(fontSize: 14, color: colors.error),
            ),
            data: (items) => Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final category in items.where(
                  (category) =>
                      category.availabilityStatus ==
                      ServiceAvailabilityStatus.active,
                ))
                  UstaadChoiceChip(
                    label: category.name,
                    selected: selected == category.id,
                    // Tapping the selected trade again clears it; tapping any
                    // other one replaces it. Never two at once.
                    onTap: () => onChanged(
                      selected == category.id ? null : category.id,
                    ),
                  ),
              ],
            ),
          ),
          if (hasError) UstaadFieldError(l10n.workerMainSkillRequired),
        ],
      ),
    );
  }
}

/// The home address. Verification data — the note says so, and the backend
/// keeps `residentialAddress` out of every Client-facing worker payload.
class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.areaCtrl,
    required this.streetCtrl,
    required this.houseCtrl,
    required this.landmarkCtrl,
    required this.areaError,
    required this.streetError,
    required this.houseError,
    required this.onChanged,
  });

  final TextEditingController areaCtrl;
  final TextEditingController streetCtrl;
  final TextEditingController houseCtrl;
  final TextEditingController landmarkCtrl;
  final bool areaError;
  final bool streetError;
  final bool houseError;

  /// Receives the field key that changed, so only that field's error clears.
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return UstaadSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UstaadSectionTitle(
            l10n.ustaadAddressTitle,
            subtitle: l10n.ustaadAddressSubtitle,
          ),
          const SizedBox(height: 16),
          // Area and Street share a row on anything wider than a very narrow
          // phone, and stack below that rather than squeezing.
          LayoutBuilder(
            builder: (context, constraints) {
              final area = _Field(
                label: l10n.ustaadAreaLabel,
                hint: l10n.ustaadAreaHint,
                controller: areaCtrl,
                hasError: areaError,
                errorText: l10n.workerDocumentRequired,
                onChanged: () => onChanged(_kFieldArea),
              );
              final street = _Field(
                label: l10n.ustaadStreetLabel,
                hint: kStreetHint,
                controller: streetCtrl,
                hasError: streetError,
                errorText: l10n.workerDocumentRequired,
                onChanged: () => onChanged(_kFieldStreet),
              );
              if (constraints.maxWidth < 300) {
                return Column(
                  children: [area, const SizedBox(height: 14), street],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: area),
                  const SizedBox(width: 12),
                  Expanded(child: street),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _Field(
            label: l10n.ustaadHouseLabel,
            hint: kHouseHint,
            controller: houseCtrl,
            hasError: houseError,
            errorText: l10n.workerDocumentRequired,
            onChanged: () => onChanged(_kFieldHouse),
          ),
          const SizedBox(height: 14),
          _Field(
            label: l10n.ustaadLandmarkLabel,
            hint: l10n.ustaadLandmarkHint,
            controller: landmarkCtrl,
            hasError: false,
            errorText: null,
            onChanged: () => onChanged(null),
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    required this.hasError,
    required this.errorText,
    required this.onChanged,
    this.textInputAction = TextInputAction.next,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool hasError;
  final String? errorText;
  final VoidCallback onChanged;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClientFieldLabel(label),
        ClientTextField(
          controller: controller,
          hint: hint,
          textInputAction: textInputAction,
          forceError: hasError,
          validator: errorText == null
              ? null
              : (v) => (v == null || v.trim().isEmpty) ? errorText : null,
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}
