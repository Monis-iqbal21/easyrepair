import 'package:flutter/material.dart';

import '../l10n/l10n_extensions.dart';
import '../theme/app_semantic_colors.dart';

/// Small, non-blocking strip shown above cached content when a screen is
/// displaying its last-known-good data because the live fetch failed (see
/// `CachedResult.isStale`). Never covers the whole screen — that's reserved
/// for the "no cache + no internet" full state, which [OfflineNoDataView]
/// renders.
///
/// Colours come from [AppSemanticColors] rather than literals, so the pending
/// palette decision and the future dark theme reach this banner without it
/// being edited.
class OfflineDataBanner extends StatelessWidget {
  const OfflineDataBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Container(
      width: double.infinity,
      color: colors.warningSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: colors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.offlineCachedDataBanner,
              style: TextStyle(fontSize: 12.5, color: colors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-state view for "the device is offline and this screen has nothing
/// cached to show" — the one case where there is genuinely no data.
///
/// Deliberately distinct from `ResourceUnavailableView` (a booking/job that is
/// *gone*, where retrying the same id can never help) — here retrying is
/// exactly the right thing once connectivity returns, so [onRetry] is
/// required.
///
/// [onRetry] must only refetch. It must never navigate, pop the current page,
/// or re-submit a write — Retry on a read screen is a read.
class OfflineNoDataView extends StatelessWidget {
  /// Overrides the default "no internet connection" copy — pass a
  /// screen-specific localized message when one reads better.
  final String? message;
  final VoidCallback onRetry;

  const OfflineNoDataView({super.key, required this.onRetry, this.message});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 30,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              message ?? context.l10n.errorOfflineActionBlocked,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, color: colors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                elevation: 0,
                minimumSize: const Size(0, 44),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
