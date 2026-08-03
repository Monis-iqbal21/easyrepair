import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/agreement_template_entity.dart';
import '../providers/worker_providers.dart';
import '../utils/agreement_labels.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/l10n/l10n_extensions.dart';

// ── Palette (matches the rest of the worker app) ────────────────────────────
const _kOrange = Color(0xFFDB6234);
const _kDark = Color(0xFF1A1A1A);
const _kGray = Color(0xFF6B7280);
const _kBorder = Color(0xFFE2E8F0);
const _kBg = Color(0xFFF9FAFB);
const _kRed = Color(0xFFDC2626);

/// The one in-app reader for an approved HandyGo agreement.
///
/// Shows the FULL backend-approved legal body verbatim — never truncated,
/// never summarised, and never reconstructed from app localization. Only the
/// surrounding chrome (labels, notices, buttons) is translated.
///
/// Pops with an [AgreementEvidence] once the exact document has actually
/// rendered. A page that opened and failed to load pops with null, so a failed
/// open can never unlock the acceptance checkbox behind it.
class AgreementViewerPage extends ConsumerStatefulWidget {
  /// Which of the three documents to show. A value outside
  /// [kUstaadDocumentTypes] cannot reach here — the caller iterates that list.
  final String documentType;

  const AgreementViewerPage({super.key, required this.documentType});

  @override
  ConsumerState<AgreementViewerPage> createState() =>
      _AgreementViewerPageState();
}

class _AgreementViewerPageState extends ConsumerState<AgreementViewerPage> {
  /// Captured the moment the document renders, so the evidence timestamp is
  /// the real "opened and read" moment rather than the tap that started the
  /// (possibly slow, possibly failed) fetch.
  AgreementEvidence? _evidence;

  void _markViewed(AgreementTemplateEntity template) {
    if (_evidence != null) return;
    // Deferred: this runs during build, and the evidence is only a record
    // handed back on pop — it must not trigger a rebuild mid-frame.
    _evidence = template.evidenceViewedAt(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(agreementTemplatesProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // The single exit point: system back and the AppBar arrow both return
        // the evidence (or null when nothing rendered).
        Navigator.of(context).pop(_evidence);
      },
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: _kBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: _kDark),
            onPressed: () => Navigator.of(context).pop(_evidence),
          ),
          title: Text(
            context.l10n.agreementViewerTitle,
            style: const TextStyle(
              color: _kDark,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ),
        body: templatesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: _kOrange),
          ),
          error: (err, _) => _ErrorState(
            message: failureMessage(
              context.l10n,
              err,
              fallback: context.l10n.agreementLoadFailed,
            ),
            onRetry: () => ref.invalidate(agreementTemplatesProvider),
          ),
          data: (templates) {
            AgreementTemplateEntity? template;
            for (final t in templates) {
              if (t.documentType == widget.documentType) template = t;
            }
            if (template == null || template.contentText.trim().isEmpty) {
              // The document genuinely is not available (e.g. an unsupported
              // trade). Never fall back to another schedule, and never count
              // this as viewed.
              return _ErrorState(
                message: context.l10n.agreementUnavailableForTrade,
                onRetry: () => ref.invalidate(agreementTemplatesProvider),
              );
            }

            _markViewed(template);
            return _AgreementBody(template: template);
          },
        ),
      ),
    );
  }
}

class _AgreementBody extends StatelessWidget {
  final AgreementTemplateEntity template;
  const _AgreementBody({required this.template});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Backend-authored title — shown as-is, never translated.
          Text(
            template.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _kDark,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Chip(label: l10n.workerAgreementVersion(template.version)),
              _Chip(
                label: l10n.agreementLanguageChip(
                  agreementLocaleLabel(l10n, template.agreementLocale),
                ),
              ),
              if (template.applicableTrade != null)
                _Chip(
                  label: l10n.agreementTradeChip(
                    tradeLabel(l10n, template.applicableTrade!),
                  ),
                ),
            ],
          ),
          if (template.legalLanguageNoticeRequired) ...[
            const SizedBox(height: 12),
            const _LanguageNotice(),
          ],
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
            ),
            child: SelectableText(
              // The complete approved legal body, verbatim.
              template.contentText,
              style: const TextStyle(
                fontSize: 13,
                color: _kDark,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "This approved legal agreement is currently available in Roman Urdu."
///
/// Shown whenever the app language differs from the language of the approved
/// legal body. The body itself is never machine-translated.
class _LanguageNotice extends StatelessWidget {
  const _LanguageNotice();

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
          const Icon(Icons.info_outline_rounded, size: 18, color: _kOrange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.agreementLanguageNotice,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF7C3A16),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: _kGray,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 36, color: _kRed),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: _kGray, height: 1.5),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
