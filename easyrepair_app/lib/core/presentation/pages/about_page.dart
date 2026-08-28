import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n_extensions.dart';
import '../../theme/app_semantic_colors.dart';
import '../../utils/app_version_info.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
//
// There isn't one. The four page-local constants that used to live here —
// _kOrange #DB6234 (EasyRepair's, on the website link), _kDark #1A1A1A,
// _kGray #6B7280 and _kBg #F9FAFB — are now primary / textPrimary /
// textSecondary / background.
//
// SHARED SCREEN: one About page for both Client and Ustaad (see
// settingsAboutTitle — never duplicated per role). Presented identically to
// both; no role-conditional UI, no functional change.

/// Simple, shared About HandyGo screen.
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  static const _websiteUrl = 'https://handygo.ai';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.semanticColors;
    final versionAsync = ref.watch(appVersionInfoProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.l10n.settingsAboutTitle,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Identity ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/logo-green.png',
                      width: 72,
                      height: 72,
                    ),
                    const SizedBox(height: 14),
                    // The product's own name — never translated.
                    Text(
                      'HandyGo',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.aboutAppDescription,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Facts ────────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  children: [
                    _AboutRow(
                      label: context.l10n.aboutWebsiteLabel,
                      value: _websiteUrl,
                      onTap: () => launchUrl(
                        Uri.parse(_websiteUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: c.border,
                    ),
                    _AboutRow(
                      label: context.l10n.settingsAppVersionTitle,
                      value: versionAsync.when(
                        data: (info) => context.l10n.aboutVersionValue(
                          info.version,
                          info.buildNumber,
                        ),
                        loading: () => '…',
                        error: (_, _) => '—',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _AboutRow({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: c.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    color: onTap != null ? c.primary : c.textPrimary,
                    fontWeight: FontWeight.w600,
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
