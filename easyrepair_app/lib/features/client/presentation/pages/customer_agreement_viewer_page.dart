import 'package:flutter/material.dart';

import '../../domain/entities/customer_agreement_entity.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';

/// The Customer Terms full-text reader, opened from the gate's
/// "View/Download PDF" action.
///
/// Shows the backend-approved legal body verbatim — the exact text that will
/// be sealed into the accepted PDF once the Client agrees. Freely dismissible
/// (system back / AppBar arrow): reading here is optional evidence-gathering
/// for the Client, never a requirement the gate enforces before the checkbox
/// can be ticked.
class CustomerAgreementViewerPage extends StatelessWidget {
  final CustomerAgreementEntity agreement;

  const CustomerAgreementViewerPage({super.key, required this.agreement});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.l10n.agreementViewerTitle,
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Backend-authored title — shown as-is, never translated.
            Text(
              agreement.title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: c.border),
              ),
              child: Text(
                context.l10n.workerAgreementVersion(agreement.version),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border),
              ),
              child: SelectableText(
                // The complete approved legal body, verbatim.
                agreement.contentText,
                style: TextStyle(
                  fontSize: 13,
                  color: c.textPrimary,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
