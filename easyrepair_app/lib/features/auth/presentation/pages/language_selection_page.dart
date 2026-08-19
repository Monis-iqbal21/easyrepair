import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_locale.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/l10n/locale_provider.dart';
import '../../../../core/theme/app_semantic_colors.dart';

/// Onboarding step between the branded welcome screen and the existing
/// Client/Ustaad role picker.
///
/// It does not own any language state of its own: the selection is applied
/// through [LocaleNotifier.setLocale], the same single source of truth the
/// settings language sheet already uses, so the choice persists to
/// SharedPreferences and the whole app rebuilds from [localeProvider].
///
/// ## Only two options
///
/// HandyGo ships three locales, but onboarding deliberately offers two —
/// Roman Urdu (+ easy English) and English. Urdu script remains fully
/// supported and reachable from the settings language sheet; it is simply not
/// surfaced here. See [_onboardingOptions].
///
/// ## Colours
///
/// Every colour resolves from [AppSemanticColors]. There is no brand literal
/// in this file, so the pending palette decision and the future dark theme
/// reach this page without it being edited.
class LanguageSelectionPage extends ConsumerStatefulWidget {
  const LanguageSelectionPage({super.key});

  /// Where "Continue" hands off to — the EXISTING role picker, unchanged.
  static const roleSelectRoute = '/auth/role-select';

  @override
  ConsumerState<LanguageSelectionPage> createState() =>
      _LanguageSelectionPageState();
}

/// The two choices this screen exposes, in display order.
const _onboardingOptions = <AppLocale>[
  AppLocale.romanUrdu,
  AppLocale.english,
];

class _LanguageSelectionPageState extends ConsumerState<LanguageSelectionPage> {
  /// What the user actively tapped, or null while the page is still showing
  /// the default derived from their current locale.
  ///
  /// Kept separate from "which card is highlighted" on purpose: merely opening
  /// this screen must not rewrite a preference the user already has (an Urdu
  /// user, for instance, is shown the Roman Urdu card because Urdu script has
  /// no card here — pressing Continue without touching anything leaves their
  /// Urdu setting exactly as it was).
  AppLocale? _tapped;

  /// The card to highlight: the user's tap if there was one, otherwise the
  /// closest card to the locale already in effect.
  AppLocale get _highlighted => _tapped ?? _cardFor(ref.read(localeProvider));

  /// Maps any locale onto the card that represents it. Urdu script has no
  /// card of its own, so it shows as Roman Urdu — the nearest option, and
  /// never English.
  static AppLocale _cardFor(AppLocale current) =>
      current == AppLocale.english ? AppLocale.english : AppLocale.romanUrdu;

  Future<void> _onContinue() async {
    final selection = _tapped;
    if (selection != null) {
      // An explicit choice always wins and is persisted.
      await ref.read(localeProvider.notifier).setLocale(selection);
    } else if (!_hasStoredPreference()) {
      // Brand-new user who accepted the default: record it so the choice is
      // explicit rather than implicit, and so a future change to the app-wide
      // default cannot silently move them.
      //
      // setLocale alone is not enough here: it short-circuits when the locale
      // is already in effect, which it always is in this branch (the default
      // IS what they are looking at), so nothing would ever reach disk. The
      // write goes through the same key and the same store the notifier uses.
      final fallback = _highlighted;
      await ref.read(localeProvider.notifier).setLocale(fallback);
      await ref
          .read(sharedPreferencesProvider)
          .setString(kLocalePrefsKey, fallback.storageValue);
    }
    // else: an existing preference the user did not touch — left untouched.

    if (!mounted) return;
    context.push(LanguageSelectionPage.roleSelectRoute);
  }

  bool _hasStoredPreference() =>
      ref.read(sharedPreferencesProvider).getString(kLocalePrefsKey) != null;

  @override
  Widget build(BuildContext context) {
    // Watched (not read) so the copy re-renders in the newly chosen language
    // the moment a card is tapped.
    ref.watch(localeProvider);
    final colors = context.semanticColors;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sidePadding = constraints.maxWidth < 340 ? 20.0 : 24.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(sidePadding, 8, sidePadding, 24),
              child: ConstrainedBox(
                // Tablets get a comfortable column instead of cards stretched
                // across the whole width.
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.languageOnboardingTitle,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.languageOnboardingSubtitle,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 36),
                    for (final option in _onboardingOptions) ...[
                      _LanguageCard(
                        title: option.onboardingLabel,
                        subtitle: option == AppLocale.english
                            ? l10n.languageOptionEnglishSubtitle
                            : l10n.languageOptionRomanUrduSubtitle,
                        selected: _highlighted == option,
                        onTap: () => setState(() => _tapped = option),
                      ),
                      const SizedBox(height: 14),
                    ],
                    const SizedBox(height: 18),
                    _ContinueButton(onPressed: _onContinue),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One large, fully tappable language card. The whole surface is the target —
/// not just the indicator.
class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    const radius = 16.0;

    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: Material(
        color: selected
            // No primary-container token exists in the semantic palette yet,
            // so the selected tint is derived from primary itself rather than
            // introducing a second colour literal.
            ? colors.primary.withValues(alpha: 0.08)
            : colors.surface,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: selected ? colors.primary : colors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.35,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                _SelectionIndicator(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Filled primary circle with a check when selected; a plain outlined circle
/// when not.
class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? colors.primary : null,
        border: Border.all(
          color: selected ? colors.primary : colors.border,
          width: selected ? 0 : 1.5,
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 16, color: colors.onPrimary)
          : null,
    );
  }
}

/// Full-width primary CTA. Its colours come from the central tokens, so it
/// stays in the same family as the Shuru karein button and Client Home.
class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        disabledBackgroundColor: colors.disabled,
        elevation: 0,
        // Grows with the text scale rather than clipping; never below the
        // 48dp accessible minimum.
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Text(
        context.l10n.commonContinue,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
