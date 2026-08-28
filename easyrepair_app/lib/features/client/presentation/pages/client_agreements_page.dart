import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/customer_agreement_entity.dart';
import '../providers/customer_agreement_providers.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../l10n/app_localizations.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
//
// There isn't one. The six page-local constants that used to sit here —
// _kOrange #DB6234 (EasyRepair's, on every action and spinner), _kDark,
// _kGray, _kBorder, _kBg and _kRed — are primary / textPrimary /
// textSecondary / border / background / error.
//
// CLIENT-ONLY screen. Colour, type, spacing and the empty/error states moved;
// no provider, endpoint, download path or navigation target was touched.

const double _rCard = 16;

/// The Client's own legal history — read-only, under Client Profile ›
/// "Accepted Agreements". Mirrors WorkerAgreementsPage's download pattern.
///
/// These records are immutable: switching the app language changes the
/// labels around them, never the accepted version or date. A Client only
/// ever sees their own — the backend scopes the list to the authenticated
/// profile, and the download endpoint rejects another client's acceptance id.
class ClientAgreementsPage extends ConsumerStatefulWidget {
  const ClientAgreementsPage({super.key});

  @override
  ConsumerState<ClientAgreementsPage> createState() =>
      _ClientAgreementsPageState();
}

class _ClientAgreementsPageState extends ConsumerState<ClientAgreementsPage> {
  /// Acceptance id currently downloading, so only that row spins.
  String? _downloading;

  Future<void> _download(AcceptedCustomerAgreementEntity record) async {
    if (_downloading != null) return;
    setState(() => _downloading = record.downloadId);

    final bytes = await ref
        .read(downloadCustomerAgreementProvider.notifier)
        .download(record.downloadId);
    if (!mounted) return;

    if (bytes == null || bytes.isEmpty) {
      setState(() => _downloading = null);
      final err = ref.read(downloadCustomerAgreementProvider).error;
      _snack(
        failureMessage(
          context.l10n,
          err,
          fallback: context.l10n.agreementDownloadFailed,
        ),
        isError: true,
      );
      return;
    }

    String? savedPath;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/agreements');
      if (!folder.existsSync()) folder.createSync(recursive: true);
      // The public acceptance id only — never the phone number or the
      // Client's name.
      final file = File('${folder.path}/handygo-agreement-'
          '${record.downloadId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-')}.pdf');
      file.writeAsBytesSync(bytes);
      savedPath = file.path;
    } catch (_) {
      savedPath = null;
    }

    if (!mounted) return;
    setState(() => _downloading = null);

    if (savedPath == null) {
      _snack(context.l10n.agreementDownloadFailed, isError: true);
      return;
    }

    // Best effort: hand the saved file to whatever can open a PDF. If nothing
    // can, the Client is still told exactly where it was saved.
    try {
      await launchUrl(Uri.file(savedPath));
    } catch (_) {
      // Intentionally ignored — the snackbar below is the fallback.
    }
    if (!mounted) return;
    _snack(context.l10n.agreementDownloadSaved(savedPath));
  }

  void _snack(String message, {bool isError = false}) {
    final c = context.semanticColors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        // Anything but an error keeps the themed SnackBar background.
        backgroundColor: isError ? c.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _view(AcceptedCustomerAgreementEntity record) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.semanticColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AcceptedAgreementSheet(
        record: record,
        onDownload: () {
          Navigator.pop(ctx);
          _download(record);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final recordsAsync = ref.watch(customerAgreementHistoryProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.l10n.customerAgreementHistoryTitle,
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: recordsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => _StateView(
            icon: Icons.error_outline_rounded,
            message: failureMessage(
              context.l10n,
              err,
              fallback: context.l10n.agreementsLoadFailed,
            ),
            action: OutlinedButton(
              onPressed: () =>
                  ref.invalidate(customerAgreementHistoryProvider),
              child: Text(context.l10n.commonRetry),
            ),
          ),
          data: (records) {
            if (records.isEmpty) {
              return _StateView(
                icon: Icons.gavel_rounded,
                message: context.l10n.workerAcceptedAgreementsEmpty,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: records.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _AcceptedAgreementCard(
                record: records[i],
                downloading: _downloading == records[i].downloadId,
                onView: () => _view(records[i]),
                onDownload: () => _download(records[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One shape for "nothing here" and "that failed" — same icon-over-text
/// rhythm, so the page never changes layout language between its states.
class _StateView extends StatelessWidget {
  const _StateView({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
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
              child: Icon(icon, size: 26, color: c.primary),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: c.textSecondary,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _AcceptedAgreementCard extends StatelessWidget {
  const _AcceptedAgreementCard({
    required this.record,
    required this.downloading,
    required this.onView,
    required this.onDownload,
  });

  final AcceptedCustomerAgreementEntity record;
  final bool downloading;
  final VoidCallback onView;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_rCard),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Backend-authored title, frozen at acceptance time — shown
          // verbatim, never translated.
          Text(
            record.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.workerAgreementVersion(record.version),
            style: TextStyle(fontSize: 12.5, height: 1.45, color: c.textSecondary),
          ),
          Text(
            l10n.agreementAcceptedOn(
              _formatAgreementDate(l10n, record.acceptedAt),
            ),
            style: TextStyle(fontSize: 12.5, height: 1.45, color: c.textSecondary),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: c.border),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _Action(
                  icon: Icons.visibility_outlined,
                  label: l10n.workerViewAgreement,
                  onTap: onView,
                ),
              ),
              Expanded(
                child: downloading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : _Action(
                        icon: Icons.download_outlined,
                        label: l10n.agreementDownload,
                        onTap: onDownload,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
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
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: c.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-only detail of one sealed acceptance. Shows what was accepted and
/// when — and offers the sealed PDF, which is the document itself.
class _AcceptedAgreementSheet extends StatelessWidget {
  const _AcceptedAgreementSheet({
    required this.record,
    required this.onDownload,
  });

  final AcceptedCustomerAgreementEntity record;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
              Text(
                record.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              _MetaRow(label: l10n.workerAgreementVersion(record.version)),
              _MetaRow(
                label: l10n.agreementAcceptedOn(
                  _formatAgreementDate(l10n, record.acceptedAt),
                ),
              ),
              if (record.acceptanceId != null)
                _MetaRow(label: l10n.agreementAcceptanceId(record.acceptanceId!)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onDownload,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(l10n.agreementDownload),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          color: context.semanticColors.textSecondary,
          height: 1.45,
        ),
      ),
    );
  }
}

/// "12 Aug 2026" in the app's language, using the same month names the rest
/// of the app already ships. Mirrors worker_agreements_page.dart's
/// formatAgreementDate — kept local rather than imported across features.
String _formatAgreementDate(AppLocalizations l10n, DateTime date) {
  final months = [
    l10n.monthJan, l10n.monthFeb, l10n.monthMar, l10n.monthApr,
    l10n.monthMay, l10n.monthJun, l10n.monthJul, l10n.monthAug,
    l10n.monthSep, l10n.monthOct, l10n.monthNov, l10n.monthDec,
  ];
  final local = date.toLocal();
  return l10n.dateDayMonthYear(local.day, months[local.month - 1], local.year);
}
