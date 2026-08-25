import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/l10n/locale_provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/notifications/notification_permission_card.dart';
import '../../../../core/permissions/media_permission_helper.dart';
import '../../../../core/presentation/widgets/language_selector_sheet.dart';
import '../../../../core/presentation/pages/general_info_page.dart';
import '../../../../core/presentation/pages/privacy_policy_page.dart';
import '../../../../core/presentation/pages/terms_conditions_page.dart';
import '../../../../core/presentation/pages/about_page.dart';
import '../../../../core/utils/support_contact.dart';
import '../pages/worker_reviews_page.dart';
import '../pages/earning_history_page.dart';
import '../pages/worker_agreements_page.dart';
import '../pages/worker_profile_details_page.dart';
import '../providers/worker_providers.dart';
import '../providers/worker_review_providers.dart';
import '../widgets/worker_bottom_nav_bar.dart';
import '../../../../core/theme/app_semantic_colors.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
//
// There isn't one. Every colour comes from `context.semanticColors`.
//
// Two page-local constants used to live here, and both were misleading:
//
//   c.primary    #DB6234  EasyRepair's orange              -> c.primary
//   c.error #DB6234  named "DeleteRed", and the SAME orange. "Delete
//                        Account" has never actually been red -> c.error
//
// Loose literals went the same way: #1A1A1A -> textPrimary,
// #6B7280 -> textSecondary, #E2E8F0 / #F1F5F9 -> border, #F9FAFB -> background,
// #FFF0E8 -> softTeal, #EF4444 -> error, and the five approval-status pairs
// onto warning / error / success and their surfaces.
//
// Colour, type size and shape only. No provider, API call, navigation target
// or condition was touched.

const double _rCard = 16;   // prototype `.crd`
const double _rPill = 999;  // prototype `.tg`
const double _hButton = 52; // prototype `.btnp`

// ── Local avatar cache (user-specific key) ────────────────────────────────────

final _workerLocalAvatarPathProvider =
    StateNotifierProvider<_WorkerAvatarNotifier, String?>(
  (ref) => _WorkerAvatarNotifier(),
);

class _WorkerAvatarNotifier extends StateNotifier<String?> {
  static String _key(String userId) => 'worker_avatar_path_$userId';

  _WorkerAvatarNotifier() : super(null);

  Future<void> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key(userId));
  }

  Future<void> save(String userId, String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), path);
    state = path;
  }

  Future<void> remove(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
    state = null;
  }
}

// ── Cloud avatar URL provider ─────────────────────────────────────────────────

final _workerCloudAvatarUrlProvider = StateProvider<String?>((ref) => null);

// ── Worker Profile Page ───────────────────────────────────────────────────────

class WorkerProfilePage extends ConsumerStatefulWidget {
  const WorkerProfilePage({super.key});

  @override
  ConsumerState<WorkerProfilePage> createState() => _WorkerProfilePageState();
}

