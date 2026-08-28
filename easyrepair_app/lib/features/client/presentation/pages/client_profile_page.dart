import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/notifications/notification_permission_card.dart';
import '../../../../core/permissions/media_permission_helper.dart';
import '../../../../core/l10n/locale_provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/presentation/widgets/language_selector_sheet.dart';
import '../../../../core/presentation/pages/general_info_page.dart';
import '../../../../core/presentation/pages/privacy_policy_page.dart';
import '../../../../core/presentation/pages/terms_conditions_page.dart';
import '../../../../core/presentation/pages/about_page.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/utils/support_contact.dart';
import 'client_agreements_page.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
//
// There isn't one. Every colour comes from `context.semanticColors`.
//
// What used to sit at the top of this file:
//
//   _kOrange    #DB6234  EasyRepair's orange, on the avatar, every row icon,
//                        the sheet options and the language tick   -> c.primary
//   _kDeleteRed #DB6234  the SAME orange under a name claiming red -> c.error
//
// and, loose in the widgets: #F9FAFB -> background, #FFFFFF -> surface,
// #1A1A1A -> textPrimary, #6B7280 -> textSecondary, #E2E8F0 / #F1F5F9 ->
// border, #FFF0E8 -> softTeal, #EF4444 -> error, Colors.orange.shade700 ->
// warning. Every shadow is gone: a HandyGo card is surface + 16 + a hairline.
//
// Colour, type, shape and grouping only. No provider, API call, navigation
// target, logout semantic or condition was touched.

const double _rCard = 16; // prototype `.crd`
const double _rIcon = 10;
const double _hButton = 52; // prototype `.btnp`
const double _hRow = 56; // prototype tappable row
const double _avatar = 64;

// ── Local avatar cache (user-specific key) ────────────────────────────────────

final _localAvatarPathProvider =
    StateNotifierProvider<_LocalAvatarNotifier, String?>(
  (ref) => _LocalAvatarNotifier(),
);

class _LocalAvatarNotifier extends StateNotifier<String?> {
  static String _key(String userId) => 'client_avatar_path_$userId';

  _LocalAvatarNotifier() : super(null);

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

final _cloudAvatarUrlProvider = StateProvider<String?>((ref) => null);

// ── Profile Page ──────────────────────────────────────────────────────────────

class ClientProfilePage extends ConsumerStatefulWidget {
  const ClientProfilePage({super.key});

  @override
  ConsumerState<ClientProfilePage> createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends ConsumerState<ClientProfilePage> {
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
    await ref.read(_localAvatarPathProvider.notifier).load(user.id);
    final localPath = ref.read(_localAvatarPathProvider);
    final localFile = localPath != null ? File(localPath) : null;

    if (localFile != null && localFile.existsSync()) return; // cache hit

    // No local cache — fetch cloud URL from backend
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get<Map<String, dynamic>>('/auth/avatar');
      final url = resp.data?['data']?['avatarUrl'] as String?;
      if (url != null && url.isNotEmpty && mounted) {
        ref.read(_cloudAvatarUrlProvider.notifier).state = url;
        // Download and cache locally
        _cacheRemoteImage(url, user.id);
      }
    } catch (_) {}
  }

