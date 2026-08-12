import 'package:flutter/material.dart';

import '../l10n/l10n_extensions.dart';

/// Small, non-blocking strip shown above cached content when a screen is
/// displaying its last-known-good data because the live fetch failed (see
/// `CachedResult.isStale`). Never covers the whole screen — that's reserved
/// for the "no cache + no internet" full error state, which pages render
/// separately.
class OfflineDataBanner extends StatelessWidget {
  const OfflineDataBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF4E5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 16, color: Color(0xFFB45309)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.offlineCachedDataBanner,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFB45309)),
            ),
          ),
        ],
      ),
    );
  }
}
