import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_locale.dart';
import '../../l10n/l10n_extensions.dart';
import '../../l10n/locale_provider.dart';

const _kOrange = Color(0xFFDB6234);

/// Opens the language picker used by both the Client and Ustaad profiles.
///
/// Selecting a language applies it on the spot — the whole app rebuilds from
/// [localeProvider] with no restart — and persists it before the sheet closes.
Future<void> showLanguageSelectorSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
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
    final current = ref.watch(localeProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              context.l10n.languageSheetTitle,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          const SizedBox(height: 14),
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? _kOrange : const Color(0xFF1A1A1A),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_rounded, size: 20, color: _kOrange),
          ],
        ),
      ),
    );
  }
}
