import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/presentation/responsive_utils.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../l10n/app_localizations.dart';

class WorkerBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const WorkerBottomNavBar({super.key, required this.currentIndex});

  /// Tab order and icons are fixed; only the label is language-dependent, so
  /// the label is a lookup rather than a string and the list stays const. The
  /// last four reuse the matching page-title keys — one English string must
  /// map to one ARB key (see the duplicate check in arb_parity_test.dart).
  static const _tabs = [
    _NavTab(label: _navHome,    icon: Icons.home_outlined,          route: '/worker/home'),
    _NavTab(label: _navNewJobs, icon: Icons.work_outline_rounded,   route: '/worker/new-jobs'),
    _NavTab(label: _navMyJobs,  icon: Icons.build_outlined,         route: '/worker/jobs'),
    _NavTab(label: _navChat,    icon: Icons.chat_bubble_outline,    route: '/worker/chat'),
    _NavTab(label: _navProfile, icon: Icons.person_outline,         route: '/worker/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final l10n = context.l10n;
    final c = context.semanticColors;
    // Labels are translated, but the bar itself stays pinned LTR: Urdu RTL
    // must never reverse tab order or move Home away from the left edge.
    // Verified by test/core/l10n/bottom_nav_protection_test.dart.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
      // Prototype `.nav` (CSS line 45): `background: var(--card)` with a
      // single `border-top: 1px solid var(--line)` — no shadow.
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomInset),
        // LayoutBuilder gives real available width so each tab knows its budget.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabW = constraints.maxWidth / _tabs.length;
            // Scale icon and label relative to tabW at 390px screen (tabW≈90).
            final iconSize = rFont(tabW, 24, min: 20, max: 28, baseWidth: 90);
            // Prototype `.nv` (CSS line 46) is 12.5px; the floor comes up with
            // it so a narrow phone never drops the label below what an Ustaad
            // can read outdoors.
            final labelSize = rFont(tabW, 12.5, min: 12, max: 14, baseWidth: 90);
            final gap = (4.0 * tabW / 90.0).clamp(2.0, 6.0);

            return Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final isActive = i == currentIndex;
                // Expanded gives each tab an equal share of width — overflow
                // at the Row level is structurally impossible.
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (!isActive) context.go(tab.route);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // In the prototype the icon and the label of an
                          // inactive tab are the same colour (`.nv` inherits
                          // `--ink2` and the SVG uses `currentColor`). The app
                          // had them on two different greys.
                          Icon(
                            tab.icon,
                            size: iconSize,
                            color: isActive ? c.primary : c.textSecondary,
                          ),
                          SizedBox(height: gap),
                          Text(
                            tab.label(l10n),
                            style: TextStyle(
                              fontSize: labelSize,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isActive ? c.primary : c.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
      ),
    );
  }
}

/// Resolves a tab's label for the active language. A plain `String` field
/// could not be const here, and a const tab list is what keeps tab order and
/// icons identical in every language.
typedef _NavLabel = String Function(AppLocalizations l10n);

String _navHome(AppLocalizations l10n) => l10n.navHome;
String _navNewJobs(AppLocalizations l10n) => l10n.workerNewJobsTitle;
String _navMyJobs(AppLocalizations l10n) => l10n.clientJobsTitle;
String _navChat(AppLocalizations l10n) => l10n.chatTitleFallback;
String _navProfile(AppLocalizations l10n) => l10n.clientProfileTitle;

class _NavTab {
  final _NavLabel label;
  final IconData icon;
  final String route;
  const _NavTab({required this.label, required this.icon, required this.route});
}
