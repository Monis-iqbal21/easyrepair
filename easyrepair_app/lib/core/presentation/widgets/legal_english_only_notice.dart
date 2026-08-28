import 'package:flutter/material.dart';

import '../../l10n/l10n_extensions.dart';
import '../../theme/app_semantic_colors.dart';

/// Tells the reader, in their own language, that the legal document below is
/// approved in English only.
///
/// The Privacy Policy and Terms bodies are deliberately not machine-translated
/// — see `docs/legal_translation_exclusions.md`. This banner is app chrome, so
/// it *is* localized; the document under it is not.
///
/// SHARED: sits on the Privacy Policy and Terms pages, which both the Client
/// and the Ustaad reach. Colour only — the wording and behaviour are unchanged.
///
/// The surface was #F5E8E0 with a #C2541D icon — EasyRepair's orange notice.
/// This is informational chrome, not a failure and not urgent, so it now
/// reads in the brand's own quiet tint.
class LegalEnglishOnlyNotice extends StatelessWidget {
  const LegalEnglishOnlyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.softTeal,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: c.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.legalEnglishOnlyNotice,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: c.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
