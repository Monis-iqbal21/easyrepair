import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
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
class UstaadRegisterStep3Page extends ConsumerStatefulWidget {
  const UstaadRegisterStep3Page({super.key});

  static const route = '/auth/worker/register/profile';

  @override
  ConsumerState<UstaadRegisterStep3Page> createState() =>
      _UstaadRegisterStep3PageState();
}

class _UstaadRegisterStep3PageState
    extends ConsumerState<UstaadRegisterStep3Page> {
  final _picker = ImagePicker();
  final _areaCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _houseCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();

  File? _photo;
  List<String> _categoryIds = const [];
  int? _experienceYears;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final draft = ref.read(ustaadRegistrationDraftProvider);
      _areaCtrl.text = draft.area;
      _streetCtrl.text = draft.street;
      _houseCtrl.text = draft.house;
      _landmarkCtrl.text = draft.landmark;
      setState(() {
        _photo = draft.photo;
        _categoryIds = draft.categoryIds;
        _experienceYears = draft.experienceYears;
      });
    });
  }

  @override
  void dispose() {
    _areaCtrl.dispose();
    _streetCtrl.dispose();
    _houseCtrl.dispose();
    _landmarkCtrl.dispose();
    super.dispose();
  }

  /// The same required set the profile-completion form enforces, plus the
  /// trade the account itself cannot be created without. The backend remains
  /// the authority; this only keeps the CTA honest.
  bool get _canContinue =>
      _photo != null &&
      _categoryIds.isNotEmpty &&
      _experienceYears != null &&
      _areaCtrl.text.trim().isNotEmpty &&
      _streetCtrl.text.trim().isNotEmpty &&
      _houseCtrl.text.trim().isNotEmpty;

  void _saveToDraft() {
    ref.read(ustaadRegistrationDraftProvider.notifier).update(
          (d) => d.copyWith(
            photo: _photo,
            categoryIds: _categoryIds,
            experienceYears: _experienceYears,
            area: _areaCtrl.text.trim(),
            street: _streetCtrl.text.trim(),
            house: _houseCtrl.text.trim(),
            landmark: _landmarkCtrl.text.trim(),
          ),
        );
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      // The same bounds the profile-completion uploads use, so the backend
      // sees images of the size it already expects.
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _photo = File(picked.path));
    _saveToDraft();
  }

  Future<void> _continue() async {
    if (!_canContinue || _submitting) return;
    setState(() => _submitting = true);
    _saveToDraft();

    try {
      final draft = ref.read(ustaadRegistrationDraftProvider);

      if (!draft.accountCreated) {
        final token = draft.registrationToken;
        if (token == null) {
          // Step 2 was never completed — nothing to present, so send them back
          // rather than failing at the network.
          if (mounted) context.pop();
          return;
        }
        final created =
            await ref.read(workerOtpRegisterNotifierProvider.notifier).register(
                  fullName: draft.fullName,
                  phone: draft.phone,
                  password: draft.password,
                  categoryId: _categoryIds.first,
                  registrationToken: token,
                );
        if (!created) return;
        ref
            .read(ustaadRegistrationDraftProvider.notifier)
            .update((d) => d.copyWith(accountCreated: true));
      }

      // From here the Ustaad is authenticated, so these are the ordinary
      // worker endpoints the profile-completion form has always called.
      final profile = ref.read(profileCompletionNotifierProvider.notifier);

      if (_categoryIds.length > 1) {
        await ref.read(skillsNotifierProvider.notifier).saveSkills(_categoryIds);
      }
      if (_photo != null) {
        await profile.uploadAvatar(_photo!);
      }
      final saved = await profile.save(
        fullLegalName: draft.fullName,
        cnicNumber: draft.cnicNumber,
        residentialAddress: draft.residentialAddress,
        experienceYears: _experienceYears,
      );
      if (!mounted || !saved) return;

      context.push(UstaadRegisterStep4Page.route);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

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
    ref.watch(ustaadRegistrationDraftProvider);

    final l10n = context.l10n;
    final colors = context.semanticColors;

    return UstaadStepScaffold(
      cta: ClientPrimaryButton(
        label: l10n.postJobNext,
        isLoading: _submitting,
        onPressed: _canContinue ? _continue : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UstaadStepHeader(title: l10n.clientProfileTitle, step: 3),
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
          _PhotoCard(photo: _photo, onUpload: _pickPhoto),
          const SizedBox(height: 14),
          _SkillsCard(
            selected: _categoryIds,
            onChanged: (ids) {
              setState(() => _categoryIds = ids);
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
                          _saveToDraft();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _AddressCard(
            areaCtrl: _areaCtrl,
            streetCtrl: _streetCtrl,
            houseCtrl: _houseCtrl,
            landmarkCtrl: _landmarkCtrl,
            onChanged: () {
              setState(() {});
              _saveToDraft();
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _showError(Object? error) {
    if (!mounted) return;
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            failureMessage(l10n, error, fallback: l10n.authErrorGeneric),
          ),
        ),
      );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.photo, required this.onUpload});

  final File? photo;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.semanticColors;

    return UstaadSectionCard(
      child: Row(
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
    );
  }
}

/// The trades, straight from the live category list — never a hardcoded set,
/// so a category the admin adds (Appliances Repair, say) appears here without
/// a code change.
class _SkillsCard extends ConsumerWidget {
  const _SkillsCard({required this.selected, required this.onChanged});

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

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
                for (final category in items)
                  UstaadChoiceChip(
                    label: category.name,
                    selected: selected.contains(category.id),
                    onTap: () {
                      final next = [...selected];
                      // More than one trade is allowed — the first is the
                      // account's main category.
                      next.contains(category.id)
                          ? next.remove(category.id)
                          : next.add(category.id);
                      onChanged(next);
                    },
                  ),
              ],
            ),
          ),
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
    required this.onChanged,
  });

  final TextEditingController areaCtrl;
  final TextEditingController streetCtrl;
  final TextEditingController houseCtrl;
  final TextEditingController landmarkCtrl;
  final VoidCallback onChanged;

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
                onChanged: onChanged,
              );
              final street = _Field(
                label: l10n.ustaadStreetLabel,
                hint: kStreetHint,
                controller: streetCtrl,
                onChanged: onChanged,
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
            onChanged: onChanged,
          ),
          const SizedBox(height: 14),
          _Field(
            label: l10n.ustaadLandmarkLabel,
            hint: l10n.ustaadLandmarkHint,
            controller: landmarkCtrl,
            onChanged: onChanged,
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
    required this.onChanged,
    this.textInputAction = TextInputAction.next,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
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
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}
