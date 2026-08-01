import 'package:flutter/material.dart';

import '../../l10n/l10n_extensions.dart';

/// Tells the reader, in their own language, that the legal document below is
/// approved in English only.
///
/// The Privacy Policy and Terms bodies are deliberately not machine-translated
/// — see `docs/legal_translation_exclusions.md`. This banner is app chrome, so
/// it *is* localized; the document under it is not.
class LegalEnglishOnlyNotice extends StatelessWidget {
  const LegalEnglishOnlyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E8E0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFFC2541D),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.legalEnglishOnlyNotice,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
