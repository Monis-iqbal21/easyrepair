import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/customer_agreement_entity.dart';
import '../providers/customer_agreement_providers.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../l10n/app_localizations.dart';

// ── Palette (matches the rest of the client app) ────────────────────────────
const _kOrange = Color(0xFFDB6234);
const _kDark = Color(0xFF1A1A1A);
const _kGray = Color(0xFF6B7280);
const _kBorder = Color(0xFFE2E8F0);
const _kBg = Color(0xFFF9FAFB);
const _kRed = Color(0xFFDC2626);

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _kRed : _kDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _view(AcceptedCustomerAgreementEntity record) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
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
    final recordsAsync = ref.watch(customerAgreementHistoryProvider);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.l10n.customerAgreementHistoryTitle,
          style: const TextStyle(
            color: _kDark,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: recordsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _kOrange)),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  failureMessage(
                    context.l10n,
                    err,
                    fallback: context.l10n.agreementsLoadFailed,
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13.5, color: _kGray),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(customerAgreementHistoryProvider),
                  child: Text(context.l10n.commonRetry),
                ),
              ],
            ),
          ),
        ),
        data: (records) {
          if (records.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.l10n.workerAcceptedAgreementsEmpty,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13.5, color: _kGray),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: records.length,
            itemBuilder: (_, i) => _AcceptedAgreementCard(
              record: records[i],
              downloading: _downloading == records[i].downloadId,
              onView: () => _view(records[i]),
              onDownload: () => _download(records[i]),
            ),
          );
        },
      ),
    );
  }
}

class _AcceptedAgreementCard extends StatelessWidget {
  final AcceptedCustomerAgreementEntity record;
  final bool downloading;
  final VoidCallback onView;
  final VoidCallback onDownload;

  const _AcceptedAgreementCard({
    required this.record,
    required this.downloading,
    required this.onView,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Backend-authored title, frozen at acceptance time.
          Text(
            record.title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: _kDark,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.workerAgreementVersion(record.version),
            style: const TextStyle(fontSize: 11.5, color: _kGray),
          ),
          Text(
            l10n.agreementAcceptedOn(_formatAgreementDate(l10n, record.acceptedAt)),
            style: const TextStyle(fontSize: 11.5, color: _kGray),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Action(
                icon: Icons.visibility_outlined,
                label: l10n.workerViewAgreement,
                onTap: onView,
              ),
              const SizedBox(width: 18),
              if (downloading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _kOrange,
                  ),
                )
              else
                _Action(
                  icon: Icons.download_outlined,
                  label: l10n.agreementDownload,
                  onTap: onDownload,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _kOrange),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: _kOrange,
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only detail of one sealed acceptance. Shows what was accepted and
/// when — and offers the sealed PDF, which is the document itself.
class _AcceptedAgreementSheet extends StatelessWidget {
  final AcceptedCustomerAgreementEntity record;
  final VoidCallback onDownload;

  const _AcceptedAgreementSheet({
    required this.record,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              record.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kDark,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            _Row(label: l10n.workerAgreementVersion(record.version)),
            _Row(
              label: l10n.agreementAcceptedOn(
                _formatAgreementDate(l10n, record.acceptedAt),
              ),
            ),
            if (record.acceptanceId != null)
              _Row(label: l10n.agreementAcceptanceId(record.acceptanceId!)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onDownload,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(l10n.agreementDownload),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  const _Row({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12.5, color: _kGray, height: 1.45),
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