  Future<void> _cacheRemoteImage(String url, String userId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ext =
          url.contains('.') ? '.${url.split('.').last.split('?').first}' : '.jpg';
      final path = '${dir.path}/avatar_client_$userId$ext';
      final dio = Dio();
      await dio.download(url, path);
      if (mounted && File(path).existsSync()) {
        await ref.read(_localAvatarPathProvider.notifier).save(userId, path);
        ref.read(_cloudAvatarUrlProvider.notifier).state = null;
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
      await ref.read(_localAvatarPathProvider.notifier).remove(user.id);
      ref.read(_cloudAvatarUrlProvider.notifier).state = null;
      return;
    }

    final source =
        choice == _AvatarAction.camera ? ImageSource.camera : ImageSource.gallery;

    final file = await pickImageWithRecovery(
      context,
      picker: _picker,
      source: source,
      imageQuality: 80,
      maxWidth: 600,
    );
    if (file == null || !mounted) return;

    // Save locally immediately for instant feedback
    await ref.read(_localAvatarPathProvider.notifier).save(user.id, file.path);
    ref.read(_cloudAvatarUrlProvider.notifier).state = null;

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
    final avatarPath = ref.watch(_localAvatarPathProvider);
    final cloudUrl = ref.watch(_cloudAvatarUrlProvider);
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Page title ───────────────────────────────────────────
              Text(
                context.l10n.clientProfileTitle,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // ── Identity ─────────────────────────────────────────────
              _IdentityCard(
                fullName: fullName,
                // Names, phone numbers and addresses are user/backend content
                // and are never translated — only the chrome around them is.
                phone: user?.phone,
                initials: initials,
                uploading: _uploading,
                avatarPath: avatarPath,
                cloudUrl: cloudUrl,
                onEdit: _uploading ? null : _changeAvatar,
              ),

              const SizedBox(height: 24),

              const NotificationPermissionCard(),

              // ── Account ──────────────────────────────────────────────
              _SettingsSection(
                label: context.l10n.settingsSectionAccount,
                items: [
                  _SettingsItem(
                    icon: Icons.person_outline_rounded,
                    label: context.l10n.generalInfoTitle,
                    showDivider: false,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const GeneralInfoPage(),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Preferences ──────────────────────────────────────────
              _SettingsSection(
                label: context.l10n.languageSectionTitle,
                items: [
                  _SettingsItem(
                    icon: Icons.language_rounded,
                    label: context.l10n.languageRowLabel,
                    // Each language names itself, so this value is shown
                    // verbatim in its own script — never translated.
                    trailingText: ref.watch(localeProvider).displayLabel,
                    showDivider: false,
                    onTap: () => showLanguageSelectorSheet(context),
                  ),
                ],
              ),

              // ── Legal ────────────────────────────────────────────────
              _SettingsSection(
                label: context.l10n.settingsSectionLegal,
                items: [
                  _SettingsItem(
                    icon: Icons.shield_outlined,
                    label: context.l10n.settingsPrivacyPolicy,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PrivacyPolicyPage(),
                      ),
                    ),
                  ),
                  _SettingsItem(
                    icon: Icons.article_outlined,
                    label: context.l10n.settingsTermsConditions,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TermsConditionsPage(),
                      ),
                    ),
                  ),
                  _SettingsItem(
                    icon: Icons.gavel_rounded,
                    label: context.l10n.customerAgreementHistoryTitle,
                    showDivider: false,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ClientAgreementsPage(),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Support ──────────────────────────────────────────────
              //
              // Support and About used to sit at the bottom of the Legal
              // list, which is neither legal nor findable. They are their own
              // group now; the label reuses `settingsSupportTitle` rather than
              // adding a second key carrying the same English word, which the
              // translation set forbids (see arb_parity_test.dart).
              _SettingsSection(
                label: context.l10n.settingsSupportTitle,
                items: [
                  _SettingsItem(
                    icon: Icons.support_agent_rounded,
                    label: context.l10n.settingsSupportTitle,
                    onTap: () => showSupportOptionsSheet(
                      context,
                      isWorker: false,
                    ),
                  ),
                  _SettingsItem(
                    icon: Icons.info_outline_rounded,
                    label: context.l10n.settingsAboutTitle,
                    showDivider: false,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AboutPage(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              _LogoutButton(ref: ref),
              const SizedBox(height: 24),

              // ── Danger zone ──────────────────────────────────────────
              _SectionLabel(label: context.l10n.settingsSectionDangerZone),
              const SizedBox(height: 10),
              _DeleteAccountSection(ref: ref),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Identity ──────────────────────────────────────────────────────────────────

/// Avatar, name and phone in one horizontal lockup.
///
/// Horizontal rather than the old centred column: it survives large text
/// scales without pushing every setting below the fold, and it reads as the
/// header of the list under it instead of a hero image.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.fullName,
    required this.phone,
    required this.initials,
    required this.uploading,
    required this.avatarPath,
    required this.cloudUrl,
    required this.onEdit,
  });

  final String fullName;
  final String? phone;
  final String initials;
  final bool uploading;
  final String? avatarPath;
  final String? cloudUrl;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_rCard),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: _avatar,
                height: _avatar,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.softTeal,
                  border: Border.all(color: c.border),
                ),
                child: ClipOval(
                  child: uploading
                      ? Center(
                          child: SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(c.primary),
                            ),
                          ),
                        )
                      : _AvatarContent(
                          avatarPath: avatarPath,
                          cloudUrl: cloudUrl,
                          initials: initials,
                        ),
                ),
              ),
              PositionedDirectional(
                bottom: -2,
                end: -2,
                child: Semantics(
                  button: true,
                  label: context.l10n.profilePhotoTitle,
                  child: GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: c.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.border),
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        size: 13,
                        color: c.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (fullName.isNotEmpty)
                  Text(
                    fullName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: c.textPrimary,
                    ),
                  ),
                if (phone != null && phone!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    phone!,
                    style: TextStyle(
                      fontSize: 14,
                      color: c.textSecondary,
                    ),
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

class _AvatarContent extends StatelessWidget {
  const _AvatarContent({
    required this.avatarPath,
    required this.cloudUrl,
    required this.initials,
  });

  final String? avatarPath;
  final String? cloudUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    if (avatarPath != null) {
      final file = File(avatarPath!);
      if (file.existsSync()) {
        return Image.file(file,
            fit: BoxFit.cover, width: _avatar, height: _avatar);
      }
    }
    if (cloudUrl != null && cloudUrl!.isNotEmpty) {
      return Image.network(
        cloudUrl!,
        fit: BoxFit.cover,
        width: _avatar,
        height: _avatar,
        errorBuilder: (_, _, _) => _InitialsWidget(initials: initials),
      );
    }
    return _InitialsWidget(initials: initials);
  }
}

class _InitialsWidget extends StatelessWidget {
  const _InitialsWidget({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 24,
          color: c.primary,
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
    final c = context.semanticColors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _AvatarOption(
                    icon: Icons.camera_alt_outlined,
                    label: context.l10n.postJobCamera,
                    onTap: () => Navigator.pop(context, _AvatarAction.camera),
                  ),
                ),
                Expanded(
                  child: _AvatarOption(
                    icon: Icons.photo_library_outlined,
                    label: context.l10n.commonGallery,
                    onTap: () => Navigator.pop(context, _AvatarAction.gallery),
                  ),
                ),
                Expanded(
                  child: _AvatarOption(
                    icon: Icons.delete_outline_rounded,
                    label: context.l10n.commonRemove,
                    iconColor: c.error,
                    onTap: () => Navigator.pop(context, _AvatarAction.remove),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarOption extends StatelessWidget {
  const _AvatarOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final color = iconColor ?? c.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_rCard),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
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
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Settings UI components ────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    // Uppercase is an English-only device: Urdu has no letter case, and
    // Roman Urdu in caps reads as shouting.
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    return Text(
      isEnglish ? label.toUpperCase() : label,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: c.textSecondary,
        letterSpacing: isEnglish ? 0.75 : 0,
      ),
    );
  }
}

/// A labelled group: one section label over one bordered surface.
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.label, required this.items});

