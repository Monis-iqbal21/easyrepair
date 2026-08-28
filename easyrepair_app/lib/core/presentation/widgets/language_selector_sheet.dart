import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_locale.dart';
import '../../l10n/l10n_extensions.dart';
import '../../l10n/locale_provider.dart';
import '../../theme/app_semantic_colors.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
//
// There isn't one. `_kOrange #DB6234` — EasyRepair's, on the selected label
// and the tick — is `c.primary`; #1A1A1A / #E2E8F0 / Colors.white are
// textPrimary / border / surface.
//
// SHARED: the same sheet opens from both the Client and the Ustaad profile.
// Presented identically to both. Selecting a language still applies it on the
// spot and persists it before the sheet closes — none of that was touched.

/// Opens the language picker used by both the Client and Ustaad profiles.
///
/// Selecting a language applies it on the spot — the whole app rebuilds from
/// [localeProvider] with no restart — and persists it before the sheet closes.
Future<void> showLanguageSelectorSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.semanticColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _LanguageSelectorSheet(),
  );
}

class _LanguageSelectorSheet extends ConsumerWidget {
  const _LanguageSelectorSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.semanticColors;
    final current = ref.watch(localeProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
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
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              context.l10n.languageSheetTitle,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final option in AppLocale.values)
            _LanguageOption(
              option: option,
              isSelected: option == current,
              onTap: () async {
                await ref.read(localeProvider.notifier).setLocale(option);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final AppLocale option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            // Selection reads as a surface, not just a coloured word — a
            // bigger, calmer target than a tinted label on bare white.
            //
            // A fill and nothing else, deliberately: an outline on the
            // selected row only would inset its label by the border width and
            // break the three options out of a single left edge, which
            // language_selector_test.dart asserts and a reader would see.
            color: isSelected ? c.softTeal : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                // Each language names itself and is shown in its own script, so
                // it is never translated — a user who cannot read the current
                // language can still find their own. It is not wrapped in an RTL
                // Directionality either: that would push اردو to the right edge
                // while the other two sat left, which is the mirroring HandyGo
                // does not do. Urdu glyphs shape correctly inside an LTR row
                // without it.
                child: Text(
                  option.displayLabel,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.3,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? c.primary : c.textPrimary,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_rounded, size: 20, color: c.primary),
            ],
          ),
        ),
      ),
    );
  }
}
