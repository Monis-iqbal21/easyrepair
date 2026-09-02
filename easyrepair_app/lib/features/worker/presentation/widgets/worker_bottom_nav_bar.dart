import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/presentation/responsive_utils.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/worker_nav_indicator_providers.dart';

class WorkerBottomNavBar extends ConsumerWidget {
  final int currentIndex;

  const WorkerBottomNavBar({super.key, required this.currentIndex});

  /// Tab order and icons are fixed; only the label is language-dependent, so
  /// the label is a lookup rather than a string and the list stays const. The
  /// last four reuse the matching page-title keys — one English string must
  /// map to one ARB key (see the duplicate check in arb_parity_test.dart).
  ///
  /// `indicator` says what, if anything, a tab is allowed to report. It lives
  /// in the const tab list on purpose: which tabs carry an indicator is
  /// structural, exactly like the icon and the route, and must not drift per
  /// language or per screen.
  static const _tabs = [
    _NavTab(label: _navHome,    icon: Icons.home_outlined,          route: '/worker/home'),
    _NavTab(label: _navNewJobs, icon: Icons.work_outline_rounded,   route: '/worker/new-jobs',
            indicator: _NavIndicator.unreadNewJobCount),
    _NavTab(label: _navMyJobs,  icon: Icons.build_outlined,         route: '/worker/jobs',
            indicator: _NavIndicator.ongoingJobDot),
    _NavTab(label: _navChat,    icon: Icons.chat_bubble_outline,    route: '/worker/chat',
            indicator: _NavIndicator.unreadConversationCount),
    _NavTab(label: _navProfile, icon: Icons.person_outline,         route: '/worker/profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                          //
                          // The indicator hangs off the icon rather than
                          // sitting in the Column, so it cannot change the
                          // tab's width or push the label down: the Stack is
                          // sized by the Icon alone and the badge is
                          // positioned outside it (`clipBehavior: none`).
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                tab.icon,
                                size: iconSize,
                                color: isActive ? c.primary : c.textSecondary,
                              ),
                              ..._indicatorFor(ref, tab.indicator),
                            ],
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

  /// Resolves one tab's indicator to zero or one positioned widget.
  ///
  /// Returns a list rather than a nullable widget so "nothing to report"
  /// contributes no child at all — an invisible `SizedBox` would still be a
  /// widget the layout, and every reader of this file, has to reason about.
  List<Widget> _indicatorFor(WidgetRef ref, _NavIndicator? indicator) {
    switch (indicator) {
      case null:
        return const [];
      case _NavIndicator.unreadConversationCount:
        final count = ref.watch(workerUnreadConversationCountProvider);
        if (count == 0) return const [];
        return [
          Positioned(top: -4, right: -6, child: _CountBadge(count: count)),
        ];
      case _NavIndicator.unreadNewJobCount:
        final count = ref.watch(workerNewJobsUnreadCountProvider);
        if (count == 0) return const [];
        return [
          Positioned(top: -4, right: -6, child: _CountBadge(count: count)),
        ];
      case _NavIndicator.ongoingJobDot:
        if (!ref.watch(workerHasOngoingJobProvider)) return const [];
        return const [Positioned(top: -2, right: -4, child: _OngoingDot())];
    }
  }
}

/// What a tab is allowed to report. Deliberately a closed set: a tab either
/// carries one of these or carries nothing, so "add a badge" is a decision
/// taken here rather than improvised inside a screen.
enum _NavIndicator {
  /// Chat — how many CONVERSATIONS hold unread messages, never how many
  /// unread messages.
  unreadConversationCount,

  /// Naye Kaam — how many eligible jobs have arrived in the last 24h since
  /// this Ustaad last opened the screen. Shares its provider with the Home
  /// "Nayi Shikayat" card; neither counts anything itself.
  unreadNewJobCount,

  /// My Jobs — a presence dot for "you have a job in hand right now". No
  /// number: an Ustaad works one job at a time, so a count would always read 1.
  ongoingJobDot,
}

/// The numeric pill. Sized from its own text and capped at "9+", so a busy
/// inbox can never widen the tab it sits on.
class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      constraints: const BoxConstraints(minWidth: 17),
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // `urgent` is the attention accent, the same one the Home notification
        // bell already uses for its count. The `surface` ring keeps the pill
        // legible where it overlaps the icon beneath it.
        color: c.urgent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.surface, width: 1.5),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: TextStyle(
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w700,
          color: c.onPrimary,
        ),
      ),
    );
  }
}

/// The "job in hand" dot. `success`, not `urgent`: having work is a good
/// state, not something demanding rescue.
class _OngoingDot extends StatelessWidget {
  const _OngoingDot();

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: c.success,
        shape: BoxShape.circle,
        border: Border.all(color: c.surface, width: 1.5),
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
  final _NavIndicator? indicator;
  const _NavTab({
    required this.label,
    required this.icon,
    required this.route,
    this.indicator,
  });
}
