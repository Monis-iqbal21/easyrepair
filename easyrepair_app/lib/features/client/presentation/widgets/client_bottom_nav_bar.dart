import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/responsive_utils.dart';

const _kAccent = Color(0xFF1D9E75);

class ClientBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const ClientBottomNavBar({super.key, required this.currentIndex});

  static const _tabs = [
    _NavTab(label: 'Home', icon: Icons.home_outlined, route: '/client/home'),
    _NavTab(
      label: 'Bookings',
      icon: Icons.task_alt_outlined,
      route: '/client/jobs',
    ),
    _NavTab(
      label: 'Chat',
      icon: Icons.chat_bubble_outline,
      route: '/client/chat',
    ),
    _NavTab(
      label: 'Profile',
      icon: Icons.person_outline,
      route: '/client/profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 16,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomInset),
        // LayoutBuilder gives real available width so each tab knows its budget.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabW = constraints.maxWidth / _tabs.length;
            // Scale icon and label relative to tabW at 390px screen (tabW≈90).
            final iconSize = rFont(tabW, 24, min: 24, max: 30, baseWidth: 90);
            final labelSize = rFont(tabW, 12, min: 10, max: 14, baseWidth: 90);
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
                          Icon(
                            tab.icon,
                            size: iconSize,
                            color: isActive
                                ? _kAccent
                                : const Color(0xFF1A1A1A),
                          ),
                          SizedBox(height: gap),
                          Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: labelSize,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isActive
                                  ? _kAccent
                                  : const Color(0xFF6B7280),
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
    );
  }
}

class _NavTab {
  final String label;
  final IconData icon;
  final String route;
  const _NavTab({required this.label, required this.icon, required this.route});
}