class _WorkerProfilePageState extends ConsumerState<WorkerProfilePage> {
  final _picker = ImagePicker();
  bool _uploading = false;
  bool _avatarInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAvatar());
  }

  Future<void> _initAvatar() async {
    if (_avatarInitialized) return;
    _avatarInitialized = true;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    // Load local cache first
    await ref.read(_workerLocalAvatarPathProvider.notifier).load(user.id);
    final localPath = ref.read(_workerLocalAvatarPathProvider);
    final localFile = localPath != null ? File(localPath) : null;

    if (localFile != null && localFile.existsSync()) return; // cache hit

    // No local cache — fetch cloud URL from backend
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get<Map<String, dynamic>>('/auth/avatar');
      final url = resp.data?['data']?['avatarUrl'] as String?;
      if (url != null && url.isNotEmpty && mounted) {
        ref.read(_workerCloudAvatarUrlProvider.notifier).state = url;
        _cacheRemoteImage(url, user.id);
      }
    } catch (_) {}
  }

  Future<void> _cacheRemoteImage(String url, String userId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ext = url.contains('.') ? '.${url.split('.').last.split('?').first}' : '.jpg';
      final path = '${dir.path}/avatar_worker_$userId$ext';
      final dio = Dio();
      await dio.download(url, path);
      if (mounted && File(path).existsSync()) {
        await ref.read(_workerLocalAvatarPathProvider.notifier).save(userId, path);
        ref.read(_workerCloudAvatarUrlProvider.notifier).state = null;
      }
    } catch (_) {}
  }

  Future<void> _changeAvatar() async {
    final c = context.semanticColors;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final choice = await showModalBottomSheet<_AvatarAction>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AvatarPickerSheet(),
    );
    if (choice == null || !mounted) return;

    if (choice == _AvatarAction.remove) {
      await ref.read(_workerLocalAvatarPathProvider.notifier).remove(user.id);
      ref.read(_workerCloudAvatarUrlProvider.notifier).state = null;
      return;
    }

    final source = choice == _AvatarAction.camera
        ? ImageSource.camera
        : ImageSource.gallery;

    final file = await pickImageWithRecovery(
      context,
      picker: _picker,
      source: source,
      imageQuality: 80,
      maxWidth: 600,
    );
    if (file == null || !mounted) return;

    // Save locally immediately for instant feedback
    await ref.read(_workerLocalAvatarPathProvider.notifier).save(user.id, file.path);
    ref.read(_workerCloudAvatarUrlProvider.notifier).state = null;

    // Upload to cloud in background
    setState(() => _uploading = true);
    try {
      final dio = ref.read(dioProvider);
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path,
            filename: 'avatar.jpg', contentType: DioMediaType('image', 'jpeg')),
      });
      await dio.patch<void>('/auth/avatar', data: formData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.clientProfileAvatarLocalOnly),
            backgroundColor: c.warning,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final user = ref.watch(authStateProvider).valueOrNull;
    final avatarPath = ref.watch(_workerLocalAvatarPathProvider);
    final cloudUrl = ref.watch(_workerCloudAvatarUrlProvider);
    final skills = ref.watch(workerProfileProvider).valueOrNull?.skills ?? const [];
    final mainSkillName = skills.isNotEmpty ? skills.first.categoryName : null;
    final firstName = user?.firstName ?? '';
    final lastName = user?.lastName ?? '';
    final fullName = '$firstName $lastName'.trim();
    final initials = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: c.background,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text(
                  context.l10n.clientProfileTitle,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Avatar ───────────────────────────────────────────────
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.softTeal,
                        border: Border.all(color: c.border),
                      ),
                      child: ClipOval(
                        child: _uploading
                            ? Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(c.onPrimary),
                                ),
                              )
                            : _buildAvatarContent(avatarPath, cloudUrl, initials),
                      ),
                    ),
                    PositionedDirectional(
                      bottom: 0,
                      end: 0,
                      child: GestureDetector(
                        onTap: _uploading ? null : _changeAvatar,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: c.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.border),
                          ),
                          child: Icon(
                            Icons.edit_rounded,
                            size: 14,
                            color: c.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              if (user != null) ...[
                Center(
                  child: Text(
                    fullName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    user.phone,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.softTeal,
                      borderRadius: BorderRadius.circular(_rPill),
                    ),
                    child: Text(
                      context.l10n.workerRoleBadge,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: c.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    mainSkillName != null
                        ? context.l10n.workerMainSkillWithName(mainSkillName)
                        : context.l10n.workerNoMainSkillYet,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: mainSkillName != null
                          ? c.textPrimary
                          : c.textSecondary,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── Profile completion / approval status ──────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ProfileApprovalCard(),
              ),

              const SizedBox(height: 24),

              // ── Reviews Summary Card ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ReviewsSummaryCard(),
              ),

              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const NotificationPermissionCard(),
                    _SectionLabel(label: context.l10n.settingsSectionAccount),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      items: [
                        _SettingsItem(
                          icon: Icons.person_outline_rounded,
                          label: context.l10n.generalInfoTitle,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const GeneralInfoPage(),
                            ),
                          ),
                        ),
                        _SettingsItem(
                          icon: Icons.star_outline_rounded,
                          label: context.l10n.reviewsMyReviews,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const WorkerReviewsPage(),
                            ),
                          ),
                        ),
                        _SettingsItem(
                          icon: Icons.savings_outlined,
                          label: context.l10n.earningHistoryTitle,
                          showDivider: false,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const EarningHistoryPage(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel(label: context.l10n.languageSectionTitle),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      items: [
                        _SettingsItem(
                          icon: Icons.language_rounded,
                          label: context.l10n.languageRowLabel,
                          trailingText: ref.watch(localeProvider).displayLabel,
                          showDivider: false,
                          onTap: () => showLanguageSelectorSheet(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel(label: context.l10n.settingsSectionLegal),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      items: [
                        // The Ustaad's own permanently accepted agreements —
                        // view and download, scoped to their account only.
                        _SettingsItem(
                          icon: Icons.gavel_rounded,
                          label: context.l10n.workerAcceptedAgreementsTitle,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const WorkerAgreementsPage(),
                            ),
                          ),
                        ),
                        _SettingsItem(
                          icon: Icons.shield_outlined,
                          label: context.l10n.settingsPrivacyPolicy,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyPage(),
                            ),
                          ),
                        ),
                        _SettingsItem(
                          icon: Icons.article_outlined,
                          label: context.l10n.settingsTermsConditions,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TermsConditionsPage(),
                            ),
                          ),
                        ),
                        _SettingsItem(
                          icon: Icons.support_agent_rounded,
                          label: context.l10n.settingsSupportTitle,
                          onTap: () => showSupportOptionsSheet(
                            context,
                            isWorker: true,
                          ),
                        ),
                        _SettingsItem(
                          icon: Icons.info_outline_rounded,
                          label: context.l10n.settingsAboutTitle,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AboutPage(),
                            ),
                          ),
                          showDivider: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _LogoutButton(ref: ref),
                    const SizedBox(height: 24),
                    _SectionLabel(label: context.l10n.settingsSectionDangerZone),
                    const SizedBox(height: 10),
                    _DeleteAccountSection(ref: ref),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const WorkerBottomNavBar(currentIndex: 4),
    );
  }

  Widget _buildAvatarContent(String? avatarPath, String? cloudUrl, String initials) {
    if (avatarPath != null) {
      final file = File(avatarPath);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover, width: 88, height: 88);
      }
    }
    if (cloudUrl != null && cloudUrl.isNotEmpty) {
      return Image.network(
        cloudUrl,
        fit: BoxFit.cover,
        width: 88,
        height: 88,
        errorBuilder: (ctx, err, st) => _InitialsWidget(initials: initials),
      );
    }
    return _InitialsWidget(initials: initials);
  }
}

