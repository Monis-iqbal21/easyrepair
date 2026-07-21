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
import '../../../../core/network/api_client.dart';
import '../../../../core/presentation/pages/general_info_page.dart';
import '../../../../core/presentation/pages/privacy_policy_page.dart';
import '../../../../core/presentation/pages/terms_conditions_page.dart';
import '../pages/worker_reviews_page.dart';
import '../providers/worker_providers.dart';
import '../providers/worker_review_providers.dart';
import '../widgets/worker_bottom_nav_bar.dart';

const _kOrange = Color(0xFFDB6234);

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
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final choice = await showModalBottomSheet<_AvatarAction>(
      context: context,
      backgroundColor: Colors.white,
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

    final file = await _picker.pickImage(
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
            content: const Text(
              'Profile image saved on this device. Cloud sync is not available yet.',
            ),
            backgroundColor: Colors.orange.shade700,
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
      backgroundColor: const Color(0xFFF9FAFB),
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar ─────────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
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
                        color: _kOrange,
                        boxShadow: [
                          BoxShadow(
                            color: _kOrange.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _uploading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : _buildAvatarContent(avatarPath, cloudUrl, initials),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _uploading ? null : _changeAvatar,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFF9FAFB),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            size: 14,
                            color: _kOrange,
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    user.phone,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0E8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Ustaad',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kOrange,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    mainSkillName != null
                        ? 'Main Skill: $mainSkillName'
                        : 'No main skill selected yet',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: mainSkillName != null
                          ? const Color(0xFF1A1A1A)
                          : const Color(0xFF6B7280),
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
                    _SectionLabel(label: 'Account'),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      items: [
                        _SettingsItem(
                          icon: Icons.person_outline_rounded,
                          label: 'General',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const GeneralInfoPage(),
                            ),
                          ),
                        ),
                        _SettingsItem(
                          icon: Icons.star_outline_rounded,
                          label: 'Mere Reviews',
                          showDivider: false,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const WorkerReviewsPage(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel(label: 'Legal'),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      items: [
                        _SettingsItem(
                          icon: Icons.shield_outlined,
                          label: 'Privacy Policy',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyPage(),
                            ),
                          ),
                        ),
                        _SettingsItem(
                          icon: Icons.article_outlined,
                          label: 'Terms & Conditions',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TermsConditionsPage(),
                            ),
                          ),
                          showDivider: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _LogoutButton(ref: ref),
                    const SizedBox(height: 24),
                    _SectionLabel(label: 'Danger Zone'),
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
  (String, Color, Color, IconData) _visual(String onboardingStatus) => switch (onboardingStatus) {
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
            const Color(0xFFDC2626),
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
            const Color(0xFF6B7280),
            const Color(0xFFF1F5F9),
            Icons.description_outlined,
          ),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(workerProfileProvider).valueOrNull;
    if (profile == null) return const SizedBox.shrink();

    final status = profile.onboardingStatus;
    final (label, fg, bg, icon) = _visual(status);
    final reason = status == 'CHANGES_REQUIRED'
        ? profile.changesRequiredReason
        : status == 'REJECTED'
            ? profile.rejectionReason
            : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Profile Approval',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 13, color: fg),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg),
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
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280), height: 1.4),
            ),
          ],
          if (status != 'APPROVED') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/worker/profile-completion'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Complete Profile', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    SizedBox(height: 1),
                    Text(
                      'پروفائل مکمل کریں',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ],
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
    final summaryAsync = ref.watch(workerReviewSummaryProvider);
    final reviewsAsync = ref.watch(workerAllReviewsProvider);

    return summaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, st) => const SizedBox.shrink(),
      data: (summary) {
        if (summary.totalReviews == 0) return const SizedBox.shrink();

        final reviews = reviewsAsync.valueOrNull ?? [];
        final maxRating = reviews.isNotEmpty
            ? reviews.map((r) => r.rating).reduce((a, b) => a > b ? a : b)
            : 0;
        final minRating = reviews.isNotEmpty
            ? reviews.map((r) => r.rating).reduce((a, b) => a < b ? a : b)
            : 0;

        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WorkerReviewsPage()),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _kOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.star_rounded,
                      color: _kOrange, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${summary.averageRating.toStringAsFixed(1)} · ${summary.totalReviews} ${summary.totalReviews == 1 ? 'review' : 'reviews'}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Highest: $maxRating ★  ·  Lowest: $minRating ★',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: Color(0xFF6B7280)),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Profile Photo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AvatarOption(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                onTap: () => Navigator.pop(context, _AvatarAction.camera),
              ),
              _AvatarOption(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: () => Navigator.pop(context, _AvatarAction.gallery),
              ),
              _AvatarOption(
                icon: Icons.delete_outline_rounded,
                label: 'Remove',
                iconColor: const Color(0xFFEF4444),
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
    final color = iconColor ?? _kOrange;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
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
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 30,
          color: Colors.white,
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
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF6B7280),
        letterSpacing: 0.8,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<_SettingsItem> items;

  const _SettingsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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

  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
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
                    color: const Color(0xFFFFF0E8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: _kOrange),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: Color(0xFF6B7280)),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            indent: 66,
            endIndent: 16,
            color: Color(0xFFF1F5F9),
          ),
      ],
    );
  }
}

const _kDeleteRed = Color(0xFFDB6234);

class _DeleteAccountSection extends StatelessWidget {
  final WidgetRef ref;
  const _DeleteAccountSection({required this.ref});

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete account?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: const Text(
          'This will delete your Handygo account and sign you out. This action may not be reversible.',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: _kDeleteRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final success = await ref
        .read(deleteAccountNotifierProvider.notifier)
        .deleteAccount();

    if (!context.mounted) return;
    if (!success) {
      final state = ref.read(deleteAccountNotifierProvider);
      final msg = state is AsyncError
          ? (state.error as dynamic).message as String? ?? 'Failed to delete account.'
          : 'Failed to delete account.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                      color: _kDeleteRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_forever_rounded,
                        size: 18, color: _kDeleteRed),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Account Delete karein',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _kDeleteRed,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 20, color: Color(0xFF6B7280)),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 66, endIndent: 16, color: Color(0xFFF1F5F9)),
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
                      color: const Color(0xFF6B7280).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.mail_outline_rounded,
                        size: 18, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Email se delete karwayen',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 20, color: Color(0xFF6B7280)),
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
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () =>
            ref.read(logoutNotifierProvider.notifier).logout(),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text('Logout'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFEF4444),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
          padding: const EdgeInsets.symmetric(vertical: 14),
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
