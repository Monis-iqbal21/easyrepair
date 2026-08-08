import 'package:flutter/material.dart';

import '../../domain/entities/customer_agreement_entity.dart';
import '../../../../core/l10n/l10n_extensions.dart';

const _kDark = Color(0xFF1A1A1A);
const _kGray = Color(0xFF6B7280);
const _kBorder = Color(0xFFE2E8F0);
const _kBg = Color(0xFFF9FAFB);

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
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kDark),
          onPressed: () => Navigator.of(context).pop(),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Backend-authored title — shown as-is, never translated.
            Text(
              agreement.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _kDark,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _kBorder),
              ),
              child: Text(
                context.l10n.workerAgreementVersion(agreement.version),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _kGray,
                ),
              ),
            ),
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
                agreement.contentText,
                style: const TextStyle(
                  fontSize: 13,
                  color: _kDark,
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