// ── Profile completion / approval status card ─────────────────────────────────

class _ProfileApprovalCard extends ConsumerWidget {
  /// [onboardingStatus] is the raw backend token — only the badge wording is
  /// translated. Same mapping as the Profile Completion page's banner.
  (String, Color, Color, IconData) _visual(
    AppLocalizations l10n,
    AppSemanticColors c,
    String onboardingStatus,
  ) =>
      switch (onboardingStatus) {
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
            c.surfaceSubtle,
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
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.semanticColors;
    final profile = ref.watch(workerProfileProvider).valueOrNull;
    if (profile == null) return const SizedBox.shrink();

    final status = profile.onboardingStatus;
    final (label, fg, bg, icon) = _visual(context.l10n, c, status);
    final reason = status == 'CHANGES_REQUIRED'
        ? profile.changesRequiredReason
        : status == 'REJECTED'
            ? profile.rejectionReason
            : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_rCard),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.l10n.workerProfileApproval,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(_rPill)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 13, color: fg),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: fg),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              reason,
              style: TextStyle(fontSize: 12.5, color: c.textSecondary, height: 1.4),
            ),
          ],
          if (status == 'APPROVED') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WorkerProfileDetailsPage(),
                  ),
                ),
                icon: const Icon(Icons.badge_outlined, size: 18),
                label: Text(
                  context.l10n.workerViewSubmittedDetails,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.primary,
                  side: BorderSide(color: c.primary),
                  minimumSize: const Size.fromHeight(_hButton),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
          // Only while there is actually something to do. A profile sitting
          // in the review queue has nothing to complete, and the backend
          // refuses edits to it — see WorkerProfileEntity.needsProfileAction.
          if (status == 'DRAFT' ||
              status == 'CHANGES_REQUIRED' ||
              status == 'REJECTED') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/worker/profile-completion'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: c.onPrimary,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(_hButton),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                // Was an English label with a hard-coded Urdu line under it;
                // the app now speaks one language at a time.
                child: Text(
                  context.l10n.workerCompleteProfile,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Reviews Summary Card ──────────────────────────────────────────────────────

class _ReviewsSummaryCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.semanticColors;
    final summaryAsync = ref.watch(workerReviewSummaryProvider);
    final reviewsAsync = ref.watch(workerAllReviewsProvider);

    return summaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, st) => const SizedBox.shrink(),
      data: (summary) {
        if (summary.totalReviews == 0) return const SizedBox.shrink();

        // "Highest 5 · Lowest 5" said nothing — the same pair PR #6 took out
        // of My Reviews. How many gave five is what an Ustaad actually reads.
        final reviews = reviewsAsync.valueOrNull ?? [];
        final topCount = reviews.where((r) => r.rating == 5).length;

        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WorkerReviewsPage()),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(_rCard),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.softTeal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.star_rounded,
                      color: c.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.reviewsRatingSummary(
                          summary.averageRating.toStringAsFixed(1),
                          summary.totalReviews,
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.reviewsCount(topCount),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: c.textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Avatar picker sheet ───────────────────────────────────────────────────────

enum _AvatarAction { camera, gallery, remove }

class _AvatarPickerSheet extends StatelessWidget {
  const _AvatarPickerSheet();

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.profilePhotoTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AvatarOption(
                icon: Icons.camera_alt_outlined,
                label: context.l10n.postJobCamera,
                onTap: () => Navigator.pop(context, _AvatarAction.camera),
              ),
              _AvatarOption(
                icon: Icons.photo_library_outlined,
                label: context.l10n.commonGallery,
                onTap: () => Navigator.pop(context, _AvatarAction.gallery),
              ),
              _AvatarOption(
                icon: Icons.delete_outline_rounded,
                label: context.l10n.commonRemove,
                iconColor: c.error,
                onTap: () => Navigator.pop(context, _AvatarAction.remove),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvatarOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  const _AvatarOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final color = iconColor ?? c.primary;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.softTeal,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Initials widget ───────────────────────────────────────────────────────────

class _InitialsWidget extends StatelessWidget {
  final String initials;
  const _InitialsWidget({required this.initials});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 30,
          color: c.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Shared UI components ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: c.textSecondary,
        letterSpacing: 0.75,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<_SettingsItem> items;

  const _SettingsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_rCard),
        border: Border.all(color: c.border),
      ),
      child: Column(children: items),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showDivider;

  /// Optional value shown before the chevron — used by the language row to
  /// display the current language without opening the sheet.
  final String? trailingText;

  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showDivider = true,
    this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c.softTeal,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: c.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                if (trailingText != null) ...[
                  Text(
                    trailingText!,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                // Icons.chevron_right_rounded declares matchTextDirection, so
                // it points left on its own in Urdu.
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: c.textSecondary),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 66,
            endIndent: 16,
            color: c.border,
          ),
      ],
    );
  }
}

