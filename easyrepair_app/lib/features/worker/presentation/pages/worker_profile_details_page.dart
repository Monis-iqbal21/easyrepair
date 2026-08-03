import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/worker_profile_entity.dart';
import '../providers/worker_providers.dart';
import '../pages/worker_agreements_page.dart';
import '../../../../core/l10n/l10n_extensions.dart';

// ── Palette (matches the rest of the worker app) ────────────────────────────
const _kOrange = Color(0xFFDB6234);
const _kDark = Color(0xFF1A1A1A);
const _kGray = Color(0xFF6B7280);
const _kBorder = Color(0xFFE2E8F0);
const _kBg = Color(0xFFF9FAFB);

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
    final l10n = context.l10n;
    final profileAsync = ref.watch(workerProfileProvider);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          l10n.workerSubmittedDetails,
          style: const TextStyle(
            color: _kDark,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: profileAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _kOrange)),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.workerProfileLoadFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _kGray),
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
                      const Icon(Icons.gavel_rounded, size: 18, color: _kOrange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.workerAcceptedAgreementsTitle,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: _kDark,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 20, color: _kGray),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E8E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kOrange.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 18, color: _kOrange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.workerDetailsReadOnlyNotice,
              style: const TextStyle(fontSize: 12.5, color: _kDark, height: 1.4),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: _kDark,
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
    final shown = (value == null || value!.trim().isEmpty) ? '—' : value!.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: _kGray),
          ),
          const SizedBox(height: 2),
          Text(
            shown,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: _kDark,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E8E0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _kOrange,
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
              color: Colors.white,
              border: Border.all(color: _kBorder, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: url == null
                ? const Icon(Icons.person_rounded, size: 44, color: _kGray)
                : Image.network(
                    url!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.person_rounded,
                      size: 44,
                      color: _kGray,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: _kGray),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, color: _kGray)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: url == null ? null : () => _openFullScreen(context, url!, label),
          child: Container(
            height: 96,
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: url == null
                ? const Center(
                    child: Icon(Icons.image_not_supported_outlined,
                        size: 22, color: _kGray),
                  )
                : Image.network(
                    url!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(Icons.broken_image_outlined,
                          size: 22, color: _kGray),
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
class _FullScreenImagePage extends StatelessWidget {
  final String url;
  final String label;
  const _FullScreenImagePage({required this.url, required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
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
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              size: 48,
              color: Colors.white54,
            ),
          ),
        ),
      ),
    );
  }
}
