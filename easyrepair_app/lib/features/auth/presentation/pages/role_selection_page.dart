import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';

/// New auth entry page — replaces the old direct Login/Register screen.
///
/// Reached from Welcome → Language Selection. The wording is fully localized,
/// so the Roman Urdu + Easy English onboarding choice reads
/// "Aap kya karna chahte hain?" and the English choice reads "What would you
/// like to do?" — the page itself never names a language.
///
/// ## Colour architecture
///
/// Every colour comes from [AppSemanticColors]; there is not one hex literal
/// in this file, and not one `brightness == Brightness.dark` check. The page
/// is therefore dark-mode ready without any page-level logic: the palette
/// swaps centrally and this screen follows.
///
/// The Client card carries the emphasized (primary) treatment and the Ustaad
/// card the neutral one. That is a visual hierarchy decision only — neither
/// option is pre-selected, and both navigate identically.
class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  String? _selected;

  Future<void> _select(String key, String route) async {
    if (_selected != null) return; // guards a double-tap mid-navigation
    setState(() => _selected = key);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    // push, not go: `go` replaces the stack, which leaves the destination
    // with nothing to pop back to - the AppBar arrow does nothing and the
    // Android Back button closes the app from a mid-flow auth screen.
    //
    // `push` returns once the pushed route (and anything it pushed in turn)
    // is popped back off, i.e. exactly when the user returns here — that's
    // the moment to drop the highlight/tap-guard. Without this, this page's
    // State survives underneath the pushed route (push never disposes it),
    // so `_selected` stayed stuck on whichever card was tapped last time and
    // silently swallowed every tap after Back — a temporary UI choice must
    // never outlive the screen it was made for.
    await context.push(route);
    if (mounted) setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Content sits in the upper middle rather than dead centre, as in
            // the design. Proportional so it holds on a short phone and does
            // not drift to the bottom of a tall one, and clamped so it never
            // eats the cards' room.
            final topSpace = (constraints.maxHeight * 0.14).clamp(20.0, 110.0);

            // The scroll view is the overflow fallback: at a large text scale
            // the cards grow past the viewport and this scrolls instead of
            // throwing. At normal scales nothing scrolls.
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    // Keeps the cards a comfortable phone width on a tablet
                    // instead of stretching them edge to edge.
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: topSpace),
                          Text(
                            l10n.authRoleQuestion,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            l10n.authRoleSubtitle,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 32),
                          _RoleCard(
                            icon: Icons.home_rounded,
                            title: l10n.authRoleClientTitle,
                            subtitle: l10n.authRoleClientSubtitle,
                            // The primary CTA treatment from the design — a
                            // hierarchy cue, not a selected state.
                            emphasized: true,
                            isPressed: _selected == 'client',
                            onTap: () => _select('client', '/auth/client'),
                          ),
                          const SizedBox(height: 16),
                          _RoleCard(
                            icon: Icons.handyman_rounded,
                            title: l10n.authRoleWorkerTitle,
                            subtitle: l10n.authRoleWorkerSubtitle,
                            emphasized: false,
                            isPressed: _selected == 'worker',
                            onTap: () =>
                                _select('worker', '/auth/worker/choice'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One tappable role option: icon tile, title + subtitle, chevron.
///
/// [emphasized] picks between the two treatments the design calls for — the
/// primary-bordered Client card and the neutral Ustaad card. Both are equally
/// tappable; the difference is visual weight only.
///
/// Deliberately private to this page rather than an edit to the shared
/// `SelectionCard`: that widget is also used by the Ustaad new-or-existing
/// screen, which is not part of this redesign.
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.emphasized,
    required this.isPressed,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool emphasized;

  /// The brief highlight between tap and navigation — see
  /// `_RoleSelectionPageState._select`. Not a persisted selection.
  final bool isPressed;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    final borderColor = emphasized || isPressed ? colors.primary : colors.border;
    final accent = emphasized ? colors.primary : colors.textSecondary;
    final iconTile = emphasized ? colors.softTeal : colors.surfaceSubtle;

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Material(
          // Held on `surface` in both treatments so the two cards read as one
          // family; the emphasis comes from the border and the icon tile.
          color: isPressed ? colors.softTeal : colors.surface,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(18),
              // Comfortably above the 48dp accessible minimum, and a floor
              // rather than a fixed height so a wrapped subtitle just grows
              // the card instead of clipping.
              constraints: const BoxConstraints(minHeight: 88),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: borderColor,
                  width: emphasized || isPressed ? 1.6 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: iconTile,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 26, color: accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
