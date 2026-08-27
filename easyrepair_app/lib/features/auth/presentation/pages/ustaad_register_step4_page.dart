import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/permissions/media_permission_helper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../worker/domain/entities/agreement_template_entity.dart';
import '../../../worker/presentation/pages/agreement_viewer_page.dart';
import '../../../worker/presentation/providers/worker_providers.dart';
import '../providers/ustaad_registration_draft.dart';
import '../widgets/client_auth_widgets.dart';
import '../widgets/ustaad_register_widgets.dart';

/// Ustaad registration, Step 4 of 4 — identity evidence and the agreements.
///
/// ONE scrolling page; the two reference screenshots are two scroll positions
/// of it.
///
/// ## Live selfie is not the profile photo
///
/// Step 3's photo is the customer-facing avatar: it goes to
/// `PATCH /workers/avatar` and sets `avatarUrl`. `submitProfileForReview`
/// requires `liveSelfieUrl`, which only
/// `POST /workers/profile-completion/selfie` writes — a camera-taken
/// verification image the customer never sees. The two were being conflated,
/// which is why every submission from this flow was rejected. They are now
/// separate captures with separate purposes, matching the legacy
/// profile-completion form (which also forces the camera for this one).
///
/// ## The legal model is untouched
///
/// This screen is a new layout over the SAME compliance machinery the
/// profile-completion form uses, not a replacement for it:
///
///  * the three documents come from `getAgreementTemplates` — General, the
///    trade-specific one and the Background Verification Consent, each with
///    its version, source hash, locale and applicable trade;
///  * "Parhein" opens [AgreementViewerPage], and only the [AgreementEvidence]
///    it returns unlocks a checkbox — a box cannot be ticked for a document
///    that was never rendered;
///  * evidence is invalidated the moment it stops describing the currently
///    loaded template, which is what forces a re-read when the trade changes;
///  * submission goes through `submitProfileForReview`, which seals the
///    acceptance records (acceptance id, timestamps, hashes, the filled PDF)
///    exactly as before. A single `submissionAttemptId` is generated per
///    attempt so a retry after a timeout returns the same sealed records
///    rather than creating a second set.
///
/// Nothing here reduces an agreement to a boolean.
class UstaadRegisterStep4Page extends ConsumerStatefulWidget {
  const UstaadRegisterStep4Page({super.key});

  /// Under `/worker`, not `/auth`: by the time this shows, Step 3 has created
  /// the account and the session is live, and every `/auth` location
  /// dispatches a logged-in user to their home. No redirect rule was changed
  /// to make this work — the route simply sits where an authenticated Ustaad
  /// is allowed to be.
  static const route = '/worker/register/verification';

  @override
  ConsumerState<UstaadRegisterStep4Page> createState() =>
      _UstaadRegisterStep4PageState();
}