class _DeleteAccountSection extends StatelessWidget {
  final WidgetRef ref;
  const _DeleteAccountSection({required this.ref});

  Future<void> _confirmDelete(BuildContext context) async {
    final c = context.semanticColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.l10n.deleteAccountConfirmTitle,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          context.l10n.deleteAccountConfirmBody,
          style: TextStyle(fontSize: 14, color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.commonCancel,
                style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.commonDelete,
                style: TextStyle(
                    color: c.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final failedMessage = context.l10n.profileDeleteFailed;
    final success = await ref
        .read(deleteAccountNotifierProvider.notifier)
        .deleteAccount();

    if (!context.mounted) return;
    if (!success) {
      final state = ref.read(deleteAccountNotifierProvider);
      final msg = state is AsyncError
          ? (state.error as dynamic).message as String? ?? failedMessage
          : failedMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: c.error),
      );
    }
  }

  Future<void> _requestByEmail() async {
    final uri = Uri.parse(
      'mailto:support@handygo.ai?subject=Handygo%20Account%20Deletion%20Request',
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_rCard),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _confirmDelete(context),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.urgentSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.delete_forever_rounded,
                        size: 18, color: c.error),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      context.l10n.deleteAccountTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: c.error,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 20, color: c.textSecondary),
                ],
              ),
            ),
          ),
          Divider(height: 1, indent: 66, endIndent: 16, color: c.border),
          InkWell(
            onTap: _requestByEmail,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.surfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.mail_outline_rounded,
                        size: 18, color: c.textSecondary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      context.l10n.deleteAccountRequestByEmail,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: c.textSecondary,
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
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final WidgetRef ref;

  const _LogoutButton({required this.ref});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () =>
            ref.read(logoutNotifierProvider.notifier).logout(),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: Text(context.l10n.commonLogout),
        // Logout is not destructive; Delete Account is. The red outline sat
        // here while Delete wore the brand orange — exactly backwards.
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.border),
          minimumSize: const Size.fromHeight(_hButton),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
