import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/presentation/pages/general_info_page.dart';
import '../../../../core/presentation/pages/privacy_policy_page.dart';
import '../../../../core/presentation/pages/terms_conditions_page.dart';
import '../pages/worker_reviews_page.dart';
import '../widgets/worker_bottom_nav_bar.dart';

// ── Local avatar provider for worker ─────────────────────────────────────────

final _workerLocalAvatarPathProvider =
    StateNotifierProvider<_WorkerAvatarNotifier, String?>(
  (ref) => _WorkerAvatarNotifier(),
);

class _WorkerAvatarNotifier extends StateNotifier<String?> {
  static const _key = 'worker_profile_avatar_path';

  _WorkerAvatarNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key);
  }

  Future<void> save(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, path);
    state = path;
  }

  Future<void> remove() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    state = null;
  }
}

// ── Worker Profile Page ───────────────────────────────────────────────────────

class WorkerProfilePage extends ConsumerStatefulWidget {
  const WorkerProfilePage({super.key});

  @override
  ConsumerState<WorkerProfilePage> createState() => _WorkerProfilePageState();
}

class _WorkerProfilePageState extends ConsumerState<WorkerProfilePage> {
  final _picker = ImagePicker();

  Future<void> _changeAvatar() async {
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
      await ref.read(_workerLocalAvatarPathProvider.notifier).remove();
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
    await ref.read(_workerLocalAvatarPathProvider.notifier).save(file.path);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final avatarPath = ref.watch(_workerLocalAvatarPathProvider);
    final firstName = user?.firstName ?? '';
    final lastName = user?.lastName ?? '';
    final fullName = '$firstName $lastName'.trim();
    final initials =
        firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

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
                        color: const Color(0xFF1D9E75),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF1D9E75).withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _buildAvatarContent(avatarPath, initials),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _changeAvatar,
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
                            color: Color(0xFF1D9E75),
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
                      'Worker',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D9E75),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

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
                          label: 'My Reviews',
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

  Widget _buildAvatarContent(String? avatarPath, String initials) {
    if (avatarPath != null) {
      final file = File(avatarPath);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover, width: 88, height: 88);
      }
    }
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
                onTap: () =>
                    Navigator.pop(context, _AvatarAction.gallery),
              ),
              _AvatarOption(
                icon: Icons.delete_outline_rounded,
                label: 'Remove',
                iconColor: const Color(0xFFEF4444),
                onTap: () =>
                    Navigator.pop(context, _AvatarAction.remove),
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
    final color = iconColor ?? const Color(0xFF1D9E75);
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
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0E8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon,
                      size: 18, color: const Color(0xFF1D9E75)),
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