  final String label;
  final List<_SettingsItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: label),
          const SizedBox(height: 10),
          _SettingsCard(items: items),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.items});

  final List<Widget> items;

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
  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showDivider = true,
    this.trailingText,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showDivider;

  /// Optional value shown before the chevron — used by the language row to
  /// display the current language without opening the sheet.
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_rCard),
          child: ConstrainedBox(
            // A minimum, not a fixed height: the row grows with the text
            // rather than clipping it at large text scales.
            constraints: const BoxConstraints(minHeight: _hRow),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.softTeal,
                      borderRadius: BorderRadius.circular(_rIcon),
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
                        height: 1.3,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  if (trailingText != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        trailingText!,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 13,
                          color: c.textSecondary,
                        ),
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
        ),
        if (showDivider)
          Divider(height: 1, indent: 64, endIndent: 14, color: c.border),
      ],
    );
  }
}

// ── Danger zone ───────────────────────────────────────────────────────────────

class _DeleteAccountSection extends StatelessWidget {
  const _DeleteAccountSection({required this.ref});

  final WidgetRef ref;

  Future<void> _confirmDelete(BuildContext context) async {
    final c = context.semanticColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_rCard),
        ),
        title: Text(
          context.l10n.deleteAccountConfirmTitle,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          context.l10n.deleteAccountConfirmBody,
          style: TextStyle(fontSize: 14, height: 1.45, color: c.textSecondary),
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
                style: TextStyle(color: c.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final failedMessage = context.l10n.profileDeleteFailed;
    final success =
        await ref.read(deleteAccountNotifierProvider.notifier).deleteAccount();

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
    return _SettingsCard(
      items: [
        _DestructiveItem(
          icon: Icons.delete_forever_rounded,
          label: context.l10n.deleteAccountTitle,
          iconBackground: c.errorSoft,
          foreground: c.error,
          onTap: () => _confirmDelete(context),
        ),
        Divider(height: 1, indent: 64, endIndent: 14, color: c.border),
        _DestructiveItem(
          icon: Icons.mail_outline_rounded,
          label: context.l10n.deleteAccountRequestByEmail,
          iconBackground: c.surfaceSubtle,
          foreground: c.textSecondary,
          onTap: _requestByEmail,
        ),
      ],
    );
  }
}

class _DestructiveItem extends StatelessWidget {
  const _DestructiveItem({
    required this.icon,
    required this.label,
    required this.iconBackground,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconBackground;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_rCard),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _hRow),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(_rIcon),
                ),
                child: Icon(icon, size: 18, color: foreground),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                    color: foreground,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: c.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => ref.read(logoutNotifierProvider.notifier).logout(),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: Text(context.l10n.commonLogout),
        // Logout is not destructive; Delete Account is. The red outline sat
        // here while Delete wore the brand orange — exactly backwards. Same
        // correction the Ustaad profile already carries.
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