class _UstaadRegisterStep4PageState
    extends ConsumerState<UstaadRegisterStep4Page> {
  final _picker = ImagePicker();

  bool _uploadingFront = false;
  bool _uploadingBack = false;
  bool _uploadingSelfie = false;
  bool _submitting = false;

  /// Per-document proof that THIS exact agreement was opened, plus whether the
  /// box was then ticked — the same structure the profile-completion form
  /// keeps, keyed by documentType.
  final Map<String, AgreementEvidence> _evidence = {};

  /// Generated once per submit attempt so a retry seals the same records.
  String? _submissionAttemptId;

  AgreementEvidence? _evidenceFor(AgreementTemplateEntity t) {
    final stored = _evidence[t.documentType];
    if (stored == null || !stored.matches(t)) return null;
    return stored;
  }

  bool _isAccepted(AgreementTemplateEntity t) =>
      _evidenceFor(t)?.checkboxAccepted ?? false;

  bool _isViewed(AgreementTemplateEntity t) => _evidenceFor(t) != null;

  Future<void> _openAgreement(AgreementTemplateEntity template) async {
    final result = await Navigator.of(context).push<AgreementEvidence>(
      MaterialPageRoute(
        builder: (_) => AgreementViewerPage(documentType: template.documentType),
      ),
    );
    if (!mounted || result == null) return;
    // Null means the viewer never rendered the document — that must not
    // unlock the checkbox.
    setState(() => _evidence[template.documentType] = result);
  }

  Future<void> _pickCnic({required bool front}) async {
    await _capture(
      setBusy: (v) => front ? _uploadingFront = v : _uploadingBack = v,
      upload: (notifier, file) => front
          // The existing document endpoints — same storage, same validation.
          ? notifier.uploadCnicFront(file)
          : notifier.uploadCnicBack(file),
    );
  }

  /// The verification selfie. Camera only, exactly as the legacy
  /// profile-completion form forces it — a gallery image would defeat the
  /// point of a *live* selfie.
  Future<void> _pickSelfie() async {
    await _capture(
      setBusy: (v) => _uploadingSelfie = v,
      upload: (notifier, file) => notifier.uploadLiveSelfie(file),
    );
  }

  /// Shared capture-and-upload. A failed upload surfaces through the
  /// `AsyncError` listener in [build] and leaves the tile "pending", so Submit
  /// stays blocked rather than the Ustaad reaching a submission the backend
  /// will refuse.
  Future<void> _capture({
    required void Function(bool) setBusy,
    required Future<String?> Function(
      ProfileCompletionNotifier notifier,
      File file,
    ) upload,
  }) async {
    final picked = await pickImageWithRecovery(
      context,
      picker: _picker,
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => setBusy(true));
    try {
      final notifier = ref.read(profileCompletionNotifierProvider.notifier);
      final url = await upload(notifier, File(picked.path));
      if (url == null && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(context.l10n.workerUploadFailed)),
          );
      }
    } finally {
      if (mounted) setState(() => setBusy(false));
    }
  }

  Future<void> _submit(List<AgreementTemplateEntity> templates) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      _submissionAttemptId ??=
          DateTime.now().microsecondsSinceEpoch.toString();

      final sealed = await ref
          .read(profileCompletionNotifierProvider.notifier)
          .submit(
            submissionAttemptId: _submissionAttemptId!,
            agreements: [
              for (final t in templates) _evidence[t.documentType]!,
            ],
          );
      if (!mounted || sealed == null) return;

      // The account exists, the session is live and the profile is now
      // SUBMITTED_FOR_REVIEW — pending admin approval, never auto-approved.
      // The draft (password, registration token) dies with the flow.
      ref.read(ustaadRegistrationDraftProvider.notifier).clear();
      context.go('/worker/home');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(profileCompletionNotifierProvider, (_, state) {
      if (state is AsyncError) _showError(state.error);
    });
    ref.watch(ustaadRegistrationDraftProvider);

    final l10n = context.l10n;
    final colors = context.semanticColors;
    final profile = ref.watch(workerProfileProvider).valueOrNull;
    final templatesAsync = ref.watch(agreementTemplatesProvider);
    final templates = templatesAsync.valueOrNull ?? const [];

    final hasFront = profile?.cnicFrontUrl != null;
    final hasBack = profile?.cnicBackUrl != null;
    // `submitProfileForReview` lists `liveSelfie` among its required fields;
    // the Step 3 avatar does not satisfy it.
    final hasSelfie = profile?.liveSelfieUrl != null;
    final allAccepted =
        templates.isNotEmpty && templates.every(_isAccepted);
    final canSubmit = hasFront && hasBack && hasSelfie && allAccepted;

    return UstaadStepScaffold(
      cta: ClientPrimaryButton(
        label: l10n.ustaadSubmitButton,
        isLoading: _submitting,
        onPressed: canSubmit ? () => _submit(templates) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UstaadStepHeader(title: l10n.ustaadVerificationHeader, step: 4),
          const SizedBox(height: 20),
          Text(
            l10n.ustaadStep4Heading,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.15,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.ustaadStep4Subtitle,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          _EvidenceCard(
            title: l10n.workerLiveSelfie,
            subtitle: l10n.ustaadLiveSelfieSubtitle,
            done: hasSelfie,
            busy: _uploadingSelfie,
            onTap: _pickSelfie,
          ),
          const SizedBox(height: 12),
          _EvidenceCard(
            title: l10n.ustaadCnicFrontTitle,
            subtitle: l10n.ustaadCnicFrontSubtitle,
            done: hasFront,
            busy: _uploadingFront,
            onTap: () => _pickCnic(front: true),
          ),
          const SizedBox(height: 12),
          _EvidenceCard(
            title: l10n.ustaadCnicBackTitle,
            subtitle: l10n.ustaadCnicBackSubtitle,
            done: hasBack,
            busy: _uploadingBack,
            onTap: () => _pickCnic(front: false),
          ),
          const SizedBox(height: 22),
          Text(
            l10n.ustaadAgreementsLabel,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          templatesAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
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
              l10n.agreementsLoadFailed,
              style: TextStyle(fontSize: 14, color: colors.error),
            ),
            data: (items) => Column(
              children: [
                for (final template in items) ...[
                  _AgreementCard(
                    template: template,
                    viewed: _isViewed(template),
                    accepted: _isAccepted(template),
                    onRead: () => _openAgreement(template),
                    onToggle: (value) {
                      final evidence = _evidenceFor(template);
                      // Only a document that was actually rendered can be
                      // accepted — there is no evidence to tick otherwise.
                      if (evidence == null) return;
                      setState(() {
                        _evidence[template.documentType] =
                            evidence.copyWith(checkboxAccepted: value);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
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

/// One capture tile: a thumbnail slot, a title/subtitle and a status
/// badge. Used for the live selfie and both CNIC sides.
class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({
    required this.title,
    required this.subtitle,
    required this.done,
    required this.busy,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool done;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.semanticColors;

    return UstaadSectionCard(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              width: 76,
              height: 60,
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: busy
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    )
                  : Text(
                      l10n.ustaadUploadAction,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colors.textSecondary,
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: UstaadSectionTitle(title, subtitle: subtitle),
            ),
            const SizedBox(width: 10),
            UstaadStatusBadge(
              label: done ? l10n.ustaadUploadedBadge : l10n.ustaadPendingBadge,
              done: done,
            ),
          ],
        ),
      ),
    );
  }
}

/// What each document covers, in one line.
///
/// Deliberately NOT part of the agreement text: the binding wording is the
/// backend-served [AgreementTemplateEntity.contentText], rendered verbatim by
/// the viewer. This is only a signpost telling the Ustaad which document they
/// are about to open, which is why it is app copy and translated.
String _summaryFor(AppLocalizations l10n, String documentType) =>
    switch (documentType) {
      kUstaadGeneralAgreement => l10n.ustaadAgreementGeneralSummary,
      kUstaadTradeAgreement => l10n.ustaadAgreementTradeSummary,
      _ => l10n.ustaadAgreementBackgroundSummary,
    };

class _AgreementCard extends StatelessWidget {
  const _AgreementCard({
    required this.template,
    required this.viewed,
    required this.accepted,
    required this.onRead,
    required this.onToggle,
  });

  final AgreementTemplateEntity template;
  final bool viewed;
  final bool accepted;
  final VoidCallback onRead;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.semanticColors;

    return UstaadSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                checked: accepted,
                enabled: viewed,
                child: Checkbox(
                  value: accepted,
                  // Disabled until the document has actually been rendered —
                  // this is the read-before-accept rule, not decoration.
                  onChanged: viewed ? (v) => onToggle(v ?? false) : null,
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
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    template.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 50),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _summaryFor(l10n, template.documentType),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Semantics(
                  button: true,
                  child: InkWell(
                    onTap: onRead,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: Text(
                        l10n.ustaadReadAction,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
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
