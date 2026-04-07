import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ClientBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const ClientBottomNavBar({super.key, required this.currentIndex});

  static const _tabs = [
    _NavTab(label: 'Home', emoji: '🏠', route: '/client/home'),
    _NavTab(label: 'Bookings', emoji: '📋', route: '/client/jobs'),
    _NavTab(label: 'Chat', emoji: '💬', route: '/client/chat'),
    _NavTab(label: 'Profile', emoji: '👤', route: '/client/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_tabs.length, (i) {
            final tab = _tabs[i];
            final isActive = i == currentIndex;
            return GestureDetector(
              onTap: () {
                if (!isActive) context.go(tab.route);
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFFF5F15).withOpacity(0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tab.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 2),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        color: isActive
                            ? const Color(0xFFFF5F15)
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavTab {
  final String label;
  final String emoji;
  final String route;
  const _NavTab({required this.label, required this.emoji, required this.route});
}
