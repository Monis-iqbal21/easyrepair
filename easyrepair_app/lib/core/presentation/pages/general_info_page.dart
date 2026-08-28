import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../theme/app_semantic_colors.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
//
// There isn't one. Every colour comes from `context.semanticColors`, and
// anything `AppTheme` already decides (app bar, text fields, buttons) is not
// restated here.
//
// What was replaced: #F9FAFB -> background, Colors.white -> surface,
// #1A1A1A -> textPrimary, #6B7280 -> textSecondary, #E2E8F0 / #F1F5F9 ->
// border, #1D9E75 (a green that is not a HandyGo colour) and #FFB899 (an
// orange disabled fill) -> the themed ElevatedButton. The card shadow is gone.
//
// SHARED SCREEN: reached from BOTH the Client and the Ustaad profile. It is
// presented identically to both roles — there is no role-conditional UI here,
// and no functionality changed.

const double _rCard = 16;
const double _hRow = 56;

class GeneralInfoPage extends ConsumerWidget {
  const GeneralInfoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.semanticColors;
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.l10n.generalInfoTitle,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel(label: context.l10n.generalAccountSection),
              const SizedBox(height: 10),
              _Card(
                children: [
                  // Names and phone numbers are the user's own content —
                  // shown verbatim, never translated.
                  _InfoRow(
                    label: context.l10n.generalFirstName,
                    value: user?.firstName,
                  ),
                  const _RowDivider(),
                  _InfoRow(
                    label: context.l10n.generalLastName,
                    value: user?.lastName,
                  ),
                  const _RowDivider(),
                  _InfoRow(
                    label: context.l10n.generalPhoneNumber,
                    value: user?.phone,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                context.l10n.generalNamePhoneLocked,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              _SectionLabel(label: context.l10n.generalSecuritySection),
              const SizedBox(height: 10),
              _Card(
                children: [
                  _ActionRow(
                    icon: Icons.lock_outline_rounded,
                    label: context.l10n.generalChangePassword,
                    onTap: () => _showChangePasswordSheet(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePasswordSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.semanticColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ChangePasswordSheet(),
    );
  }
}

// ── Change Password Sheet ─────────────────────────────────────────────────────

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.generalChangePassword,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: c.textSecondary),
                    tooltip: context.l10n.commonCancel,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _PasswordField(
                controller: _currentCtrl,
                label: context.l10n.generalCurrentPassword,
                obscure: _obscureCurrent,
                onToggle: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              const SizedBox(height: 14),
              _PasswordField(
                controller: _newCtrl,
                label: context.l10n.generalNewPassword,
                obscure: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
              ),
              const SizedBox(height: 14),
              _PasswordField(
                controller: _confirmCtrl,
                label: context.l10n.generalConfirmNewPassword,
                obscure: _obscureConfirm,
                onToggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              const SizedBox(height: 10),
              Text(
                context.l10n.generalChangePasswordComingSoon,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                // Still disabled — there is no backend change-password
                // endpoint. Only the styling moved; the behaviour did not.
                onPressed: null,
                child: Text(
                  context.l10n.generalUpdatePassword,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    // Fill, borders, radius and label colour all come from
    // AppTheme.inputDecorationTheme — restating them here is what made this
    // field drift away from every other field in the app.
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(fontSize: 14, color: c.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
            color: c.textSecondary,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

// ── Shared UI components ──────────────────────────────────────────────────────

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

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_rCard),
        border: Border.all(color: c.border),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final shown = (value == null || value!.isEmpty) ? '—' : value!;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _hRow),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 14, color: c.textSecondary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                shown,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: c.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
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
                    height: 1.3,
                    color: c.textPrimary,
                  ),
                ),
              ),
              // Icons.chevron_right_rounded declares matchTextDirection.
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: c.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: context.semanticColors.border,
    );
  }
}
