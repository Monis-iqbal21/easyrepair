import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../../core/widgets/navigation_count_badge.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/presentation/responsive_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_semantic_colors.dart';

class ClientBottomNavBar extends ConsumerWidget {
  final int currentIndex;

  const ClientBottomNavBar({super.key, required this.currentIndex});

  /// Tab order and icons are fixed; only the label is language-dependent, so
  /// the label is a lookup rather than a string and the list stays const.
  static const _tabs = [
    _NavTab(
      label: _navHome,
      icon: Icons.home_outlined,
      route: '/client/home',
    ),
    _NavTab(
      label: _navBookings,
      icon: Icons.assignment_turned_in_outlined,
      route: '/client/jobs',
    ),
    _NavTab(
      label: _navChats,
      icon: Icons.chat_bubble_outline_rounded,
      route: '/client/chat',
    ),
    _NavTab(
      // Shares the Profile page's own title key — one English string must map
      // to one ARB key (see the duplicate check in arb_parity_test.dart).
      label: _navProfile,
      icon: Icons.person_outline_rounded,
      route: '/client/profile',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadChats = ref.watch(unreadConversationCountProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final l10n = context.l10n;
    final colors = context.semanticColors;
    // Labels are translated, but the bar itself stays pinned LTR: Urdu RTL
    // must never reverse tab order or move Home away from the left edge.
    // Verified by test/core/l10n/bottom_nav_protection_test.dart.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomInset),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabW = constraints.maxWidth / _tabs.length;
            final iconSize = rFont(tabW, 26, min: 24, max: 30, baseWidth: 90);
            final labelSize = rFont(tabW, 11, min: 10, max: 13, baseWidth: 90);
            final gap = (3.0 * tabW / 90.0).clamp(2.0, 5.0);

            return Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final isActive = i == currentIndex;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (!isActive) context.go(tab.route);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                tab.icon,
                                size: iconSize,
                                color: isActive ? colors.primary : colors.textSecondary,
                              ),
                              if (tab.route == '/client/chat' && unreadChats > 0)
                                Positioned(
                                  top: -4,
                                  right: -6,
                                  child: NavigationCountBadge(count: unreadChats),
                                ),
                            ],
                          ),
                          SizedBox(height: gap),
                          Text(
                            tab.label(l10n),
                            style: TextStyle(
                              fontSize: labelSize,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isActive
                                  ? colors.primary
                                  : colors.textSecondary,
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
String _navBookings(AppLocalizations l10n) => l10n.navBookings;
String _navChats(AppLocalizations l10n) => l10n.chatTitleFallback;
String _navProfile(AppLocalizations l10n) => l10n.clientProfileTitle;

class _NavTab {
  final _NavLabel label;
  final IconData icon;
  final String route;

  const _NavTab({
    required this.label,
    required this.icon,
    required this.route,
  });
}
