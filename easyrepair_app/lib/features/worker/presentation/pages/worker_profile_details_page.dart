import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/worker_profile_entity.dart';
import '../providers/worker_providers.dart';
import '../pages/worker_agreements_page.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';

/// Everything the Ustaad submitted during onboarding, as a sealed record.
///
/// Read-only by construction: this page has no controllers, no form fields and
/// no save path. Once a profile is APPROVED its identity data is what the
/// admin reviewed and what the agreement PDFs were generated against, so it
/// must not be quietly editable afterwards — a changed CNIC or legal name
/// would silently invalidate documents that are already signed.
class WorkerProfileDetailsPage extends ConsumerWidget {
  const WorkerProfileDetailsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.semanticColors;
    final l10n = context.l10n;
    final profileAsync = ref.watch(workerProfileProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          l10n.workerSubmittedDetails,
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: profileAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: c.primary)),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.workerProfileLoadFailed,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: c.textSecondary),
            ),
          ),
        ),
        data: (profile) => _Details(profile: profile),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  final WorkerProfileEntity profile;
  const _Details({required this.profile});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final l10n = context.l10n;
    final skills = profile.skills;
    final mainTrade = skills.isNotEmpty ? skills.first.categoryName : null;
    final experience =
        skills.isNotEmpty ? skills.first.yearsExperience : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The profile photo doubles as the verification image — one capture,
          // shown here as the avatar it now also is.
          Center(
            child: _PhotoAvatar(
              url: profile.liveSelfieUrl ?? profile.avatarUrl,
              label: l10n.profilePhotoTitle,
            ),
          ),
          const SizedBox(height: 16),
          const _ReadOnlyNotice(),
          const SizedBox(height: 16),

          _Card(
            title: l10n.workerSubmittedDetails,
            children: [
              _Field(label: l10n.workerFullLegalName, value: profile.fullLegalName),
              _Field(label: l10n.workerFatherName, value: profile.fatherName),
              _Field(label: l10n.workerDateOfBirth, value: profile.dateOfBirth),
              _Field(label: l10n.workerCnicNumber, value: profile.cnicNumber),
              _Field(
                label: l10n.workerResidentialAddress,
                value: profile.residentialAddress,
              ),
              _Field(
                label: l10n.workerEmergencyContact,
                value: profile.emergencyContact,
              ),
              _Field(label: l10n.workerMainTrade, value: mainTrade),
              _Field(
                label: l10n.workerExperienceYears,
                value: experience == null ? null : '$experience',
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (skills.isNotEmpty) ...[
            _Card(
              title: l10n.chooseSkills,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in skills) _SkillChip(label: s.categoryName),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          _Card(
            title: l10n.workerProfileApproval,
            children: [
              _Field(
                label: l10n.workerVerificationStatus,
                value: profile.verificationStatus,
              ),
              _Field(
                label: l10n.workerProfileApproval,
                value: profile.onboardingStatus,
              ),
            ],
          ),
          const SizedBox(height: 12),

          _Card(
            title: l10n.workerIdentityDocuments,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _DocumentThumb(
                      label: l10n.workerCnicFront,
                      url: profile.cnicFrontUrl,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DocumentThumb(
                      label: l10n.workerCnicBack,
                      url: profile.cnicBackUrl,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // The accepted-agreement list and its authenticated downloads are
          // unchanged — this only links to the page that already owns them.
          _Card(
            title: l10n.workerAgreements,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WorkerAgreementsPage(),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.gavel_rounded, size: 18, color: c.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.workerAcceptedAgreementsTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 20, color: c.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice();

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.softTeal,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, size: 18, color: c.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.workerDetailsReadOnlyNotice,
              style: TextStyle(fontSize: 12.5, color: c.textPrimary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Card({required this.title, required this.children});

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

/// A submitted value. Absent values are shown as an em dash rather than hidden,
/// so the Ustaad can see exactly what HandyGo holds on them.
class _Field extends StatelessWidget {
  final String label;
  final String? value;
  const _Field({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final shown = (value == null || value!.trim().isEmpty) ? '—' : value!.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12.5, color: c.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            shown,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String label;
  const _SkillChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.softTeal,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: c.primary,
        ),
      ),
    );
  }
}

class _PhotoAvatar extends StatelessWidget {
  final String? url;
  final String label;
  const _PhotoAvatar({required this.url, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Column(
      children: [
        GestureDetector(
          onTap: url == null
              ? null
              : () => _openFullScreen(context, url!, label),
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.surface,
              border: Border.all(color: c.border, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: url == null
                ? Icon(Icons.person_rounded, size: 44, color: c.textSecondary)
                : Image.network(
                    url!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.person_rounded,
                      size: 44,
                      color: c.textSecondary,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12.5, color: c.textSecondary),
        ),
      ],
    );
  }
}

class _DocumentThumb extends StatelessWidget {
  final String label;
  final String? url;
  const _DocumentThumb({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: url == null ? null : () => _openFullScreen(context, url!, label),
          child: Container(
            height: 96,
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: url == null
                ? Center(
                    child: Icon(Icons.image_not_supported_outlined,
                        size: 22, color: c.textSecondary),
                  )
                : Image.network(
                    url!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, _, _) => Center(
                      child: Icon(Icons.broken_image_outlined,
                          size: 22, color: c.textSecondary),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

void _openFullScreen(BuildContext context, String url, String label) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _FullScreenImagePage(url: url, label: label),
    ),
  );
}

/// A submitted image at full size, pinchable and pannable.
///
/// The lightbox stays visually dark in both app themes through the centralized
/// [AppSemanticColors.scrim] and [AppSemanticColors.onScrim] tokens.
class _FullScreenImagePage extends StatelessWidget {
  final String url;
  final String label;
  const _FullScreenImagePage({required this.url, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Scaffold(
      backgroundColor: c.scrim,
      appBar: AppBar(
        backgroundColor: c.scrim,
        elevation: 0,
        iconTheme: IconThemeData(color: c.onScrim),
        title: Text(
          label,
          style: TextStyle(
            color: c.onScrim,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Icon(
              Icons.broken_image_outlined,
              size: 48,
              color: c.onScrim.withValues(alpha: 0.54),
            ),
          ),
        ),
      ),
    );
  }
}
