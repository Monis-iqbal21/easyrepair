import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n_extensions.dart';
import '../../utils/app_version_info.dart';

const _kOrange = Color(0xFFDB6234);
const _kDark = Color(0xFF1A1A1A);
const _kGray = Color(0xFF6B7280);
const _kBg = Color(0xFFF9FAFB);

/// Simple, shared About HandyGo screen — one page for both Client and
/// Worker (see settingsAboutTitle doc comment: never duplicated per role).
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  static const _websiteUrl = 'https://handygo.ai';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(appVersionInfoProvider);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.l10n.settingsAboutTitle,
          style: const TextStyle(
            color: _kDark,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        iconTheme: const IconThemeData(color: _kDark),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Image.asset(
                  'assets/images/logo-green.png',
                  width: 72,
                  height: 72,
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'HandyGo',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _kDark,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.aboutAppDescription,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: _kGray,
                ),
              ),
              const SizedBox(height: 28),
              _AboutRow(
                label: context.l10n.aboutWebsiteLabel,
                value: _websiteUrl,
                onTap: () => launchUrl(
                  Uri.parse(_websiteUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const SizedBox(height: 12),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                color: _kGray,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                color: onTap != null ? _kOrange : _kDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
